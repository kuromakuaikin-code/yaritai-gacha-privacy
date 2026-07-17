import SwiftUI
import SwiftData
import PhotosUI

/// CAM / PhotoAddView: カメラ撮影またはアルバムから複数選択して保存
struct PhotoAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscription

    let project: Project

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showPaywall = false
    @State private var isSaving = false
    @State private var savedCount = 0
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Button {
                    guard gate() else { return }
                    showCamera = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                        Text("カメラで撮影")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
                .buttonStyle(.borderedProminent)

                PhotosPicker(selection: $pickerItems, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                        Text("アルバムから選択")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
                .buttonStyle(.bordered)

                if savedCount > 0 {
                    Label("\(savedCount)枚 保存しました", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.headline)
                }

                if isSaving {
                    ProgressView("保存中…")
                }

                Spacer()

                Text("保存時のタグは「施工中」になります。\nあとから写真ごとに変更できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
            .navigationTitle("写真を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView { image in
                    save(images: [image])
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .onChange(of: pickerItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                loadAndSave(items: newItems)
            }
            .alert("保存できませんでした", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    /// 保存前の課金チェック（仕様 7 章）
    private func gate() -> Bool {
        if subscription.canUsePremiumFeatures { return true }
        showPaywall = true
        return false
    }

    private func loadAndSave(items: [PhotosPickerItem]) {
        guard gate() else {
            pickerItems = []
            return
        }
        isSaving = true
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            save(images: images)
            pickerItems = []
            isSaving = false
        }
    }

    private func save(images: [UIImage]) {
        guard gate() else { return }
        for image in images {
            do {
                let saved = try MediaStore.savePhoto(image, projectId: project.id)
                let photo = SitePhoto(fileName: saved.fileName,
                                      thumbFileName: saved.thumbFileName,
                                      takenAt: Date(),
                                      tag: .during)
                photo.project = project
                modelContext.insert(photo)
                savedCount += 1
            } catch {
                errorMessage = "写真の保存中にエラーが発生しました。空き容量をご確認ください。"
            }
        }
    }
}

#Preview {
    PhotoAddView(project: PreviewData.sampleProject)
        .environment(SubscriptionManager())
        .modelContainer(PreviewData.container)
}
