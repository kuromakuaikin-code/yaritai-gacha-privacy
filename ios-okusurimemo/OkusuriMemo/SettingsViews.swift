import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: PurchaseStore
    @Environment(\.modelContext) private var context
    @Query private var members: [FamilyMember]

    @AppStorage("passcodeHash") private var passcodeHash = ""
    @State private var showPasscodeSetup = false
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument: BackupJSONDocument?
    @State private var importMessage: String?
    @State private var showImportResult = false

    var body: some View {
        NavigationStack {
            List {
                Section("プレミアム") {
                    if store.premium {
                        Label("プレミアム利用中（広告なし・登録数無制限）", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Color.appTint)
                    } else {
                        Button {
                            Task { await store.buyPremium() }
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
                            Task { await store.restore() }
                        }
                    }
                } footer: {
                    Text("プレミアム：広告非表示＋ご家族・お薬の登録数無制限（無料版はご家族\(AppConfig.freeMemberLimit)人・お薬\(AppConfig.freeMedicationLimit)件まで）。広告非表示のみの購入も可能です。")
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
                        exportDocument = BackupJSONDocument(data: BackupService.export(members: members) ?? Data())
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
                    Text("ご家族・お薬・服薬記録をJSONファイルとして書き出し・読み込みできます。機種変更時のデータ移行にご利用ください。")
                }

                Section {
                    Text("本アプリは、ご家族の服薬状況を記録するための個人用メモアプリです。医療機器ではなく、医学的な助言を目的としたものではありません。服薬に関する判断は、必ず医師・薬剤師の指示に従ってください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("ご利用にあたって")
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
            .sheet(isPresented: $showPasscodeSetup) {
                PasscodeSetupView()
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "okusurimemo-backup"
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
            importMessage = "\(count)件のお薬を読み込みました。"
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
                            .strokeBorder(Color.appTint, lineWidth: 2)
                            .background(Circle().fill(i < currentInput.count ? Color.appTint : Color.clear))
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
