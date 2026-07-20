import SwiftUI
import SwiftData

// MARK: - 更新期限管理 一覧

struct RenewalListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \RenewalItem.dueDate, order: .forward) private var items: [RenewalItem]

    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: RenewalItem?
    @State private var completing: RenewalItem?
    @State private var showDone = false

    private var pending: [RenewalItem] { items.filter { !$0.isDone } }
    private var done: [RenewalItem] { items.filter { $0.isDone } }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "記録がありません",
                        systemImage: "calendar.badge.clock",
                        description: Text("右上の＋から、車検・保険・免許などの更新期限を記録しましょう")
                    )
                } else {
                    List {
                        if !AppConfig.freeTrial, !store.isUnlimited, items.count > AppConfig.freeItemLimitPerModule {
                            Section {
                                Label("無料版は\(AppConfig.freeItemLimitPerModule)件まで表示中。プレミアムで全件表示できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section("未対応") {
                            if pending.isEmpty {
                                Text("未対応の更新はありません")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(pending) { item in
                                RenewalRow(item: item, onComplete: { completing = item })
                                    .contentShape(Rectangle())
                                    .onTapGesture { editing = item }
                            }
                            .onDelete { offsets in delete(offsets, in: pending) }
                        }

                        if !done.isEmpty {
                            Section("更新完了", isExpanded: $showDone) {
                                ForEach(done) { item in
                                    RenewalRow(item: item, onComplete: nil)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editing = item }
                                }
                                .onDelete { offsets in delete(offsets, in: done) }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("更新期限管理")
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
                AddEditRenewalView(item: nil)
            }
            .sheet(item: $editing) { item in
                AddEditRenewalView(item: item)
            }
            .sheet(item: $completing) { item in
                CompleteRenewalView(item: item)
            }
            .alert("記録上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版は更新期限の記録を\(AppConfig.freeItemLimitPerModule)件まで登録できます。設定タブからプレミアムで4つのモジュールすべて無制限に記録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, items.count >= AppConfig.freeItemLimitPerModule {
            showPaywall = true
        } else {
            showAdd = true
        }
    }

    private func delete(_ offsets: IndexSet, in list: [RenewalItem]) {
        for index in offsets {
            context.delete(list[index])
        }
    }
}

struct RenewalRow: View {
    let item: RenewalItem
    var onComplete: (() -> Void)?

    private var days: Int { item.daysUntilDue }
    private var color: Color { item.isDone ? .secondary : deadlineColor(days) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.icon)
                .foregroundStyle(item.isDone ? .secondary : item.category.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name.isEmpty ? "(名称未入力)" : item.name)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(item.isDone)
                HStack(spacing: 6) {
                    Text(item.category.label)
                    Text("・").foregroundStyle(.tertiary)
                    Text(mediumDate(item.dueDate))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if item.isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .trailing, spacing: 6) {
                    Text(daysLabel(days))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(color.opacity(0.15))
                        .foregroundStyle(color)
                        .clipShape(Capsule())
                    if let onComplete {
                        Button("更新完了", action: onComplete)
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .tint(Color.kurashiGold)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 更新完了

struct CompleteRenewalView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: RenewalItem
    @State private var rollForward = false
    @State private var nextDueDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section(item.name) {
                    Toggle("次回の期限を設定して繰り越す", isOn: $rollForward)
                    if rollForward {
                        DatePicker("次回の期限日", selection: $nextDueDate, displayedComponents: .date)
                    }
                } footer: {
                    Text("繰り越さない場合は「更新完了」として一覧の下部に残ります。")
                }
            }
            .navigationTitle("更新完了")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了にする") { complete() }
                }
            }
            .onAppear {
                nextDueDate = Calendar.current.date(byAdding: .year, value: 1, to: item.dueDate) ?? Date()
            }
        }
    }

    private func complete() {
        if rollForward {
            item.dueDate = nextDueDate
            item.isDone = false
        } else {
            item.isDone = true
        }
        dismiss()
    }
}

// MARK: - 追加・編集

struct AddEditRenewalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let item: RenewalItem?

    @State private var name = ""
    @State private var category: RenewalCategory = .other
    @State private var dueDate = Date()
    @State private var reminderNote = ""
    @State private var isDone = false

    private var isEditing: Bool { item != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("項目") {
                    TextField("名称（例：自動車保険・車検・パスポート）", text: $name)
                    Picker("カテゴリ", selection: $category) {
                        ForEach(RenewalCategory.allCases) { c in
                            Label(c.label, systemImage: c.icon).tag(c)
                        }
                    }
                    DatePicker("更新期限", selection: $dueDate, displayedComponents: .date)
                }

                Section("メモ") {
                    TextField("必要書類・連絡先・手続き方法など", text: $reminderNote, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("更新完了にする", isOn: $isDone)
                }

                if isEditing {
                    Section {
                        Button("この記録を削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "記録を編集" : "記録を追加")
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
        guard let item else { return }
        name = item.name
        category = item.category
        dueDate = item.dueDate
        reminderNote = item.reminderNote
        isDone = item.isDone
    }

    private func save() {
        let target = item ?? RenewalItem()
        target.name = name
        target.category = category
        target.dueDate = dueDate
        target.reminderNote = reminderNote
        target.isDone = isDone
        if item == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let item {
            context.delete(item)
        }
        dismiss()
    }
}
