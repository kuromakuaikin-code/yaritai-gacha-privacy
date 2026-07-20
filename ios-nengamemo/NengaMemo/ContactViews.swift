import SwiftUI
import SwiftData

// MARK: - 宛先一覧

struct ContactListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \Contact.name) private var contacts: [Contact]

    @State private var searchText = ""
    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: Contact?

    private var filtered: [Contact] {
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter { c in
            c.name.localizedCaseInsensitiveContains(searchText)
                || c.relationship.localizedCaseInsensitiveContains(searchText)
                || c.address.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if contacts.isEmpty {
                    ContentUnavailableView(
                        "宛先がありません",
                        systemImage: "person.crop.rectangle.stack",
                        description: Text("右上の＋から、年賀状やお中元・お歳暮を贈る相手を登録しましょう")
                    )
                } else {
                    List {
                        if !AppConfig.freeTrial, !store.isUnlimited, contacts.count > AppConfig.freeContactLimit {
                            Section {
                                Label("無料版は\(AppConfig.freeContactLimit)件まで表示中。プレミアムで全件表示できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(filtered) { contact in
                            NavigationLink {
                                ContactDetailView(contact: contact)
                            } label: {
                                ContactRow(contact: contact)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "名前・続柄・住所で検索")
            .navigationTitle("宛先一覧")
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
                AddEditContactView(contact: nil)
            }
            .sheet(item: $editing) { contact in
                AddEditContactView(contact: contact)
            }
            .alert("宛先数の上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版は\(AppConfig.freeContactLimit)件まで登録できます。設定タブからプレミアムで無制限に登録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, contacts.count >= AppConfig.freeContactLimit {
            showPaywall = true
        } else {
            showAdd = true
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filtered[index])
        }
    }
}

struct ContactRow: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .foregroundStyle(Color.nengaRed)
                .font(.title2)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.name.isEmpty ? "(名前未入力)" : contact.name)
                    .font(.subheadline.weight(.semibold))
                if !contact.relationship.isEmpty {
                    Text(contact.relationship)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 追加・編集

struct AddEditContactView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let contact: Contact?

    @State private var name = ""
    @State private var address = ""
    @State private var relationship = ""
    @State private var memo = ""

    private var isEditing: Bool { contact != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("お名前") {
                    TextField("お名前", text: $name)
                    TextField("続柄・関係（例：会社の上司、従兄弟）", text: $relationship)
                }

                Section("ご住所") {
                    TextEditor(text: $address)
                        .frame(minHeight: 100)
                }

                Section("メモ") {
                    TextField("いただいた品・お子様のお名前など", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isEditing {
                    Section {
                        Button("この宛先を削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "宛先を編集" : "宛先を追加")
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
        guard let contact else { return }
        name = contact.name
        address = contact.address
        relationship = contact.relationship
        memo = contact.memo
    }

    private func save() {
        let target = contact ?? Contact()
        target.name = name
        target.address = address
        target.relationship = relationship
        target.memo = memo
        if contact == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let contact {
            context.delete(contact)
        }
        dismiss()
    }
}

// MARK: - 宛先の詳細（贈答履歴）

struct ContactDetailView: View {
    @Bindable var contact: Contact
    @Environment(\.modelContext) private var context
    @State private var showEdit = false

    private var sortedLogs: [GiftLog] {
        contact.giftLogs.sorted { lhs, rhs in
            if lhs.year != rhs.year { return lhs.year > rhs.year }
            return lhs.occasion.label < rhs.occasion.label
        }
    }

    var body: some View {
        List {
            Section("基本情報") {
                LabeledContent("お名前", value: contact.name.isEmpty ? "(未入力)" : contact.name)
                if !contact.relationship.isEmpty {
                    LabeledContent("続柄・関係", value: contact.relationship)
                }
                if !contact.address.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ご住所").font(.caption).foregroundStyle(.secondary)
                        Text(contact.address)
                    }
                }
                if !contact.memo.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("メモ").font(.caption).foregroundStyle(.secondary)
                        Text(contact.memo)
                    }
                }
            }

            Section("贈答履歴") {
                if sortedLogs.isEmpty {
                    Text("まだ記録がありません。「今年の記録」タブからチェックすると、ここに履歴が表示されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedLogs) { log in
                        GiftLogRow(log: log)
                    }
                    .onDelete(perform: deleteLogs)
                }
            }
        }
        .navigationTitle(contact.name.isEmpty ? "宛先" : contact.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編集") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            AddEditContactView(contact: contact)
        }
    }

    private func deleteLogs(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sortedLogs[index])
        }
    }
}

struct GiftLogRow: View {
    let log: GiftLog

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: log.occasion.icon)
                .foregroundStyle(log.occasion.color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(log.year)年　\(log.occasion.label)")
                    .font(.subheadline.weight(.semibold))
                if !log.memo.isEmpty {
                    Text(log.memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                if log.sent {
                    Label("送った", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                }
                if log.received {
                    Label("もらった", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
