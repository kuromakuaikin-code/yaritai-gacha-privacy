import SwiftUI
import AVFoundation
import Photos
import UIKit

// MARK: - 書き出しエンジン
//
// ⚠️ 開発者向け注意：この合成・書き出しパイプラインは Mac / 実機 / シミュレータでの
// 動作確認が一度もできていません（この環境には Xcode / 実機がありません）。
// リリース前に、実際の動画クリップを使って必ず十分にテストしてください。
// 特に「動きの座標系」「回転（縦動画）」「音量ミックス」あたりは
// 想定と違う結果になりやすい箇所です。

@MainActor
final class ExportEngine: ObservableObject {
    enum ExportState: Equatable {
        case idle, exporting, savingToPhotos, done, failed
    }

    @Published var progress: Double = 0
    @Published var state: ExportState = .idle
    @Published var outputURL: URL?
    @Published var errorMessage: String?

    private var timer: Timer?

    func start(project: VideoProject, isPremium: Bool) {
        guard state != .exporting, state != .savingToPhotos else { return }
        state = .exporting
        progress = 0
        errorMessage = nil
        outputURL = nil

        let clips = project.clips
        let caption = project.caption
        let stickers = project.stickers
        let music = project.music

        Task {
            do {
                let session = try await ExportBuilder.buildExportSession(
                    clips: clips,
                    caption: caption,
                    stickers: stickers,
                    music: music,
                    isPremium: isPremium
                )
                startPolling(session)
                try await ExportBuilder.run(session)
                stopPolling()
                progress = 1

                guard let url = session.outputURL else {
                    throw ExportBuilder.ExportError.exportFailed
                }
                outputURL = url
                state = .savingToPhotos
                try await ExportBuilder.saveToPhotos(url: url)
                state = .done
            } catch {
                stopPolling()
                if let exportError = error as? ExportBuilder.ExportError {
                    errorMessage = exportError.errorDescription
                } else {
                    errorMessage = "うまく つくれませんでした。もう一度 ためしてね。"
                }
                state = .failed
            }
        }
    }

    private func startPolling(_ session: AVAssetExportSession) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            let value = Double(session.progress)
            Task { @MainActor in
                self.progress = value
            }
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - 合成・書き出しロジック（AVFoundation）

enum ExportBuilder {
    enum ExportError: LocalizedError {
        case noClips, compositionFailed, exportFailed, photoLibraryDenied

        var errorDescription: String? {
            switch self {
            case .noClips: return "どうがが えらばれていません。"
            case .compositionFailed: return "どうがの がっせいに しっぱいしました。"
            case .exportFailed: return "かきだしに しっぱいしました。"
            case .photoLibraryDenied: return "しゃしんライブラリへの アクセスが きょかされていません。"
            }
        }
    }

    /// クリップ・キャプション・ステッカー・BGM設定から AVMutableComposition と
    /// AVMutableVideoComposition を組み立て、書き出し準備済みの AVAssetExportSession を返す。
    static func buildExportSession(
        clips: [VideoClip],
        caption: ProjectCaption,
        stickers: [PlacedSticker],
        music: MusicSettings,
        isPremium: Bool
    ) async throws -> AVAssetExportSession {
        guard !clips.isEmpty else { throw ExportError.noClips }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExportError.compositionFailed
        }

        var renderSize = CGSize(width: 1280, height: 720)
        var finalTransform = CGAffineTransform.identity
        var cursor = CMTime.zero
        var isFirst = true

        for clip in clips {
            let asset = AVURLAsset(url: clip.assetURL)
            guard let tracks = try? await asset.loadTracks(withMediaType: .video),
                  let assetVideoTrack = tracks.first else { continue }

            if isFirst {
                if let naturalSize = try? await assetVideoTrack.load(.naturalSize),
                   let transform = try? await assetVideoTrack.load(.preferredTransform) {
                    let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(transform)
                    let absSize = CGSize(width: abs(transformedRect.width), height: abs(transformedRect.height))
                    if absSize.width > 0, absSize.height > 0 {
                        renderSize = fittedRenderSize(from: absSize)
                        let scale = renderSize.width / absSize.width
                        finalTransform = transform
                            .concatenating(CGAffineTransform(translationX: -transformedRect.origin.x, y: -transformedRect.origin.y))
                            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                    }
                }
                isFirst = false
            }

            let assetDuration = (try? await asset.load(.duration))?.seconds ?? clip.duration
            let clampedStart = max(0, min(clip.trimStart, assetDuration))
            let clampedEnd = max(clampedStart + 0.05, min(clip.trimEnd, max(assetDuration, clampedStart + 0.05)))
            let start = CMTime(seconds: clampedStart, preferredTimescale: 600)
            let end = CMTime(seconds: clampedEnd, preferredTimescale: 600)
            let range = CMTimeRange(start: start, duration: end - start)

            do {
                try videoTrack.insertTimeRange(range, of: assetVideoTrack, at: cursor)
            } catch {
                continue
            }

            if let audioTracks = try? await asset.loadTracks(withMediaType: .audio),
               let assetAudioTrack = audioTracks.first {
                try? audioTrack.insertTimeRange(range, of: assetAudioTrack, at: cursor)
            }

            cursor = cursor + (end - start)
        }

        guard cursor.seconds > 0 else { throw ExportError.compositionFailed }

        // MARK: BGM トラック（有効な場合、動画全体の長さになるまでループ挿入）
        var bgmTrack: AVMutableCompositionTrack?
        if music.enabled, let bgmURL = bundledAudioURL(for: music.trackID) {
            let bgmAsset = AVURLAsset(url: bgmURL)
            if let sourceTrack = try? await bgmAsset.loadTracks(withMediaType: .audio).first,
               let bgmDuration = try? await bgmAsset.load(.duration),
               bgmDuration.seconds > 0 {
                let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                if let track {
                    var remaining = cursor
                    var insertAt = CMTime.zero
                    while remaining.seconds > 0 {
                        let segment = remaining.seconds < bgmDuration.seconds ? remaining : bgmDuration
                        try? track.insertTimeRange(CMTimeRange(start: .zero, duration: segment), of: sourceTrack, at: insertAt)
                        insertAt = insertAt + segment
                        remaining = remaining - segment
                    }
                    bgmTrack = track
                }
            }
        }

        // MARK: レイヤー合成（テキストキャプション・ステッカー・すかし）

        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.addSublayer(videoLayer)

        if !caption.text.isEmpty {
            let style = CaptionStyleData.all.first(where: { $0.id == caption.styleID }) ?? CaptionStyleData.all[0]
            let captionLayer = makeTextLayer(
                text: caption.text,
                color: UIColor(style.color),
                fontSize: renderSize.width * 0.07,
                frame: captionFrame(for: caption.position, renderSize: renderSize)
            )
            parentLayer.addSublayer(captionLayer)
        }

        for sticker in stickers {
            let stickerLayer = makeTextLayer(
                text: sticker.emoji,
                color: .white,
                fontSize: renderSize.width * 0.12,
                frame: stickerFrame(for: sticker.position, renderSize: renderSize)
            )
            parentLayer.addSublayer(stickerLayer)
        }

        if !isPremium {
            let watermarkFrame = CGRect(
                x: renderSize.width * 0.55,
                y: renderSize.height * 0.02,
                width: renderSize.width * 0.43,
                height: renderSize.height * 0.06
            )
            let watermark = makeTextLayer(
                text: "きっず動画編集",
                color: UIColor.white.withAlphaComponent(0.85),
                fontSize: renderSize.width * 0.028,
                frame: watermarkFrame
            )
            watermark.alignmentMode = .right
            parentLayer.addSublayer(watermark)
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer, in: parentLayer
        )

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: cursor)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(finalTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // MARK: 音量ミックス
        var audioMixParams: [AVMutableAudioMixInputParameters] = []
        let originalParams = AVMutableAudioMixInputParameters(track: audioTrack)
        originalParams.setVolume(1.0, at: .zero)
        audioMixParams.append(originalParams)

        if let bgmTrack {
            let bgmParams = AVMutableAudioMixInputParameters(track: bgmTrack)
            let volume = Float(max(0, min(1, music.volume)))
            bgmParams.setVolumeRamp(fromStartVolume: volume, toEndVolume: volume, timeRange: CMTimeRange(start: .zero, duration: cursor))
            audioMixParams.append(bgmParams)
        }

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = audioMixParams

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.exportFailed
        }
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.audioMix = audioMix
        exportSession.shouldOptimizeForNetworkUse = true

        return exportSession
    }

    /// 書き出しを実行する（進捗は呼び出し側が session.progress をポーリングする）
    static func run(_ session: AVAssetExportSession) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(throwing: session.error ?? ExportError.exportFailed)
                default:
                    continuation.resume(throwing: ExportError.exportFailed)
                }
            }
        }
    }

    static func saveToPhotos(url: URL) async throws {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<PHAuthorizationStatus, Never>) in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
        guard status == .authorized || status == .limited else {
            throw ExportError.photoLibraryDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }

    // MARK: - ジオメトリ・レイヤー生成ヘルパー

    private static func fittedRenderSize(from size: CGSize) -> CGSize {
        let maxDimension: CGFloat = 1280
        let scale = min(1, maxDimension / max(size.width, size.height))
        var width = (size.width * scale).rounded()
        var height = (size.height * scale).rounded()
        if width.truncatingRemainder(dividingBy: 2) != 0 { width -= 1 }
        if height.truncatingRemainder(dividingBy: 2) != 0 { height -= 1 }
        return CGSize(width: max(width, 2), height: max(height, 2))
    }

    private static func makeTextLayer(text: String, color: UIColor, fontSize: CGFloat, frame: CGRect) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = text
        layer.font = UIFont.boldSystemFont(ofSize: fontSize)
        layer.fontSize = fontSize
        layer.foregroundColor = color.cgColor
        layer.alignmentMode = .center
        layer.frame = frame
        layer.contentsScale = UIScreen.main.scale
        layer.isWrapped = true
        layer.truncationMode = .end
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 1)
        return layer
    }

    private static func captionFrame(for position: CaptionPosition, renderSize: CGSize) -> CGRect {
        let width = renderSize.width * 0.9
        let height = renderSize.height * 0.15
        let x = (renderSize.width - width) / 2
        switch position {
        case .top: return CGRect(x: x, y: renderSize.height * 0.06, width: width, height: height)
        case .center: return CGRect(x: x, y: (renderSize.height - height) / 2, width: width, height: height)
        case .bottom: return CGRect(x: x, y: renderSize.height * 0.79, width: width, height: height)
        }
    }

    private static func stickerFrame(for position: StickerPosition, renderSize: CGSize) -> CGRect {
        let size = renderSize.width * 0.16
        let margin = renderSize.width * 0.04
        switch position {
        case .topLeft: return CGRect(x: margin, y: margin, width: size, height: size)
        case .topRight: return CGRect(x: renderSize.width - margin - size, y: margin, width: size, height: size)
        case .center: return CGRect(x: (renderSize.width - size) / 2, y: (renderSize.height - size) / 2, width: size, height: size)
        case .bottomLeft: return CGRect(x: margin, y: renderSize.height - margin - size, width: size, height: size)
        case .bottomRight: return CGRect(x: renderSize.width - margin - size, y: renderSize.height - margin - size, width: size, height: size)
        }
    }

    private static func bundledAudioURL(for filename: String) -> URL? {
        let (name, ext) = splitFilename(filename)
        return Bundle.main.url(forResource: name, withExtension: ext)
    }

    private static func splitFilename(_ filename: String) -> (name: String, ext: String?) {
        guard let dotIndex = filename.lastIndex(of: ".") else { return (filename, nil) }
        let name = String(filename[filename.startIndex..<dotIndex])
        let ext = String(filename[filename.index(after: dotIndex)...])
        return (name, ext)
    }
}

// MARK: - 書き出し画面

struct ExportView: View {
    @EnvironmentObject private var project: VideoProject
    @EnvironmentObject private var store: PurchaseStore
    @StateObject private var engine = ExportEngine()
    @State private var showParentalGateForShare = false
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 24) {
            switch engine.state {
            case .idle:
                ProgressView("じゅんびちゅう…")
            case .exporting:
                exportingView
            case .savingToPhotos:
                savingView
            case .done:
                doneView
            case .failed:
                failedView
            }
        }
        .padding()
        .navigationTitle("かんせい")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(engine.state == .exporting || engine.state == .savingToPhotos)
        .onAppear {
            if engine.state == .idle {
                engine.start(project: project, isPremium: store.premium)
            }
        }
        .parentalGate(isPresented: $showParentalGateForShare) {
            showShareSheet = true
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = engine.outputURL {
                ShareSheet(items: [url])
            }
        }
    }

    private var exportingView: some View {
        VStack(spacing: 20) {
            Text("🎬 どうがを つくっているよ…").font(.title3.bold())
            ProgressView(value: engine.progress)
                .progressViewStyle(.linear)
                .tint(.pink)
                .padding(.horizontal, 40)
            Text("\(Int(engine.progress * 100))%")
                .font(.headline)
            Text("すこし まってね")
                .foregroundStyle(.secondary)
        }
    }

    private var savingView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("しゃしんに ほぞんしているよ…").font(.headline)
        }
    }

    private var doneView: some View {
        VStack(spacing: 24) {
            Text("🎉").font(.system(size: 80))
            Text("できたよ！").font(.system(size: 36, weight: .heavy, design: .rounded))
            Text("どうがを アルバムに ほぞんしたよ").foregroundStyle(.secondary)

            Button {
                showParentalGateForShare = true
            } label: {
                Label("シェアする", systemImage: "square.and.arrow.up")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .padding(.horizontal)

            Button {
                project.reset()
                project.path = NavigationPath()
            } label: {
                Text("あたらしい どうがを つくる")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.pink)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .padding(.horizontal)
        }
    }

    private var failedView: some View {
        VStack(spacing: 20) {
            Text("😢").font(.system(size: 60))
            Text("うまく つくれませんでした").font(.title3.bold())
            if let message = engine.errorMessage {
                Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Button {
                engine.start(project: project, isPremium: store.premium)
            } label: {
                Text("もういちど ためす")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.pink)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - 共有シート（UIActivityViewController ラッパー）

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
