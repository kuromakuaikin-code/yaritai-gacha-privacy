import SwiftUI
import SwiftData

// MARK: - 日用品の在庫 一覧

struct SupplyListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query private var supplies: [Supply]

    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: Supply?

    private var sorted: [Supply] {
        supplies.sorted { lhs, rhs in
            if lhs.isLowStock != rhs.isLowStock { return lhs.isLowStock && !rhs.isLowStock }
            return lhs.name < rhs.name
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if supplies.isEmpty {
                    ContentUnavailableView(
                        "在庫がありません",
                        systemImage: "shippingbox",
                        description: Text("右上の＋から、トイレットペーパーや洗剤などの日用品を登録しましょう")
                    )
                } else {
                    List {
                        if !store.canAddMore(currentCount: supplies.count) {
                            Section {
                                Label("無料版は\(AppConfig.freeItemLimitPerModule)件まで登録できます。プレミアムで無制限に登録できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(sorted) { supply in
                            SupplyRow(supply: supply, onEdit: { editing = supply })
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("在庫管理")
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
                AddEditSupplyView(supply: nil)
            }
            .sheet(item: $editing) { supply in
                AddEditSupplyView(supply: supply)
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
        if store.canAddMore(currentCount: supplies.count) {
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

struct SupplyRow: View {
    @Bindable var supply: Supply
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    Image(systemName: "shippingbox.fill")
                        .foregroundStyle(supply.isLowStock ? .red : .kurashiSage)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(supply.name.isEmpty ? "(名前未入力)" : supply.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if supply.isLowStock {
                            Text("そろそろ買い足し")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.red.opacity(0.15))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 10) {
                Button {
                    if supply.currentStock > 0 { supply.currentStock -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .disabled(supply.currentStock <= 0)

                Text("\(supply.currentStock)")
                    .font(.subheadline.weight(.bold))
                    .frame(minWidth: 24)

                Button {
                    supply.currentStock += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
            .font(.title3)
            .buttonStyle(.plain)
            .tint(.kurashiSage)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 追加・編集

struct AddEditSupplyView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let supply: Supply?

    @State private var name = ""
    @State private var currentStockText = "1"
    @State private var lowStockThresholdText = "1"
    @State private var memo = ""

    private var isEditing: Bool { supply != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("品目") {
                    TextField("名前（例：トイレットペーパー）", text: $name)
                }

                Section("在庫") {
                    HStack {
                        Text("現在の在庫数")
                        Spacer()
                        TextField("0", text: $currentStockText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("買い足しの目安（この数以下で通知）")
                        Spacer()
                        TextField("0", text: $lowStockThresholdText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("メモ") {
                    TextField("よく買うお店・銘柄など", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isEditing {
                    Section {
                        Button("この品目を削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "品目を編集" : "品目を追加")
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
        guard let supply else { return }
        name = supply.name
        currentStockText = String(supply.currentStock)
        lowStockThresholdText = String(supply.lowStockThreshold)
        memo = supply.memo
    }

    private func save() {
        let target = supply ?? Supply()
        target.name = name
        target.currentStock = Int(currentStockText) ?? 0
        target.lowStockThreshold = Int(lowStockThresholdText) ?? 0
        target.memo = memo
        if supply == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let supply {
            context.delete(supply)
        }
        dismiss()
    }
}
