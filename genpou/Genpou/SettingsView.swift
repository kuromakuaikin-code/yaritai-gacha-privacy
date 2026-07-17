import SwiftUI
import SwiftData
import PhotosUI

/// SET-01: 設定
struct SettingsView: View {
    @Environment(SubscriptionManager.self) private var subscription
    @Query private var profiles: [CompanyProfile]

    @State private var showPaywall = false

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section("会社情報") {
                NavigationLink {
                    CompanyEditorView()
                } label: {
                    HStack {
                        Text("会社情報を編集")
                        Spacer()
                        Text(profiles.first?.companyName ?? "")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("プラン") {
                HStack {
                    Text("現在のプラン")
                    Spacer()
                    Text(subscription.statusLabelJP)
                        .foregroundStyle(.secondary)
                }
                Button("プラン管理") {
                    showPaywall = true
                }
            }

            Section("サポート") {
                Link("利用規約", destination: URL(string: "https://example.com/terms")!)
                Link("プライバシーポリシー", destination: URL(string: "https://example.com/privacy")!)
                Link("お問い合わせ", destination: URL(string: "mailto:support@example.com")!)
            }

            Section("アプリ情報") {
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
            }

            #if DEBUG
            Section("デバッグ") {
                Button("トライアルを期限切れにする") {
                    subscription.debugExpireTrial()
                }
                Button("トライアルを今日から再開する") {
                    subscription.debugResetTrial()
                }
            }
            #endif
        }
        .navigationTitle("設定")
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

/// 会社情報の編集（設定から）
struct CompanyEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [CompanyProfile]

    @State private var companyName = ""
    @State private var representative = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var logoItem: PhotosPickerItem?
    @State private var logoImage: UIImage?
    @State private var logoChanged = false

    var body: some View {
        Form {
            Section("屋号・会社名（必須）") {
                TextField("例: 山田電設", text: $companyName)
            }
            Section("代表者・連絡先") {
                TextField("代表者名（完了報告書の署名欄に使用）", text: $representative)
                TextField("電話番号", text: $phone)
                    .keyboardType(.phonePad)
                TextField("住所", text: $address)
            }
            Section("ロゴ") {
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
        .navigationTitle("会社情報")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(companyName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear(perform: load)
        .onChange(of: logoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    logoImage = image
                    logoChanged = true
                }
            }
        }
    }

    private func load() {
        guard let profile = profiles.first else { return }
        companyName = profile.companyName
        representative = profile.representative ?? ""
        phone = profile.phone ?? ""
        address = profile.address ?? ""
        logoImage = MediaStore.loadLogo(fileName: profile.logoFileName)
    }

    private func save() {
        let profile = profiles.first ?? {
            let newProfile = CompanyProfile()
            modelContext.insert(newProfile)
            return newProfile
        }()
        profile.companyName = companyName.trimmingCharacters(in: .whitespaces)
        profile.representative = representative.isEmpty ? nil : representative
        profile.phone = phone.isEmpty ? nil : phone
        profile.address = address.isEmpty ? nil : address
        if logoChanged, let logoImage {
            profile.logoFileName = try? MediaStore.saveLogo(logoImage, replacing: profile.logoFileName)
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(SubscriptionManager())
    .modelContainer(PreviewData.container)
}
