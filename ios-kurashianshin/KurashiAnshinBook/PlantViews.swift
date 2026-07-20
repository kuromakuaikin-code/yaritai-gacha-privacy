import SwiftUI
import SwiftData

// MARK: - 観葉植物の水やり 一覧

struct PlantListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query private var plants: [Plant]

    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: Plant?

    private var sorted: [Plant] {
        plants.sorted { $0.nextWaterDate < $1.nextWaterDate }
    }

    var body: some View {
        NavigationStack {
            Group {
                if plants.isEmpty {
                    ContentUnavailableView(
                        "植物が登録されていません",
                        systemImage: "leaf",
                        description: Text("右上の＋から、観葉植物を登録しましょう")
                    )
                } else {
                    List {
                        if !store.canAddMore(currentCount: plants.count) {
                            Section {
                                Label("無料版は\(AppConfig.freeItemLimitPerModule)件まで登録できます。プレミアムで無制限に登録できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(sorted) { plant in
                            PlantRow(plant: plant, onEdit: { editing = plant })
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("植物")
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
                AddEditPlantView(plant: nil)
            }
            .sheet(item: $editing) { plant in
                AddEditPlantView(plant: plant)
            }
            .alert("登録件数の上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版は\(AppConfig.freeItemLimitPerModule)件まで登録できます。設定タブからプレミアムで無制限に登録できます。")
            }
        }
    }

    private func addTapped() {
        if store.canAddMore(currentCount: plants.count) {
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

struct PlantRow: View {
    @Bindable var plant: Plant
    var onEdit: () -> Void

    private var days: Int { daysUntil(plant.nextWaterDate) }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(waterStatusColor(daysUntil: days))
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(plant.name.isEmpty ? "(名前未入力)" : plant.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if let species = plant.species, !species.isEmpty {
                            Text(species)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(waterStatusLabel(daysUntil: days))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(waterStatusColor(daysUntil: days))
                        Text(mediumDate(plant.nextWaterDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                plant.lastWateredDate = Date()
            } label: {
                Label("水やりした", systemImage: "drop.fill")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 追加・編集

struct AddEditPlantView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let plant: Plant?

    @State private var name = ""
    @State private var species = ""
    @State private var lastWateredDate = Date()
    @State private var intervalDays = 7
    @State private var memo = ""

    private var isEditing: Bool { plant != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("植物") {
                    TextField("名前（例：モンステラ）", text: $name)
                    TextField("品種（任意）", text: $species)
                }

                Section("水やり") {
                    DatePicker("前回の水やり日", selection: $lastWateredDate, displayedComponents: .date)
                    Stepper("周期：\(intervalDays)日ごと", value: $intervalDays, in: 1...60)
                    let nextDate = Calendar.current.date(byAdding: .day, value: intervalDays, to: lastWateredDate) ?? lastWateredDate
                    Label("次回目安：\(mediumDate(nextDate))", systemImage: "drop")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("メモ") {
                    TextField("置き場所・肥料・注意点など", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isEditing {
                    Section {
                        Button("この植物を削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "植物を編集" : "植物を追加")
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
        guard let plant else { return }
        name = plant.name
        species = plant.species ?? ""
        lastWateredDate = plant.lastWateredDate
        intervalDays = plant.intervalDays
        memo = plant.memo
    }

    private func save() {
        let target = plant ?? Plant()
        target.name = name
        target.species = species.isEmpty ? nil : species
        target.lastWateredDate = lastWateredDate
        target.intervalDays = intervalDays
        target.memo = memo
        if plant == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let plant {
            context.delete(plant)
        }
        dismiss()
    }
}
