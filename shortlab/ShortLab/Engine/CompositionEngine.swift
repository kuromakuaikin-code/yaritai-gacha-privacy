import AVFoundation
import CoreGraphics

/// プロジェクト状態から AVMutableComposition + AVMutableVideoComposition を構築する。
/// プレビューと書き出しの両方がここを通ることで「プレビューでは正しいのに書き出すとズレる」を防ぐ。
enum CompositionEngineError: Error, LocalizedError {
    case noVideoTrack(URL)
    case emptyProject

    var errorDescription: String? {
        switch self {
        case .noVideoTrack(let url):
            return "動画トラックが見つかりません: \(url.lastPathComponent)"
        case .emptyProject:
            return "クリップがありません"
        }
    }
}

struct CompositionResult {
    let composition: AVMutableComposition
    let videoComposition: AVMutableVideoComposition
}

enum CompositionEngine {

    /// クリップ列からコンポジションを構築する。
    /// - トリム範囲を insertTimeRange で挿入し、速度は scaleTimeRange で適用
    /// - 各クリップの preferredTransform を解決し、1080x1920 にアスペクトフィットさせる
    static func build(project: EditorProject) async throws -> CompositionResult {
        guard !project.clips.isEmpty else { throw CompositionEngineError.emptyProject }

        let composition = AVMutableComposition()
        guard
            let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid),
            let audioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw CompositionEngineError.emptyProject
        }

        var instructions: [AVMutableVideoCompositionInstruction] = []
        var cursor = CMTime.zero

        for clip in project.clips {
            let asset = AVURLAsset(url: clip.url)
            let assetVideoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let srcVideo = assetVideoTracks.first else {
                throw CompositionEngineError.noVideoTrack(clip.url)
            }
            let srcAudio = try await asset.loadTracks(withMediaType: .audio).first

            let start = RenderSpec.time(clip.trimStart)
            let duration = RenderSpec.time(clip.trimEnd - clip.trimStart)
            let sourceRange = CMTimeRange(start: start, duration: duration)

            try videoTrack.insertTimeRange(sourceRange, of: srcVideo, at: cursor)
            if let srcAudio {
                try audioTrack.insertTimeRange(sourceRange, of: srcAudio, at: cursor)
            }

            // 速度適用: 挿入した範囲を timeline 上でスケール
            let insertedRange = CMTimeRange(start: cursor, duration: duration)
            let scaledDuration = RenderSpec.time(clip.timelineDuration)
            if clip.speed != 1.0 {
                videoTrack.scaleTimeRange(insertedRange, toDuration: scaledDuration)
                audioTrack.scaleTimeRange(insertedRange, toDuration: scaledDuration)
            }

            // レイヤーインストラクション(向き補正 + アスペクトフィット)
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: cursor, duration: scaledDuration)

            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            let transform = try await aspectFitTransform(for: srcVideo, into: RenderSpec.renderSize)
            layerInstruction.setTransform(transform, at: cursor)
            instruction.layerInstructions = [layerInstruction]
            instructions.append(instruction)

            cursor = CMTimeAdd(cursor, scaledDuration)
        }

        // BGMトラック(動画長に合わせて末尾カット。動画より短ければそのまま)
        if let music = project.music {
            let musicAsset = AVURLAsset(url: music.url)
            if let srcMusic = try await musicAsset.loadTracks(withMediaType: .audio).first,
               let bgmTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid) {
                let musicDuration = try await musicAsset.load(.duration)
                let insertDuration = CMTimeMinimum(musicDuration, cursor)
                try bgmTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: insertDuration),
                    of: srcMusic, at: .zero)
            }
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = instructions
        videoComposition.renderSize = RenderSpec.renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        return CompositionResult(composition: composition, videoComposition: videoComposition)
    }

    /// 素材の preferredTransform を解決した上で renderSize にアスペクトフィットさせる変換を返す。
    /// iPhone撮影素材は「実データ横向き + 回転transform」が普通なので、
    /// naturalSize に transform を適用した後のサイズで計算しないと縦横が壊れる(頻出バグ)。
    private static func aspectFitTransform(
        for track: AVAssetTrack,
        into renderSize: CGSize
    ) async throws -> CGAffineTransform {
        let naturalSize = try await track.load(.naturalSize)
        let preferred = try await track.load(.preferredTransform)

        let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(preferred)
        let displaySize = CGSize(width: abs(transformedRect.width),
                                 height: abs(transformedRect.height))

        let scale = min(renderSize.width / displaySize.width,
                        renderSize.height / displaySize.height)
        let scaledSize = CGSize(width: displaySize.width * scale,
                                height: displaySize.height * scale)
        let tx = (renderSize.width - scaledSize.width) / 2 - transformedRect.origin.x * scale
        let ty = (renderSize.height - scaledSize.height) / 2 - transformedRect.origin.y * scale

        return preferred
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: tx, y: ty))
    }
}
