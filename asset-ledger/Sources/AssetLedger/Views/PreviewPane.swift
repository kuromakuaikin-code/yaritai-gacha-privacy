import SwiftUI
import SceneKit

/// 右ペイン: 選択素材のプレビューとメタ情報編集
struct PreviewPane: View {
    @EnvironmentObject var store: LibraryStore

    var selectedAsset: Asset? {
        guard let id = store.selectedAssetID else { return nil }
        return store.assets.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let asset = selectedAsset {
                AssetDetailView(asset: asset)
                    .id(asset.id) // 選択が変わったら状態をリセット
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("素材を選択するとプレビューを表示します")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct AssetDetailView: View {
    @EnvironmentObject var store: LibraryStore
    let asset: Asset

    @State private var scene: SCNScene?
    @State private var sceneLoadFailed = false
    @State private var tagsText = ""
    @State private var noteText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                previewArea
                    .frame(height: 280)
                    .frame(maxWidth: .infinity)
                    .background(Color(nsColor: .underPageBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if asset.isMissing {
                    Label("元ファイルが見つかりません", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.callout)
                }

                // ファイル情報
                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.fileName)
                        .font(.headline)
                        .textSelection(.enabled)
                    Text(asset.filePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    HStack {
                        Text(asset.fileType.label)
                        Text(ByteCountFormatter.string(fromByteCount: asset.fileSize, countStyle: .file))
                        Text(asset.createdAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                HStack {
                    Button {
                        store.toggleFavorite(asset.id)
                    } label: {
                        Label(asset.isFavorite ? "お気に入り解除" : "お気に入り",
                              systemImage: asset.isFavorite ? "star.fill" : "star")
                    }
                    Button("Finderで表示") { store.revealInFinder(asset) }
                    Button("開く") { store.openWithDefaultApp(asset) }
                }
                .controlSize(.small)

                Divider()

                // タグ（カンマ区切りで編集）
                VStack(alignment: .leading, spacing: 4) {
                    Text("タグ").font(.caption).foregroundStyle(.secondary)
                    TextField("例: キャラ, 武器, trellis", text: $tagsText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { commitTags() }
                    if !asset.tags.isEmpty {
                        FlowTagsView(tags: asset.tags)
                    }
                }

                // メモ
                VStack(alignment: .leading, spacing: 4) {
                    Text("メモ").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $noteText)
                        .font(.body)
                        .frame(height: 60)
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(nsColor: .separatorColor)))
                        .onChange(of: noteText) { _, newValue in
                            store.update(asset.id) { $0.note = newValue.isEmpty ? nil : newValue }
                        }
                }
            }
            .padding(12)
        }
        .onAppear {
            tagsText = asset.tags.joined(separator: ", ")
            noteText = asset.note ?? ""
        }
        .task(id: asset.id) {
            await loadSceneIfNeeded()
        }
    }

    @ViewBuilder
    private var previewArea: some View {
        if asset.fileType.is3D {
            if let scene {
                // ドラッグで回転（カメラコントロール）
                SceneView(scene: scene,
                          options: [.allowsCameraControl, .autoenablesDefaultLighting])
            } else if sceneLoadFailed {
                VStack(spacing: 8) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(asset.fileType == .glb
                         ? "GLBの3Dプレビューは未対応です（v0.2予定）"
                         : "3Dモデルを読み込めませんでした")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                ProgressView()
            }
        } else if asset.fileType == .image {
            ImageZoomView(url: asset.fileURL)
        } else {
            Image(systemName: "doc")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
        }
    }

    private func loadSceneIfNeeded() async {
        guard asset.fileType.is3D, !asset.isMissing else {
            sceneLoadFailed = asset.fileType.is3D
            return
        }
        let url = asset.fileURL
        let type = asset.fileType
        let loaded = await Task.detached(priority: .userInitiated) { () -> SCNScene? in
            ThumbnailGenerator.loadScene(url: url, type: type)
        }.value
        if let loaded {
            loaded.background.contents = NSColor.underPageBackgroundColor
            scene = loaded
        } else {
            sceneLoadFailed = true
        }
    }

    private func commitTags() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        store.update(asset.id) { $0.tags = tags }
    }
}

/// 画像プレビュー（拡大縮小スライダー付き）
private struct ImageZoomView: View {
    let url: URL
    @State private var image: NSImage?
    @State private var zoom: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 4) {
            if let image {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300 * zoom, height: 220 * zoom)
                }
                Slider(value: $zoom, in: 1...4)
                    .frame(maxWidth: 160)
                    .controlSize(.mini)
            } else {
                ProgressView()
            }
        }
        .padding(4)
        .task(id: url) {
            image = await Task.detached(priority: .userInitiated) { () -> NSImage? in
                NSImage(contentsOf: url)
            }.value
        }
    }
}

/// タグをシンプルに並べる（プロトタイプなので折返しは簡易）
private struct FlowTagsView: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
            }
        }
    }
}
