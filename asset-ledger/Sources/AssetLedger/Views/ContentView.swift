import SwiftUI

/// メイン画面: フィルタバー + サムネグリッド + 右ペインプレビュー
struct ContentView: View {
    @EnvironmentObject var store: LibraryStore

    @State private var filterType: AssetFileType?
    @State private var filterFolderID: UUID?
    @State private var filterTag: String?
    @State private var favoritesOnly = false

    var filteredAssets: [Asset] {
        store.assets
            .filter { asset in
                if let filterType, asset.fileType != filterType { return false }
                if let filterFolderID, asset.folderID != filterFolderID { return false }
                if let filterTag, !asset.tags.contains(filterTag) { return false }
                if favoritesOnly && !asset.isFavorite { return false }
                return true
            }
            .sorted { $0.createdAt > $1.createdAt } // 新しい順
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                filterBar
                Divider()
                if store.folders.isEmpty {
                    emptyState
                } else {
                    AssetGridView(assets: filteredAssets)
                }
            }
            .frame(minWidth: 480, minHeight: 400)

            PreviewPane()
                .frame(minWidth: 280, idealWidth: 340, maxWidth: 480)
        }
        .frame(minWidth: 800, minHeight: 480)
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Picker("種別", selection: $filterType) {
                Text("すべて").tag(AssetFileType?.none)
                ForEach(AssetFileType.allCases) { type in
                    Text(type.label).tag(AssetFileType?.some(type))
                }
            }
            .frame(maxWidth: 140)

            Picker("フォルダ", selection: $filterFolderID) {
                Text("すべて").tag(UUID?.none)
                ForEach(store.folders) { folder in
                    Text(folder.name).tag(UUID?.some(folder.id))
                }
            }
            .frame(maxWidth: 180)

            Picker("タグ", selection: $filterTag) {
                Text("すべて").tag(String?.none)
                ForEach(store.allTags, id: \.self) { tag in
                    Text(tag).tag(String?.some(tag))
                }
            }
            .frame(maxWidth: 160)

            Toggle(isOn: $favoritesOnly) {
                Image(systemName: favoritesOnly ? "star.fill" : "star")
            }
            .toggleStyle(.button)
            .help("お気に入りのみ表示")

            Spacer()

            Text("\(filteredAssets.count)件")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("監視フォルダが未設定です")
                .font(.title3)
            Text("設定（⌘,）から出力フォルダを追加してください")
                .foregroundStyle(.secondary)
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Text("設定を開く…")
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
