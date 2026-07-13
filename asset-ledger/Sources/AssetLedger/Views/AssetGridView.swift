import SwiftUI

/// サムネグリッド（新しい順・フォルダ横断）
struct AssetGridView: View {
    @EnvironmentObject var store: LibraryStore
    let assets: [Asset]

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(assets) { asset in
                    AssetGridCell(asset: asset, isSelected: store.selectedAssetID == asset.id)
                        .onTapGesture(count: 2) {
                            store.revealInFinder(asset)
                        }
                        .onTapGesture {
                            store.selectedAssetID = asset.id
                            store.markViewed(asset.id)
                        }
                        .contextMenu {
                            Button("Finderで表示") { store.revealInFinder(asset) }
                            Button("既定のアプリで開く") { store.openWithDefaultApp(asset) }
                            Divider()
                            Button(asset.isFavorite ? "お気に入りを外す" : "お気に入りに追加") {
                                store.toggleFavorite(asset.id)
                            }
                        }
                }
            }
            .padding(12)
        }
    }
}

struct AssetGridCell: View {
    let asset: Asset
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                ThumbnailImageView(asset: asset)
                    .frame(minWidth: 140, minHeight: 140)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                    )

                // NEWバッジ（未閲覧）
                if !asset.isViewed {
                    Text("NEW")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                // 元ファイル消失バッジ
                if asset.isMissing {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .shadow(radius: 2)
                        .padding(6)
                        .help("元ファイルが見つかりません")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if asset.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .shadow(radius: 2)
                        .padding(6)
                }
            }
            .overlay(alignment: .bottomLeading) {
                Text(asset.fileType.label)
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.black.opacity(0.55), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(6)
            }

            Text(asset.fileName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(asset.isMissing ? .secondary : .primary)
        }
    }
}
