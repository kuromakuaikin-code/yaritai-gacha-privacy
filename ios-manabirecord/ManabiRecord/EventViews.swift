import SwiftUI
import SwiftData

// MARK: - 学校行事一覧

struct SchoolEventListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \SchoolEvent.date, order: .forward) private var events: [SchoolEvent]

    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: SchoolEvent?

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView(
                        "学校行事が登録されていません",
                        systemImage: "checklist",
                        description: Text("右上の＋から、運動会・参観日・遠足などを登録しましょう")
                    )
                } else {
                    List {
                        if !AppConfig.freeTrial, !store.isUnlimited, events.count > AppConfig.freeItemLimitPerModule {
                            Section {
                                Label("無料版は\(AppConfig.freeItemLimitPerModule)件まで表示中。プレミアムで全件表示できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(events) { event in
                            NavigationLink {
                                ChecklistView(event: event)
                            } label: {
                                SchoolEventRow(event: event)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("行事チェック")
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
                AddEditSchoolEventView(event: nil)
            }
            .sheet(item: $editing) { event in
                AddEditSchoolEventView(event: event)
            }
            .alert("登録件数の上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版は行事を\(AppConfig.freeItemLimitPerModule)件まで登録できます。設定タブからプレミアムで無制限に登録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, events.count >= AppConfig.freeItemLimitPerModule {
            showPaywall = true
        } else {
            showAdd = true
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(events[index])
        }
    }
}

struct SchoolEventRow: View {
    let event: SchoolEvent

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title.isEmpty ? "(未入力)" : event.title)
                    .font(.subheadline.weight(.semibold))
                Text(mediumDateWeekday(event.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !event.entries.isEmpty {
                Text("\(event.checkedCount)/\(event.entries.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.studyBlue)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 行事の追加・編集

struct AddEditSchoolEventView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let event: SchoolEvent?

    @State private var title = ""
    @State private var date = Date()
    @State private var memo = ""

    private var isEditing: Bool { event != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("行事") {
                    TextField("行事名（例：運動会）", text: $title)
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                }
                Section("メモ") {
                    TextField("持ち物・集合時間など", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }
                if isEditing {
                    Section {
                        Button("この行事を削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "行事を編集" : "行事を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let event else { return }
        title = event.title
        date = event.date
        memo = event.memo
    }

    private func save() {
        let target = event ?? SchoolEvent()
        target.title = title
        target.date = date
        target.memo = memo
        if event == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let event {
            context.delete(event)
        }
        dismiss()
    }
}

// MARK: - 持ち物チェックリスト

struct ChecklistView: View {
    @Bindable var event: SchoolEvent
    @Environment(\.modelContext) private var context

    @State private var newItemText = ""

    private var sortedEntries: [ChecklistEntry] {
        event.entries.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        List {
            if !event.memo.isEmpty {
                Section("メモ") {
                    Text(event.memo)
                        .font(.subheadline)
                }
            }

            Section("持ち物・チェック項目") {
                if sortedEntries.isEmpty {
                    Text("チェック項目はまだありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedEntries) { entry in
                        ChecklistRow(entry: entry)
                    }
                    .onDelete(perform: delete)
                }

                HStack {
                    TextField("新しい項目（例：体操服）", text: $newItemText)
                    Button {
                        addItem()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle(event.title.isEmpty ? "チェックリスト" : event.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let entry = ChecklistEntry()
        entry.text = trimmed
        entry.isChecked = false
        entry.event = event
        context.insert(entry)
        event.entries.append(entry)
        newItemText = ""
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sortedEntries[index])
        }
    }
}

struct ChecklistRow: View {
    @Bindable var entry: ChecklistEntry

    var body: some View {
        Button {
            entry.isChecked.toggle()
        } label: {
            HStack {
                Image(systemName: entry.isChecked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(entry.isChecked ? Color.studyBlue : .secondary)
                Text(entry.text)
                    .strikethrough(entry.isChecked)
                    .foregroundStyle(entry.isChecked ? .secondary : .primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
