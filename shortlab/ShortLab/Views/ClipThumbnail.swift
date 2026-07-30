import SwiftUI
import AVFoundation
import UIKit

/// クリップのサムネイル(トリム開始位置の1コマ)を取得する。
/// 同じ(ファイル, トリム開始位置)は NSCache に載せて再生成しない。
/// 位置は 0.1 秒単位でキー化し、トリムを微調整するたびに作り直すのを防ぐ。
@MainActor
enum ThumbnailLoader {
    private static let cache = NSCache<NSString, UIImage>()

    static func cacheKey(for clip: VideoClip) -> String {
        "\(clip.url.lastPathComponent)-\(Int(clip.trimStart * 10))"
    }

    static func thumbnail(for clip: VideoClip) async -> UIImage? {
        let key = cacheKey(for: clip) as NSString
        if let hit = cache.object(forKey: key) { return hit }

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: clip.url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 320)
        // ちょうど境界のフレームは取得に失敗することがあるため少しだけ内側を見る
        let time = RenderSpec.time(clip.trimStart + 0.05)
        guard let cgImage = try? await generator.image(at: time).image else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key)
        return image
    }
}

/// サムネイル表示ビュー(かんたんモードの一覧・しっかり編集のタイムラインで共用)
struct ClipThumbnailView: View {
    let clip: VideoClip
    var cornerRadius: CGFloat = 10

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.black.opacity(0.25)
                Image(systemName: "film")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: ThumbnailLoader.cacheKey(for: clip)) {
            image = await ThumbnailLoader.thumbnail(for: clip)
        }
    }
}
