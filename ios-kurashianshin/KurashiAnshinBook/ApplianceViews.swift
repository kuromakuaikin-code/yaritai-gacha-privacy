import SwiftUI
import SwiftData

// MARK: - 家電の保証期限 一覧

struct ApplianceListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query private var appliances: [Appliance]

    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: Appliance?

    private var sorted: [Appliance] {
        appliances.sorted { $0.warrantyEndDate < $1.warrantyEndDate }
    }

    var body: some View {
        NavigationStack {
            Group {
                if appliances.isEmpty {
                    ContentUnavailableView(
                        "家電がありません",
                        systemImage: "washer",
                        description: Text("右上の＋から、家電の購入日と保証年数を登録しましょう")
                    )
                } else {
                    List {
                        if !store.canAddMore(currentCount: appliances.count) {
                            Section {
                                Label("無料版は\(AppConfig.freeItemLimitPerModule)件まで登録できます。プレミアムで無制限に登録できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(sorted) { appliance in
                            Button {
                                editing = appliance
                            } label: {
                                ApplianceRow(appliance: appliance)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("家電保証")
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
                AddEditApplianceView(appliance: nil)
            }
            .sheet(item: $editing) { appliance in
                AddEditApplianceView(appliance: appliance)
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
        if store.canAddMore(currentCount: appliances.count) {
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

struct ApplianceRow: View {
    let appliance: Appliance

    private var days: Int { daysUntil(appliance.warrantyEndDate) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "washer.fill")
                .foregroundStyle(dueStatusColor(daysUntil: days))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(appliance.name.isEmpty ? "(名称未入力)" : appliance.name)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(appliance.purchasePlace.isEmpty ? "購入店未入力" : appliance.purchasePlace)
                    Text("・").foregroundStyle(.tertiary)
                    Text("保証\(appliance.warrantyYears)年")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(dueStatusLabel(daysUntil: days))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(dueStatusColor(daysUntil: days))
                Text(mediumDate(appliance.warrantyEndDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 追加・編集

struct AddEditApplianceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let appliance: Appliance?

    @State private var name = ""
    @State private var purchaseDate = Date()
    @State private var purchasePlace = ""
    @State private var warrantyYears = 1
    @State private var priceText = ""
    @State private var memo = ""

    private var isEditing: Bool { appliance != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("家電") {
                    TextField("名前（例：冷蔵庫、洗濯機）", text: $name)
                    DatePicker("購入日", selection: $purchaseDate, displayedComponents: .date)
                    TextField("購入店", text: $purchasePlace)
                }

                Section("保証") {
                    Stepper("保証年数：\(warrantyYears)年", value: $warrantyYears, in: 1...15)
                    HStack {
                        Text("購入金額")
                        Spacer()
                        TextField("任意", text: $priceText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("円")
                    }
                    let endDate = Calendar.current.date(byAdding: .year, value: warrantyYears, to: purchaseDate) ?? purchaseDate
                    Label("保証期限：\(mediumDate(endDate))", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("メモ") {
                    TextField("型番・保証書の保管場所など", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isEditing {
                    Section {
                        Button("この家電を削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "家電を編集" : "家電を追加")
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
        guard let appliance else { return }
        name = appliance.name
        purchaseDate = appliance.purchaseDate
        purchasePlace = appliance.purchasePlace
        warrantyYears = appliance.warrantyYears
        priceText = appliance.price.map { String($0) } ?? ""
        memo = appliance.memo
    }

    private func save() {
        let target = appliance ?? Appliance()
        target.name = name
        target.purchaseDate = purchaseDate
        target.purchasePlace = purchasePlace
        target.warrantyYears = warrantyYears
        target.price = Int(priceText)
        target.memo = memo
        if appliance == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let appliance {
            context.delete(appliance)
        }
        dismiss()
    }
}
