import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: PurchaseStore
    @Environment(\.modelContext) private var context
    @Query private var children: [Child]

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
                Section("お子さま") {
                    NavigationLink {
                        ChildManagementView()
                    } label: {
                        Label("お子さまを追加・編集", systemImage: "person.crop.circle.badge.plus")
                    }
                } footer: {
                    Text("無料版はお子さま\(AppConfig.freeChildLimit)人まで登録できます。プレミアムで人数無制限になります。")
                }

                Section("プレミアム") {
                    if store.premium {
                        Label("プレミアム利用中（広告なし・お子さま人数無制限）", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.kodomoTeal)
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
                    Text("プレミアム：広告非表示＋お子さま人数無制限（無料版は\(AppConfig.freeChildLimit)人まで）。広告非表示のみの購入も可能です。")
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
                        exportDocument = BackupJSONDocument(data: BackupService.export(children: children) ?? Data())
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
                    Text("お子さまと記録をJSONファイルとして書き出し・読み込みできます。機種変更時のデータ移行にご利用ください。バックアップファイルにはお子さまの個人情報が含まれるため、保管・共有には十分ご注意ください。")
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
                defaultFilename: "kodomogrowth-backup"
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
            importMessage = "\(count)件の記録を読み込みました。"
            showImportResult = true
        case .failure:
            importMessage = "読み込みに失敗しました。"
            showImportResult = true
        }
    }
}

// MARK: - お子さまの管理

struct ChildManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Child.createdAt) private var children: [Child]

    @State private var showAdd = false
    @State private var editing: Child?

    var body: some View {
        List {
            Section {
                ForEach(children) { child in
                    Button {
                        editing = child
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: child.sex.icon)
                                .foregroundStyle(child.sex.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(child.name.isEmpty ? "(名前未設定)" : child.name)
                                    .foregroundStyle(.primary)
                                Text(mediumDate(child.birthday) + "生まれ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .onDelete(perform: delete)
            } footer: {
                Text("お子さまを削除すると、そのお子さまの成長記録もすべて削除されます。")
            }

            Section {
                Button {
                    showAdd = true
                } label: {
                    Label("お子さまを追加", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("お子さまの管理")
        .sheet(isPresented: $showAdd) {
            ChildEditView(child: nil)
        }
        .sheet(item: $editing) { child in
            ChildEditView(child: child)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(children[index])
        }
    }
}

struct ChildEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \Child.createdAt) private var children: [Child]

    let child: Child?

    @State private var name = ""
    @State private var birthday = Date()
    @State private var sex: Sex = .unspecified
    @State private var memo = ""
    @State private var showPaywall = false

    private var isEditing: Bool { child != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("プロフィール") {
                    TextField("お名前（ニックネーム可）", text: $name)
                    DatePicker("誕生日", selection: $birthday, displayedComponents: .date)
                    Picker("性別", selection: $sex) {
                        ForEach(Sex.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("メモ") {
                    TextField("アレルギー、かかりつけ医など", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isEditing {
                    Section {
                        Button("このお子さまを削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    } footer: {
                        Text("削除すると、このお子さまの成長記録もすべて削除されます。")
                    }
                }
            }
            .navigationTitle(isEditing ? "お子さまを編集" : "お子さまを登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.isEmpty)
                }
            }
            .onAppear(perform: load)
            .alert("お子さまの登録上限に達しました", isPresented: $showPaywall) {
                Button("OK") {}
            } message: {
                Text("無料版はお子さま\(AppConfig.freeChildLimit)人まで登録できます。設定タブのプレミアムで人数無制限になります。")
            }
        }
    }

    private func load() {
        guard let child else { return }
        name = child.name
        birthday = child.birthday
        sex = child.sex
        memo = child.memo
    }

    private func save() {
        if child == nil, !AppConfig.freeTrial, !store.isUnlimited, children.count >= AppConfig.freeChildLimit {
            showPaywall = true
            return
        }
        let target = child ?? Child()
        target.name = name
        target.birthday = birthday
        target.sex = sex
        target.memo = memo
        if child == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let child {
            context.delete(child)
        }
        dismiss()
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
                            .strokeBorder(Color.kodomoTeal, lineWidth: 2)
                            .background(Circle().fill(i < currentInput.count ? Color.kodomoTeal : Color.clear))
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
