import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: PurchaseStore
    @Environment(\.modelContext) private var context
    @Query private var rules: [GarbageRule]

    @AppStorage("passcodeHash") private var passcodeHash = ""
    @State private var showPasscodeSetup = false
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument: BackupJSONDocument?
    @State private var importMessage: String?
    @State private var showImportResult = false

    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 19
    @AppStorage("reminderMinute") private var reminderMinute = 0

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var comps = DateComponents()
                comps.hour = reminderHour
                comps.minute = reminderMinute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = comps.hour ?? 19
                reminderMinute = comps.minute ?? 0
                applyReminder()
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("プレミアム") {
                    if store.premium {
                        Label("プレミアム利用中（広告なし・ルール数無制限・リマインダー通知）", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Color.gomiTint)
                    } else {
                        Button {
                            Task {
                                await store.buyPremium()
                                applyReminder()
                            }
                        } label: {
                            HStack {
                                Label("プレミアムにアップグレード", systemImage: "star.fill")
                                Spacer()
                                Text(AppConfig.premiumPriceLabel).foregroundStyle(.secondary)
                            }
                        }
                        if !store.adFree {
                            Button {
                                Task { await store.buyAdFree() }
                            } label: {
                                HStack {
                                    Label("広告非表示のみ購入", systemImage: "rectangle.slash")
                                    Spacer()
                                    Text(AppConfig.adFreePriceLabel).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Button("購入を復元") {
                            Task {
                                await store.restore()
                                applyReminder()
                            }
                        }
                    }
                } footer: {
                    Text("プレミアム：広告非表示＋ルール数無制限＋リマインダー通知（無料版は\(AppConfig.freeRuleLimit)件まで）。広告非表示のみの購入も可能です。")
                }

                Section("リマインダー通知") {
                    if store.isUnlimited {
                        Toggle("毎日リマインダーを受け取る", isOn: $reminderEnabled)
                            .onChange(of: reminderEnabled) { _, _ in applyReminder() }
                        if reminderEnabled {
                            DatePicker("通知時刻", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                        }
                    } else {
                        HStack {
                            Text("毎日リマインダーを受け取る")
                            Spacer()
                            Text("プレミアムで有効化")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("設定した時刻に、その日出せるごみをお知らせします。端末の通知許可が必要です。通知内容はアプリを開くたびに最新のルールで更新されます。")
                }

                Section("セキュリティ") {
                    if passcodeHash.isEmpty {
                        Button("パスコードを設定") { showPasscodeSetup = true }
                    } else {
                        Button("パスコードを変更") { showPasscodeSetup = true }
                        Button("パスコードを解除", role: .destructive) { passcodeHash = "" }
                    }
                }

                Section("バックアップ") {
                    Button {
                        exportDocument = BackupJSONDocument(data: BackupService.export(rules: rules) ?? Data())
                        showExporter = true
                    } label: {
                        Label("バックアップを書き出す", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("バックアップを読み込む", systemImage: "square.and.arrow.down")
                    }
                } footer: {
                    Text("収集ルールをJSONファイルとして書き出し・読み込みできます。機種変更時のデータ移行にご利用ください。")
                }

                Section("アプリについて") {
                    Link("プライバシーポリシー", destination: AppConfig.privacyURL)
                    Link("利用規約", destination: AppConfig.termsURL)
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(AppConfig.version).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
            .onAppear { applyReminder() }
            .sheet(isPresented: $showPasscodeSetup) {
                PasscodeSetupView()
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "gomicalendar-backup"
            ) { _ in }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json]
            ) { result in
                handleImport(result)
            }
            .alert("読み込み結果", isPresented: $showImportResult, presenting: importMessage) { _ in
                Button("OK") {}
            } message: { message in
                Text(message)
            }
        }
    }

    /// 現在の設定・保有プランに応じて、当日のカテゴリでリマインダー通知を組み直す（ベストエフォート）
    private func applyReminder() {
        let todayCategories = rules.filter { $0.applies(on: Date()) }.map { $0.categoryName }
        let enabled = reminderEnabled && store.isUnlimited
        Task {
            await NotificationService.reschedule(
                enabled: enabled,
                hour: reminderHour,
                minute: reminderMinute,
                todayCategories: todayCategories
            )
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url),
                  let count = BackupService.importData(data, into: context) else {
                importMessage = "読み込みに失敗しました。ファイル形式をご確認ください。"
                showImportResult = true
                return
            }
            importMessage = "\(count)件のルールを読み込みました。"
            showImportResult = true
        case .failure:
            importMessage = "読み込みに失敗しました。"
            showImportResult = true
        }
    }
}

// MARK: - パスコード設定

struct PasscodeSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("passcodeHash") private var passcodeHash = ""
    @State private var first = ""
    @State private var confirm = ""
    @State private var stage = 0
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(stage == 0 ? "新しいパスコード（4桁）" : "もう一度入力してください")
                    .font(.headline)

                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .strokeBorder(Color.gomiTint, lineWidth: 2)
                            .background(Circle().fill(i < currentInput.count ? Color.gomiTint : Color.clear))
                            .frame(width: 16, height: 16)
                    }
                }

                if let errorText {
                    Text(errorText).font(.caption).foregroundStyle(.red)
                }

                keypad
            }
            .padding()
            .navigationTitle("パスコード設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private var currentInput: String { stage == 0 ? first : confirm }

    private var keypad: some View {
        let keys = ["1","2","3","4","5","6","7","8","9","","0","⌫"]
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(76)), count: 3), spacing: 14) {
            ForEach(keys, id: \.self) { key in
                if key.isEmpty {
                    Color.clear.frame(height: 64)
                } else {
                    Button {
                        tap(key)
                    } label: {
                        Text(key)
                            .font(.title2.weight(.semibold))
                            .frame(width: 68, height: 64)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func tap(_ key: String) {
        errorText = nil
        if key == "⌫" {
            if stage == 0 { if !first.isEmpty { first.removeLast() } }
            else { if !confirm.isEmpty { confirm.removeLast() } }
            return
        }
        if stage == 0 {
            guard first.count < 4 else { return }
            first += key
            if first.count == 4 { stage = 1 }
        } else {
            guard confirm.count < 4 else { return }
            confirm += key
            if confirm.count == 4 {
                if confirm == first {
                    passcodeHash = Passcode.hash(first)
                    dismiss()
                } else {
                    errorText = "一致しませんでした。もう一度どうぞ"
                    first = ""; confirm = ""; stage = 0
                }
            }
        }
    }
}

// MARK: - JSON書き出し用ドキュメント

struct BackupJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - ローカル通知（プレミアム限定・ベストエフォート実装）

enum NotificationService {
    static let identifier = "gomicalendar.dailyReminder"

    /// 毎日決まった時刻に、当日該当するカテゴリを知らせるローカル通知を(再)登録する。
    /// 通知本文は登録した時点の当日ルールから作られる簡易実装で、日をまたいでも自動更新はされない
    /// （アプリ起動時・設定変更時に呼び直すことで内容を最新化している）。
    static func reschedule(enabled: Bool, hour: Int, minute: Int, todayCategories: [String]) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled else { return }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "ゴミ出しリマインダー"
            content.body = todayCategories.isEmpty
                ? "今日該当する収集ルールはありません。ルール設定をご確認ください"
                : "今日は「\(todayCategories.joined(separator: "・"))」の日です"
            content.sound = .default

            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                center.add(request) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } catch {
            // 通知の許可が得られない・登録に失敗した場合は何もしない（次回設定変更時などに再試行）
        }
    }
}
