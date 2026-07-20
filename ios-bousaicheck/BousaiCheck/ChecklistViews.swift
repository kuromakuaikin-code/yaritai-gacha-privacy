import SwiftUI
import SwiftData

// MARK: - チェックリスト一覧（カテゴリー別）

struct ChecklistView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: [SortDescriptor(\ChecklistItem.order), SortDescriptor(\ChecklistItem.name)])
    private var items: [ChecklistItem]

    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: ChecklistItem?

    /// 無料版で件数制限の対象になるのはカスタム項目（isPreset == false）のみ。標準項目は制限に含まれない
    private var customCount: Int { items.filter { !$0.isPreset }.count }
    private var checkedCount: Int { items.filter { $0.isChecked }.count }
    private var totalCount: Int { items.count }
    private var progress: Double { totalCount == 0 ? 0 : Double(checkedCount) / Double(totalCount) }

    private var grouped: [(ItemCategory, [ChecklistItem])] {
        ItemCategory.allCases.compactMap { category in
            let list = items.filter { $0.category == category }
            return list.isEmpty ? nil : (category, list)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "読み込み中…",
                        systemImage: "checklist",
                        description: Text("標準チェックリストを準備しています")
                    )
                } else {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("準備できているもの")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(checkedCount) / \(totalCount)")
                                        .font(.subheadline.weight(.bold))
                                }
                                ProgressView(value: progress)
                                    .tint(Color.bousaiAmber)
                            }
                            .padding(.vertical, 4)
                        }

                        ForEach(grouped, id: \.0) { category, categoryItems in
                            Section {
                                ForEach(categoryItems) { item in
                                    ChecklistItemRow(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editing = item }
                                        // 標準項目（isPreset）は削除不可。カスタム項目のみスワイプ削除できる
                                        .swipeActions(edge: .trailing, allowsFullSwipe: !item.isPreset) {
                                            if !item.isPreset {
                                                Button(role: .destructive) {
                                                    context.delete(item)
                                                } label: {
                                                    Label("削除", systemImage: "trash")
                                                }
                                            }
                                        }
                                }
                            } header: {
                                Label(category.label, systemImage: category.icon)
                                    .foregroundStyle(category.color)
                            }
                        }
                    }
                }
            }
            .navigationTitle("チェックリスト")
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
                AddEditChecklistItemView(item: nil)
            }
            .sheet(item: $editing) { item in
                AddEditChecklistItemView(item: item)
            }
            .alert("追加できる項目数の上限です", isPresented: $showPaywall) {
                Button("OK") {}
            } message: {
                Text("無料版で追加できるカスタム項目は\(AppConfig.freeCustomItemLimit)件までです（標準項目は件数に含まれません）。設定タブからプレミアムで無制限に追加できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, customCount >= AppConfig.freeCustomItemLimit {
            showPaywall = true
        } else {
            showAdd = true
        }
    }
}

struct ChecklistItemRow: View {
    let item: ChecklistItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                item.isChecked.toggle()
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? Color.bousaiAmber : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(item.isChecked)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                    if item.isPreset {
                        Text("標準")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                if let expiryDate = item.expiryDate {
                    Label(expiryLabel(expiryDate), systemImage: "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(expiryColor(expiryDate))
                }

                if !item.memo.isEmpty {
                    Text(item.memo)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func daysUntil(_ date: Date) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    private func expiryLabel(_ date: Date) -> String {
        let days = daysUntil(date)
        if days < 0 { return "期限切れ（\(mediumDate(date))）" }
        if days <= 30 { return "期限が近づいています（\(mediumDate(date))まで）" }
        return "期限：\(mediumDate(date))"
    }

    private func expiryColor(_ date: Date) -> Color {
        let days = daysUntil(date)
        if days < 0 { return .red }
        if days <= 30 { return .orange }
        return .secondary
    }
}

// MARK: - 追加・編集

struct AddEditChecklistItemView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let item: ChecklistItem?

    @State private var name = ""
    @State private var category: ItemCategory = .other
    @State private var hasExpiry = false
    @State private var expiryDate = Date()
    @State private var memo = ""

    private var isEditing: Bool { item != nil }
    private var isPresetItem: Bool { item?.isPreset ?? false }

    var body: some View {
        NavigationStack {
            Form {
                Section("項目") {
                    TextField("品目名（例：非常食、モバイルバッテリーなど）", text: $name)
                    Picker("カテゴリー", selection: $category) {
                        ForEach(ItemCategory.allCases) { c in
                            Label(c.label, systemImage: c.icon).tag(c)
                        }
                    }
                }

                Section("消費期限・使用期限") {
                    Toggle("期限を設定する", isOn: $hasExpiry.animation())
                    if hasExpiry {
                        DatePicker("期限", selection: $expiryDate, displayedComponents: .date)
                    }
                } footer: {
                    Text("非常食・飲料水などのローリングストック（消費しながら備蓄する管理法）の目安にご利用ください。")
                }

                Section("メモ") {
                    TextField("保管場所・数量など", text: $memo, axis: .vertical)
                        .lineLimit(2...5)
                }

                if isEditing {
                    if isPresetItem {
                        Section {
                            Text("標準項目は削除できません。不要な場合はチェックを外したままにしてください。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section {
                            Button("この項目を削除", role: .destructive) {
                                deleteAndDismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "項目を編集" : "項目を追加")
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
        if let expiryDate = item.expiryDate {
            hasExpiry = true
            self.expiryDate = expiryDate
        }
        memo = item.memo
    }

    private func save() {
        let target = item ?? ChecklistItem()
        target.name = name
        target.category = category
        target.expiryDate = hasExpiry ? expiryDate : nil
        target.memo = memo
        if item == nil {
            target.isPreset = false
            target.isChecked = false
            target.order = 1000
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
