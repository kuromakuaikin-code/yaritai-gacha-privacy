import SwiftUI
import AppKit

/// 設定画面: 監視フォルダの追加・削除、サムネ解像度
struct SettingsView: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        Form {
            Section("監視フォルダ") {
                if store.folders.isEmpty {
                    Text("フォルダが登録されていません")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.folders) { folder in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { folder.isActive },
                            set: { store.setFolderActive(folder, $0) }
                        )) {
                            VStack(alignment: .leading) {
                                Text(folder.name)
                                Text(folder.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .truncationMode(.middle)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            store.removeFolder(folder)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .help("この監視フォルダと台帳エントリを削除（元ファイルは消しません）")
                    }
                }
                Button("フォルダを追加…") {
                    addFolder()
                }
            }

            Section("サムネイル") {
                Picker("解像度", selection: $store.thumbnailSize) {
                    Text("256px").tag(256)
                    Text("512px").tag(512)
                }
                .pickerStyle(.segmented)
                Button("全サムネイルを再生成") {
                    store.regenerateAllThumbnails()
                }
                Text("サムネイルは ~/Library/Application Support/AssetLedger/ に保存されます。元ファイルは移動・コピーしません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 400)
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "監視する"
        panel.message = "監視する出力フォルダを選択してください"
        if panel.runModal() == .OK {
            for url in panel.urls {
                store.addFolder(url: url)
            }
        }
    }
}
