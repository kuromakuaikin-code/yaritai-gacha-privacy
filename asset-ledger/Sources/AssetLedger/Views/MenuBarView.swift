import SwiftUI

/// メニューバー常駐のポップオーバー: 直近5件のサムネ表示
struct MenuBarView: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("直近の素材")
                    .font(.headline)
                Spacer()
                if store.unviewedCount > 0 {
                    Text("NEW \(store.unviewedCount)")
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                        .foregroundStyle(.white)
                }
            }

            if store.recentAssets.isEmpty {
                Text("素材がまだありません")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding(.vertical, 8)
            } else {
                ForEach(store.recentAssets) { asset in
                    Button {
                        openMain(selecting: asset)
                    } label: {
                        HStack(spacing: 8) {
                            ThumbnailImageView(asset: asset)
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(asset.fileName)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(asset.createdAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !asset.isViewed {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            HStack {
                Button("メイン画面を開く") {
                    openMain(selecting: nil)
                }
                Spacer()
                Button("終了") {
                    NSApp.terminate(nil)
                }
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 280)
    }

    private func openMain(selecting asset: Asset?) {
        if let asset {
            store.selectedAssetID = asset.id
            store.markViewed(asset.id)
        }
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
