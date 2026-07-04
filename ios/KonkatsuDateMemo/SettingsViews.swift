import SwiftUI
import SwiftData

// MARK: - 設定タブ

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query private var partners: [Partner]
    @Query private var myTopics: [MyTopic]

    @AppStorage("passcodeHash") private var passcodeHash = ""

    @State private var showPaywall = false
    @State private var showPasscodeSheet = false
    @State private var exportDoc: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var confirmWipe = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section("プラン") {
                    Button {
                        showPaywall = true
                    } label: {
                        row("⭐ プレミアム", store.premium ? "有効" : "未購入")
                    }
                    Button {
                        if store.premium {
                            message = "プレミアムに広告なしが含まれています"
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        row("🚫 広告なし",
                            store.premium ? "プレミアムに込み" : (store.adFree ? "有効" : "未購入"))
                    }
                    if !AppConfig.freeTrial {
                        Button("購入を復元") { Task { await store.restore() } }
                    }
                }

                Section("セキュリティ") {
                    if passcodeHash.isEmpty {
                        Button("🔒 パスコードロックを設定") { showPasscodeSheet = true }
                    } else {
                        Button("🔓 パスコードロックを解除", role: .destructive) {
                            passcodeHash = ""
                        }
                    }
                }

                Section("データ") {
                    Button("📤 バックアップを書き出す") { exportBackup() }
                    Button("📥 バックアップを読み込む") { showImporter = true }
                    Button("🗑 全データを削除", role: .destructive) { confirmWipe = true }
                } footer: {
                    Text("データはすべてこの端末の中にだけ保存され、外部には送信されません。Web版のバックアップファイルもそのまま読み込めます。")
                }

                Section("アプリについて") {
                    Link("📄 利用規約", destination: AppConfig.termsURL)
                    Link("🔒 プライバシーポリシー", destination: AppConfig.privacyURL)
                } footer: {
                    Text("婚活デートメモ v\(AppConfig.version)")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("設定")
            .sheet(isPresented: $showPaywall) { PaywallView(message: nil) }
            .sheet(isPresented: $showPasscodeSheet) { PasscodeSetView() }
            .fileExporter(isPresented: $showExporter,
                          document: exportDoc,
                          contentType: .json,
                          defaultFilename: "konkatsu-date-memo-backup") { _ in }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.json]) { result in
                importBackup(result)
            }
            .confirmationDialog("すべてのお相手と記録を削除します。元に戻せません。",
                                isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("削除する", role: .destructive) { wipe() }
            }
            .alert(message ?? "", isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func exportBackup() {
        do {
            let data = try Backup.export(partners: partners, myTopics: myTopics,
                                         premium: store.premium, adFree: store.adFree)
            exportDoc = BackupDocument(data: data)
            showExporter = true
        } catch {
            message = "書き出しに失敗しました"
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        do {
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            let count = try Backup.restore(data: data, context: context)
            message = "バックアップ（お相手\(count)名）を読み込みました"
        } catch {
            message = "ファイルを読み込めませんでした"
        }
    }

    private func wipe() {
        do {
            try context.delete(model: Partner.self)
            try context.delete(model: MyTopic.self)
            try context.save()
        } catch {
            message = "削除に失敗しました"
        }
    }
}

// MARK: - パスコード設定

struct PasscodeSetView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("passcodeHash") private var passcodeHash = ""

    @State private var code = ""
    @State private var confirm = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                SecureField("4桁の数字", text: $code)
                    .keyboardType(.numberPad)
                SecureField("確認のためもう一度", text: $confirm)
                    .keyboardType(.numberPad)
                if let error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                Section {
                    Text("※簡易的な画面ロックです。パスコードを忘れると解除できず、アプリの再インストールが必要になります。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("パスコードを設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("設定する") { save() }
                }
            }
        }
    }

    private func save() {
        guard code.count == 4, code.allSatisfy(\.isNumber) else {
            error = "4桁の数字で入力してください"; return
        }
        guard code == confirm else {
            error = "2回の入力が一致しません"; return
        }
        passcodeHash = Passcode.hash(code)
        dismiss()
    }
}

// MARK: - ペイウォール

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PurchaseStore

    let message: String?

    var body: some View {
        NavigationStack {
            List {
                if let message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    feature("💬", "話題リスト全カテゴリを解放（距離を縮める・価値観・真剣交際前の確認）")
                    feature("🔍", "各話題の「深掘りパターン」（会話の流れの例）も全て見られる")
                    feature("👥", "お相手の登録が無制限に（無料版は\(AppConfig.freePartnerLimit)人まで）")
                    feature("🚫", "広告が永続的に非表示（プレミアムに含まれます）")
                    feature("🔁", "買い切りのみ。追加課金・サブスクなし")
                    feature("🔒", "データはこれまで通り端末内にのみ保存")
                }
                Section {
                    Button {
                        Task { await store.buyPremium(); dismiss() }
                    } label: {
                        Text(AppConfig.freeTrial
                             ? "⭐ プレミアムを無料で有効化（テスト中）"
                             : "⭐ プレミアムを購入（\(AppConfig.premiumPriceLabel)）")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .listRowBackground(Color.clear)

                    if !store.isAdFree {
                        Button {
                            Task { await store.buyAdFree(); dismiss() }
                        } label: {
                            Text(AppConfig.freeTrial
                                 ? "🚫 広告なしのみを無料で有効化（テスト中）"
                                 : "🚫 広告なしのみ（\(AppConfig.adFreePriceLabel)・永続）")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("⭐ プレミアム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("あとで") { dismiss() }
                }
            }
        }
    }

    private func feature(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(emoji)
            Text(text).font(.subheadline)
        }
    }
}
