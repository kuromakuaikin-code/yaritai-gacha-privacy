import AVFoundation
import UIKit

/// 書き出し管理。
/// - テキストオーバーレイと透かしは AVVideoCompositionCoreAnimationTool で焼き込み
/// - AVAssetExportSession はプロパティで保持(ローカル変数だと途中で解放され silent fail する頻出バグ)
/// - 進捗は Timer ポーリング(exportSession.progress は KVO 非対応)
@MainActor
final class ExportManager: ObservableObject {

    enum ExportState: Equatable {
        case idle
        case exporting(progress: Float)
        case finished(URL)
        case failed(String)
    }

    @Published private(set) var state: ExportState = .idle

    private var session: AVAssetExportSession?
    private var progressTimer: Timer?

    /// - Parameters:
    ///   - showWatermark: 無料版は true(課金で解除)
    func export(project: EditorProject, showWatermark: Bool) async {
        guard case .idle = state else { return } // 二重実行ガード
        state = .exporting(progress: 0)

        do {
            let result = try await CompositionEngine.build(project: project)

            // オーバーレイ焼き込み用のレイヤーツリー
            let videoComposition = result.videoComposition
            videoComposition.animationTool = makeAnimationTool(
                overlays: project.textOverlays,
                showWatermark: showWatermark
            )

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("shortlab_\(UUID().uuidString).mp4")

            guard let session = AVAssetExportSession(
                asset: result.composition,
                presetName: AVAssetExportPreset1920x1080
            ) else {
                state = .failed("エクスポートセッションを作成できませんでした")
                return
            }
            session.outputURL = outputURL
            session.outputFileType = .mp4
            session.videoComposition = videoComposition
            self.session = session

            startProgressPolling()

            await session.export()

            stopProgressPolling()

            switch session.status {
            case .completed:
                state = .finished(outputURL)
            case .cancelled:
                state = .idle
            default:
                let message = session.error?.localizedDescription ?? "不明なエラー"
                state = .failed(message)
            }
            self.session = nil
        } catch {
            stopProgressPolling()
            session = nil
            state = .failed(error.localizedDescription)
        }
    }

    func cancel() {
        session?.cancelExport()
        stopProgressPolling()
        session = nil
        state = .idle
    }

    func reset() {
        state = .idle
    }

    // MARK: - Overlay layers

    private func makeAnimationTool(
        overlays: [TextOverlayItem],
        showWatermark: Bool
    ) -> AVVideoCompositionCoreAnimationTool {
        let renderSize = RenderSpec.renderSize

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)

        let parentLayer = CALayer()
        parentLayer.frame = videoLayer.frame
        parentLayer.addSublayer(videoLayer)

        for overlay in overlays {
            parentLayer.addSublayer(textLayer(for: overlay, in: renderSize))
        }

        if showWatermark {
            parentLayer.addSublayer(watermarkLayer(in: renderSize))
        }

        return AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
    }

    /// プレビューと同じ正規化座標から焼き込み位置を算出。
    /// 注意: CALayer の座標系は左下原点(UIKitと逆)。y は反転する。
    private func textLayer(for overlay: TextOverlayItem, in renderSize: CGSize) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = overlay.text
        layer.font = UIFont.systemFont(ofSize: overlay.fontSize, weight: .bold)
        layer.fontSize = overlay.fontSize
        layer.foregroundColor = UIColor.white.cgColor
        layer.backgroundColor = UIColor.black.withAlphaComponent(0.55).cgColor
        layer.cornerRadius = 8
        layer.alignmentMode = .center
        layer.contentsScale = UIScreen.main.scale
        layer.isWrapped = false

        let textSize = (overlay.text as NSString).size(
            withAttributes: [.font: UIFont.systemFont(ofSize: overlay.fontSize, weight: .bold)]
        )
        let padded = CGSize(width: textSize.width + 32, height: textSize.height + 12)

        let centerX = overlay.relativePosition.x * renderSize.width
        let centerYFromTop = overlay.relativePosition.y * renderSize.height
        let centerY = renderSize.height - centerYFromTop // 左下原点へ変換

        layer.frame = CGRect(
            x: centerX - padded.width / 2,
            y: centerY - padded.height / 2,
            width: padded.width,
            height: padded.height
        )
        return layer
    }

    private func watermarkLayer(in renderSize: CGSize) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = "ShortLab"
        let fontSize: CGFloat = 48
        layer.font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        layer.fontSize = fontSize
        layer.foregroundColor = UIColor.white.withAlphaComponent(0.7).cgColor
        layer.alignmentMode = .right
        layer.contentsScale = UIScreen.main.scale

        let width: CGFloat = 300
        let height: CGFloat = 60
        // 右下(左下原点座標系なので y は小さい値)
        layer.frame = CGRect(
            x: renderSize.width - width - 32,
            y: 40,
            width: width,
            height: height
        )
        return layer
    }

    // MARK: - Progress polling

    private func startProgressPolling() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let session = self.session else { return }
                if case .exporting = self.state {
                    self.state = .exporting(progress: session.progress)
                }
            }
        }
    }

    private func stopProgressPolling() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
