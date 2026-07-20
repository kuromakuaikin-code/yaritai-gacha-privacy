import SwiftUI
import SwiftData

// MARK: - ルール一覧

struct RulesListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \GarbageRule.createdAt) private var rules: [GarbageRule]

    @State private var showAdd = false
    @State private var editing: GarbageRule?
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Group {
                if rules.isEmpty {
                    ContentUnavailableView(
                        "ルールがありません",
                        systemImage: "list.bullet.clipboard",
                        description: Text("右上の＋から、ごみの収集ルールを追加しましょう")
                    )
                } else {
                    List {
                        if !AppConfig.freeTrial, !store.isUnlimited, rules.count > AppConfig.freeRuleLimit {
                            Section {
                                Label("無料版は\(AppConfig.freeRuleLimit)件まで表示中。プレミアムで無制限に登録できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(rules) { rule in
                            Button {
                                editing = rule
                            } label: {
                                RuleRow(rule: rule)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("ルール設定")
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
                AddEditRuleView(rule: nil)
            }
            .sheet(item: $editing) { rule in
                AddEditRuleView(rule: rule)
            }
            .alert("登録上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版は\(AppConfig.freeRuleLimit)件までルールを登録できます。設定タブからプレミアムで無制限に登録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, rules.count >= AppConfig.freeRuleLimit {
            showPaywall = true
        } else {
            showAdd = true
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(rules[index])
        }
    }
}

struct RuleRow: View {
    let rule: GarbageRule

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(rule.color)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(rule.categoryName.isEmpty ? "(名称未設定)" : rule.categoryName)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(rule.weekdaySummary.isEmpty ? "曜日未設定" : rule.weekdaySummary)
                    Text("・").foregroundStyle(.tertiary)
                    Text(rule.frequency.label)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !rule.note.isEmpty {
                    Text(rule.note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 追加・編集

struct AddEditRuleView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let rule: GarbageRule?

    @State private var categoryName = ""
    @State private var colorHex = GomiSchedule.presetColors.first?.hex ?? "E53935"
    @State private var weekdays: Set<Int> = []
    @State private var frequency: GarbageFrequency = .everyWeek
    @State private var note = ""

    private var isEditing: Bool { rule != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("カテゴリ") {
                    TextField("例：可燃ごみ", text: $categoryName)
                    colorPicker
                }

                Section("曜日") {
                    weekdayButtons
                    if weekdays.isEmpty {
                        Text("少なくとも1つの曜日を選んでください")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("頻度") {
                    Picker("頻度", selection: $frequency) {
                        ForEach(GarbageFrequency.allCases) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("メモ") {
                    TextField("例：収集は8:30まで", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if isEditing {
                    Section {
                        Button("このルールを削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "ルールを編集" : "ルールを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(categoryName.isEmpty || weekdays.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var colorPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
            ForEach(GomiSchedule.presetColors, id: \.hex) { preset in
                Button {
                    colorHex = preset.hex
                } label: {
                    Circle()
                        .fill(Color(hex: preset.hex))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle().strokeBorder(Color.primary, lineWidth: colorHex == preset.hex ? 2 : 0)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.name)
            }
        }
        .padding(.vertical, 6)
    }

    private var weekdayButtons: some View {
        HStack(spacing: 6) {
            ForEach(GomiSchedule.weekdayOrder, id: \.self) { day in
                Button {
                    toggle(day)
                } label: {
                    Text(GomiSchedule.weekdayLabel(day))
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(weekdays.contains(day) ? Color.gomiTint : Color(.secondarySystemBackground))
                        .foregroundStyle(weekdays.contains(day) ? Color.white : Color.primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(_ day: Int) {
        if weekdays.contains(day) {
            weekdays.remove(day)
        } else {
            weekdays.insert(day)
        }
    }

    private func load() {
        guard let rule else { return }
        categoryName = rule.categoryName
        colorHex = rule.colorHex
        weekdays = Set(rule.weekdays)
        frequency = rule.frequency
        note = rule.note
    }

    private func save() {
        let target = rule ?? GarbageRule()
        target.categoryName = categoryName
        target.colorHex = colorHex
        target.weekdays = Array(weekdays).sorted()
        target.frequency = frequency
        target.note = note
        if rule == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let rule {
            context.delete(rule)
        }
        dismiss()
    }
}
