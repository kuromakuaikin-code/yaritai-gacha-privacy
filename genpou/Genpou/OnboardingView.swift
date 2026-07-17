import SwiftUI
import SwiftData
import PhotosUI

/// 初回起動時のオンボーディング。3 枚の紹介ページ + 会社情報フォーム。
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionManager.self) private var subscription
    @Query private var profiles: [CompanyProfile]

    @State private var page = 0
    @State private var companyName = ""
    @State private var logoItem: PhotosPickerItem?
    @State private var logoImage: UIImage?

    var body: some View {
        TabView(selection: $page) {
            featurePage(
                symbol: "square.grid.3x3.fill",
                title: "写真を案件ごとに整理",
                message: "LINE やカメラロールに散らばる現場写真を、\n案件単位で施工前・施工中・施工後に分けて管理。"
            )
            .tag(0)

            featurePage(
                symbol: "doc.richtext",
                title: "その場で正式 PDF",
                message: "日報も完了報告書も iPhone だけで作成。\n電波がない現場でも生成できます。"
            )
            .tag(1)

            featurePage(
                symbol: "square.and.arrow.up",
                title: "そのまま共有",
                message: "できあがった PDF は LINE・メールで\n元請けにすぐ送れます。"
            )
            .tag(2)

            formPage
                .tag(3)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color(.systemGroupedBackground))
        .interactiveDismissDisabled()
    }

    private func featurePage(symbol: String, title: String, message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text(title)
                .font(.title.bold())
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                withAnimation { page += 1 }
            } label: {
                Text("次へ")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
        .padding()
    }

    private var formPage: some View {
        VStack(spacing: 0) {
            Text("会社情報を登録")
                .font(.title2.bold())
                .padding(.top, 40)
            Text("PDF 報告書のヘッダに使われます")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Form {
                Section("屋号・会社名（必須）") {
                    TextField("例: 山田電設", text: $companyName)
                        .font(.title3)
                }
                Section("ロゴ（任意）") {
                    PhotosPicker(selection: $logoItem, matching: .images) {
                        HStack {
                            if let logoImage {
                                Image(uiImage: logoImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 44)
                            } else {
                                Image(systemName: "photo.badge.plus")
                                    .font(.title2)
                            }
                            Text(logoImage == nil ? "ロゴ画像を選択" : "変更する")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)

            Button {
                complete()
            } label: {
                Text("はじめる")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(companyName.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
        .onChange(of: logoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    logoImage = image
                }
            }
        }
    }

    private func complete() {
        let name = companyName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let profile = profiles.first ?? {
            let newProfile = CompanyProfile()
            modelContext.insert(newProfile)
            return newProfile
        }()
        profile.companyName = name
        if let logoImage {
            profile.logoFileName = try? MediaStore.saveLogo(logoImage, replacing: profile.logoFileName)
        }
        subscription.startTrialIfNeeded()
        Task { await subscription.refresh() }
        // companyName が入ると RootView 側の fullScreenCover 条件が false になり閉じる
    }
}

#Preview {
    OnboardingView()
        .environment(SubscriptionManager())
        .modelContainer(PreviewData.emptyContainer)
}
