import SwiftUI
import SwiftData

/// 写真タップ時のシート: 拡大表示・タグ変更・キャプション編集・削除
struct PhotoDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let photo: SitePhoto

    @State private var caption = ""
    @State private var tag: PhotoTag = .during
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let image = MediaStore.loadPhoto(photo) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Color(.secondarySystemBackground)
                            .frame(height: 240)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    HStack {
                        Label(DateFormats.dateJP.string(from: photo.takenAt), systemImage: "calendar")
                        Text(DateFormats.time.string(from: photo.takenAt))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("工程タグ")
                            .font(.subheadline.bold())
                        Picker("工程タグ", selection: $tag) {
                            ForEach(PhotoTag.allCases) { t in
                                Text(t.labelJP).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("キャプション")
                            .font(.subheadline.bold())
                            .padding(.top, 8)
                        TextField("例: 分電盤 配線完了", text: $caption)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("この写真を削除", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 16)
                }
                .padding()
            }
            .navigationTitle("写真")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                caption = photo.caption ?? ""
                tag = photo.tag
            }
            .alert("写真を削除しますか？", isPresented: $showDeleteConfirm) {
                Button("削除", role: .destructive) {
                    deletePhoto()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。")
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        photo.tag = tag
        photo.caption = caption.isEmpty ? nil : caption
    }

    private func deletePhoto() {
        MediaStore.deleteFiles(of: photo)
        modelContext.delete(photo)
        dismiss()
    }
}

#Preview {
    PhotoDetailSheet(photo: PreviewData.samplePhoto)
        .modelContainer(PreviewData.container)
}
