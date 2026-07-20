import SwiftUI
import SwiftData

// MARK: - 住まいのメンテナンス 一覧

struct MaintenanceListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query private var tasks: [MaintenanceTask]

    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: MaintenanceTask?

    private var sorted: [MaintenanceTask] {
        tasks.sorted { $0.nextDueDate < $1.nextDueDate }
    }

    /// 無料版の件数制限はユーザーが追加したカスタム項目のみが対象（標準項目は常に無料）
    private var customCount: Int { tasks.filter { !$0.isPreset }.count }

    var body: some View {
        NavigationStack {
            Group {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "メンテナンス項目がありません",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("右上の＋から、住まいのお手入れ項目を追加しましょう")
                    )
                } else {
                    List {
                        if !store.canAddMore(currentCount: customCount) {
                            Section {
                                Label("無料版で追加できる項目は\(AppConfig.freeItemLimitPerModule)件までです（標準項目は対象外）。プレミアムで無制限に追加できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(sorted) { task in
                            MaintenanceRow(task: task, onEdit: { editing = task })
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("メンテナンス")
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
                AddEditMaintenanceView(task: nil)
            }
            .sheet(item: $editing) { task in
                AddEditMaintenanceView(task: task)
            }
            .alert("追加件数の上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版で追加できるメンテナンス項目は\(AppConfig.freeItemLimitPerModule)件までです。設定タブからプレミアムで無制限に追加できます。")
            }
        }
    }

    private func addTapped() {
        if store.canAddMore(currentCount: customCount) {
            showAdd = true
        } else {
            showPaywall = true
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sorted[index])
        }
    }
}

struct MaintenanceRow: View {
    @Bindable var task: MaintenanceTask
    var onEdit: () -> Void

    private var days: Int { daysUntil(task.nextDueDate) }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    Image(systemName: task.isPreset ? "house.fill" : "wrench.fill")
                        .foregroundStyle(dueStatusColor(daysUntil: days))
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.name.isEmpty ? "(項目未入力)" : task.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("周期：\(task.intervalMonths)ヶ月　前回：\(mediumDate(task.lastDoneDate))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(dueStatusLabel(daysUntil: days))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(dueStatusColor(daysUntil: days))
                        Text(mediumDate(task.nextDueDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Button("完了") {
                task.lastDoneDate = Date()
            }
            .font(.caption.weight(.bold))
            .buttonStyle(.bordered)
            .tint(.kurashiSage)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 追加・編集

struct AddEditMaintenanceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let task: MaintenanceTask?

    @State private var name = ""
    @State private var lastDoneDate = Date()
    @State private var intervalMonths = 3
    @State private var memo = ""

    private var isEditing: Bool { task != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("項目") {
                    TextField("名前（例：換気扇フィルターの掃除）", text: $name)
                    DatePicker("前回実施日", selection: $lastDoneDate, displayedComponents: .date)
                    Stepper("周期：\(intervalMonths)ヶ月ごと", value: $intervalMonths, in: 1...36)
                    let nextDate = Calendar.current.date(byAdding: .month, value: intervalMonths, to: lastDoneDate) ?? lastDoneDate
                    Label("次回目安：\(mediumDate(nextDate))", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("メモ") {
                    TextField("業者の連絡先・手順など", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isEditing {
                    Section {
                        Button("この項目を削除", role: .destructive) {
                            deleteAndDismiss()
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
        guard let task else { return }
        name = task.name
        lastDoneDate = task.lastDoneDate
        intervalMonths = task.intervalMonths
        memo = task.memo
    }

    private func save() {
        let target = task ?? MaintenanceTask()
        target.name = name
        target.lastDoneDate = lastDoneDate
        target.intervalMonths = intervalMonths
        target.memo = memo
        if task == nil {
            target.isPreset = false
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let task {
            context.delete(task)
        }
        dismiss()
    }
}
