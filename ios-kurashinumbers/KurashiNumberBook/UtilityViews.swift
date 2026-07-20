import SwiftUI
import SwiftData
import Charts

// MARK: - 光熱費 一覧

struct UtilityListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \UtilityRecord.yearMonth, order: .reverse) private var records: [UtilityRecord]

    @State private var kindFilter: UtilityKind?
    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: UtilityRecord?

    private var filtered: [UtilityRecord] {
        guard let kindFilter else { return records }
        return records.filter { $0.kind == kindFilter }
    }

    private var chartRecords: [UtilityRecord] {
        guard let kindFilter else { return [] }
        return records.filter { $0.kind == kindFilter }.sorted { $0.yearMonth < $1.yearMonth }
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "記録がありません",
                        systemImage: "bolt.fill",
                        description: Text("右上の＋から、電気・ガス・水道の使用量や金額を記録しましょう")
                    )
                } else {
                    List {
                        if !AppConfig.freeTrial, !store.isUnlimited, records.count > AppConfig.freeItemLimitPerModule {
                            Section {
                                Label("無料版は\(AppConfig.freeItemLimitPerModule)件まで表示中。プレミアムで全件表示できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if kindFilter != nil, chartRecords.count >= 2 {
                            Section("推移") {
                                UtilityTrendChart(records: chartRecords)
                            }
                        }

                        Section {
                            ForEach(filtered) { record in
                                Button {
                                    editing = record
                                } label: {
                                    UtilityRow(record: record)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete(perform: delete)
                        }
                    }
                }
            }
            .navigationTitle("光熱費記録")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("すべて") { kindFilter = nil }
                        ForEach(UtilityKind.allCases) { k in
                            Button(k.label) { kindFilter = k }
                        }
                    } label: {
                        Label("絞り込み", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addTapped()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddEditUtilityView(record: nil)
            }
            .sheet(item: $editing) { record in
                AddEditUtilityView(record: record)
            }
            .alert("記録上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版は光熱費記録を\(AppConfig.freeItemLimitPerModule)件まで登録できます。設定タブからプレミアムで4つのモジュールすべて無制限に記録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, records.count >= AppConfig.freeItemLimitPerModule {
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

struct UtilityTrendChart: View {
    let records: [UtilityRecord]

    var body: some View {
        Chart(records) { record in
            LineMark(
                x: .value("年月", record.yearMonth, unit: .month),
                y: .value("金額", record.amountYen)
            )
            .foregroundStyle(record.kind.color)
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("年月", record.yearMonth, unit: .month),
                y: .value("金額", record.amountYen)
            )
            .foregroundStyle(record.kind.color)
        }
        .frame(height: 160)
        .padding(.vertical, 4)
    }
}

struct UtilityRow: View {
    let record: UtilityRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.kind.icon)
                .foregroundStyle(record.kind.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(record.kind.label)：\(yearMonthLabel(record.yearMonth))")
                    .font(.subheadline.weight(.semibold))
                if !record.usageNote.isEmpty {
                    Text(record.usageNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(yen(record.amountYen))
                .font(.subheadline.weight(.bold))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 追加・編集

struct AddEditUtilityView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let record: UtilityRecord?

    @State private var kind: UtilityKind = .electricity
    @State private var yearMonth = Date()
    @State private var amountText = ""
    @State private var usageNote = ""
    @State private var memo = ""

    private var isEditing: Bool { record != nil }
    private var amount: Int { Int(amountText) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("種類・年月") {
                    Picker("種類", selection: $kind) {
                        ForEach(UtilityKind.allCases) { k in
                            Label(k.label, systemImage: k.icon).tag(k)
                        }
                    }
                    DatePicker("年月", selection: $yearMonth, displayedComponents: .date)
                }

                Section("金額・使用量") {
                    HStack {
                        Text("金額")
                        Spacer()
                        TextField("0", text: $amountText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("円")
                    }
                    TextField("使用量（例：320kWh）", text: $usageNote)
                }

                Section("メモ") {
                    TextField("気づいたことなど", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
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
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let record else { return }
        kind = record.kind
        yearMonth = record.yearMonth
        amountText = record.amountYen > 0 ? String(record.amountYen) : ""
        usageNote = record.usageNote
        memo = record.memo
    }

    private func save() {
        let target = record ?? UtilityRecord()
        target.kind = kind
        target.yearMonth = startOfMonth(yearMonth)
        target.amountYen = amount
        target.usageNote = usageNote
        target.memo = memo
        if record == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let record {
            context.delete(record)
        }
        dismiss()
    }
}
