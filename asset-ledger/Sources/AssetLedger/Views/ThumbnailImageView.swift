import SwiftUI
import AppKit

/// ディスク上のサムネJPEGを非同期に読み込んで表示する。
/// 簡易メモリキャッシュ付き（グリッドのスクロールを軽くする）。
struct ThumbnailImageView: View {
    let asset: Asset

    @State private var image: NSImage?

    private static let cache = NSCache<NSString, NSImage>()

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(nsColor: .quaternaryLabelColor)
                    Image(systemName: asset.fileType.is3D ? "cube.transparent" : "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: asset.thumbnailFileName) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = asset.thumbnailURL else { return }
        let key = url.path as NSString
        if let cached = Self.cache.object(forKey: key) {
            image = cached
            return
        }
        let loaded = await Task.detached(priority: .utility) { () -> NSImage? in
            NSImage(contentsOf: url)
        }.value
        if let loaded {
            Self.cache.setObject(loaded, forKey: key)
            image = loaded
        }
    }
}
