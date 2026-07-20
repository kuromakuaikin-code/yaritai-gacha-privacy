import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: PurchaseStore
    @Environment(\.modelContext) private var context
    @Query private var pets: [Pet]
    @Query private var records: [HealthRecord]

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
                        Label("プレミアム利用中（広告なし・ペット/記録数無制限）", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(AppConfig.tintColor)
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
                    Text("プレミアム：広告非表示＋ペット・記録数無制限（無料版はペット\(AppConfig.freePetLimit)匹・記録\(AppConfig.freeRecordLimit)件まで）。広告非表示のみの購入も可能です。")
                }

                Section("ペット") {
                    NavigationLink {
                        PetManagementView()
                    } label: {
                        Label("ペットを追加/編集", systemImage: "pawprint.fill")
                    }
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
                        exportDocument = BackupJSONDocument(data: BackupService.export(pets: pets, records: records) ?? Data())
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
                    Text("ペットと記録をJSONファイルとして書き出し・読み込みできます。機種変更時のデータ移行にご利用ください。")
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
                defaultFilename: "pethealthmemo-backup"
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
                  let outcome = BackupService.importData(data, into: context) else {
                importMessage = "読み込みに失敗しました。ファイル形式をご確認ください。"
                showImportResult = true
                return
            }
            importMessage = "ペット\(outcome.petCount)匹・記録\(outcome.recordCount)件を読み込みました。"
            showImportResult = true
        case .failure:
            importMessage = "読み込みに失敗しました。"
            showImportResult = true
        }
    }
}

// MARK: - ペット管理

struct PetManagementView: View {
    @EnvironmentObject private var store: PurchaseStore
    @Environment(\.modelContext) private var context
    @Query(sort: \Pet.createdAt) private var pets: [Pet]

    @State private var showAdd = false
    @State private var editing: Pet?
    @State private var showPaywall = false

    var body: some View {
        List {
            if pets.isEmpty {
                Text("ペットが登録されていません。右上の＋から追加しましょう")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pets) { pet in
                    Button {
                        editing = pet
                    } label: {
                        PetRow(pet: pet)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: delete)
            }

            if !AppConfig.freeTrial, !store.isUnlimited, pets.count >= AppConfig.freePetLimit {
                Section {
                    Label("無料版はペット\(AppConfig.freePetLimit)匹まで登録できます。プレミアムで無制限に登録できます", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("ペットを追加/編集")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addTapped()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddEditPetView(pet: nil)
        }
        .sheet(item: $editing) { pet in
            AddEditPetView(pet: pet)
        }
        .alert("登録上限に達しました", isPresented: $showPaywall) {
            Button("OK") {}
        } message: {
            Text("無料版はペット\(AppConfig.freePetLimit)匹まで登録できます。設定タブからプレミアムで無制限に登録できます。")
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, pets.count >= AppConfig.freePetLimit {
            showPaywall = true
        } else {
            showAdd = true
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(pets[index])
        }
    }
}

private struct PetRow: View {
    let pet: Pet

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: pet.species.icon)
                .foregroundStyle(AppConfig.tintColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(pet.name.isEmpty ? "(名前未設定)" : pet.name)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(pet.species.label)
                    if !pet.breed.isEmpty {
                        Text("・").foregroundStyle(.tertiary)
                        Text(pet.breed)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct AddEditPetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let pet: Pet?

    @State private var name = ""
    @State private var species: PetSpecies = .dog
    @State private var breed = ""
    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var memo = ""

    private var isEditing: Bool { pet != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("名前", text: $name)
                    Picker("種類", selection: $species) {
                        ForEach(PetSpecies.allCases) { s in
                            Label(s.label, systemImage: s.icon).tag(s)
                        }
                    }
                    TextField("犬種・猫種など", text: $breed)
                }

                Section("誕生日") {
                    Toggle("設定しない", isOn: Binding(
                        get: { !hasBirthday },
                        set: { hasBirthday = !$0 }
                    ))
                    if hasBirthday {
                        DatePicker("誕生日", selection: $birthday, displayedComponents: .date)
                    }
                }

                Section("メモ") {
                    TextField("性格・かかりつけ病院・持病など", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isEditing {
                    Section {
                        Button("このペットを削除（記録も全て削除されます）", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "ペットを編集" : "ペットを追加")
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
        }
    }

    private func load() {
        guard let pet else { return }
        name = pet.name
        species = pet.species
        breed = pet.breed
        if let birthdayValue = pet.birthday {
            hasBirthday = true
            birthday = birthdayValue
        }
        memo = pet.memo
    }

    private func save() {
        let target = pet ?? Pet()
        target.name = name
        target.species = species
        target.breed = breed
        target.birthday = hasBirthday ? birthday : nil
        target.memo = memo
        if pet == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let pet {
            context.delete(pet)
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
                            .strokeBorder(AppConfig.tintColor, lineWidth: 2)
                            .background(Circle().fill(i < currentInput.count ? AppConfig.tintColor : Color.clear))
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
