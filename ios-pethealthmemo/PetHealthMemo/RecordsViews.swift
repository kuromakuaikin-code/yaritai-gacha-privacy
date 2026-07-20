import SwiftUI
import SwiftData
import Charts

// MARK: - 記録一覧

struct RecordListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \HealthRecord.date, order: .reverse) private var allRecords: [HealthRecord]

    @State private var selectedPet: Pet?
    @State private var kindFilter: HealthRecordKind?
    @State private var showAdd = false
    @State private var editing: HealthRecord?
    @State private var showPaywall = false

    private var petRecords: [HealthRecord] {
        guard let selectedPet else { return [] }
        return allRecords.filter { $0.pet === selectedPet }
    }

    private var filtered: [HealthRecord] {
        petRecords.filter { r in
            kindFilter == nil || r.kind == kindFilter
        }
    }

    private var weightPoints: [HealthRecord] {
        petRecords.filter { $0.weightKg != nil }.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if pets.isEmpty {
                    ContentUnavailableView(
                        "ペットが登録されていません",
                        systemImage: "pawprint",
                        description: Text("「設定」タブの「ペットを追加/編集」から、まずペットを登録しましょう")
                    )
                } else {
                    List {
                        if pets.count > 1 {
                            Section {
                                Picker("ペット", selection: $selectedPet) {
                                    ForEach(pets) { pet in
                                        Text(pet.name.isEmpty ? "(名前未設定)" : pet.name).tag(Optional(pet))
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .listRowInsets(EdgeInsets())
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        }

                        if weightPoints.count >= 2 {
                            Section("体重の推移") {
                                WeightChartView(points: weightPoints)
                            }
                        }

                        if !AppConfig.freeTrial, !store.isUnlimited, allRecords.count > AppConfig.freeRecordLimit {
                            Section {
                                Label("無料版は記録\(AppConfig.freeRecordLimit)件まで表示中。プレミアムで全件表示できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if petRecords.isEmpty {
                            Section {
                                Text("まだ記録がありません。右上の＋から記録を追加しましょう")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Section {
                                ForEach(filtered) { record in
                                    Button {
                                        editing = record
                                    } label: {
                                        RecordRow(record: record)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .onDelete(perform: delete)
                            }
                        }
                    }
                }
            }
            .navigationTitle("記録一覧")
            .toolbar {
                if !petRecords.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button("すべて") { kindFilter = nil }
                            ForEach(HealthRecordKind.allCases) { k in
                                Button(k.label) { kindFilter = k }
                            }
                        } label: {
                            Label("絞り込み", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
                if !pets.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            addTapped()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }
            .onAppear {
                if selectedPet == nil { selectedPet = pets.first }
            }
            .onChange(of: pets) { _, newPets in
                if selectedPet == nil || !newPets.contains(where: { $0 === selectedPet }) {
                    selectedPet = newPets.first
                }
            }
            .sheet(isPresented: $showAdd) {
                AddEditRecordView(record: nil, preselectedPet: selectedPet)
            }
            .sheet(item: $editing) { record in
                AddEditRecordView(record: record, preselectedPet: record.pet)
            }
            .alert("記録上限に達しました", isPresented: $showPaywall) {
                Button("OK") {}
            } message: {
                Text("無料版は\(AppConfig.freeRecordLimit)件まで記録できます。設定タブからプレミアムで無制限に記録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, allRecords.count >= AppConfig.freeRecordLimit {
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

// MARK: - 体重グラフ

struct WeightChartView: View {
    let points: [HealthRecord]

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("日付", point.date),
                y: .value("体重", point.weightKg ?? 0)
            )
            .foregroundStyle(AppConfig.tintColor)
            .symbol(Circle())
            .interpolationMethod(.catmullRom)
        }
        .frame(height: 140)
        .padding(.vertical, 4)
    }
}

// MARK: - 記録の行

struct RecordRow: View {
    let record: HealthRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.kind.icon)
                .foregroundStyle(record.kind.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.detail.isEmpty ? record.kind.label : record.detail)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(record.kind.label)
                    if !record.hospitalName.isEmpty {
                        Text("・").foregroundStyle(.tertiary)
                        Text(record.hospitalName)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let due = record.nextDueDate {
                    Label("次回予定：\(mediumDate(due))", systemImage: "calendar")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isOverdue(due) ? .red : AppConfig.tintColor)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if let weight = record.weightKg {
                    Text(weightLabel(weight))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.green)
                }
                Text(mediumDate(record.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 追加・編集

struct AddEditRecordView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pet.createdAt) private var pets: [Pet]

    let record: HealthRecord?
    let preselectedPet: Pet?

    @State private var pet: Pet?
    @State private var kind: HealthRecordKind = .checkup
    @State private var date = Date()
    @State private var detail = ""
    @State private var weightText = ""
    @State private var hospitalName = ""
    @State private var hasNextDueDate = false
    @State private var nextDueDate = Date()
    @State private var memo = ""

    private var isEditing: Bool { record != nil }

    private var weightKg: Double? {
        guard !weightText.isEmpty else { return nil }
        return Double(weightText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ペット") {
                    Picker("ペット", selection: $pet) {
                        ForEach(pets) { p in
                            Text(p.name.isEmpty ? "(名前未設定)" : p.name).tag(Optional(p))
                        }
                    }
                }

                Section("記録の種類") {
                    Picker("種類", selection: $kind) {
                        ForEach(HealthRecordKind.allCases) { k in
                            Label(k.label, systemImage: k.icon).tag(k)
                        }
                    }
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                    TextField("内容（例：混合ワクチン5種）", text: $detail)
                }

                Section("体重") {
                    HStack {
                        Text("体重")
                        Spacer()
                        TextField("0.0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("kg")
                    }
                } footer: {
                    Text("体重測定以外の記録でも、通院時などにあわせて記録できます")
                }

                Section("病院・施設") {
                    TextField("病院名・施設名", text: $hospitalName)
                }

                Section("次回予定日") {
                    Toggle("設定しない", isOn: Binding(
                        get: { !hasNextDueDate },
                        set: { hasNextDueDate = !$0 }
                    ))
                    if hasNextDueDate {
                        DatePicker("次回予定日", selection: $nextDueDate, displayedComponents: .date)
                    }
                }

                Section("メモ") {
                    TextField("様子・症状・処方内容など", text: $memo, axis: .vertical)
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
                        .disabled(pet == nil)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        pet = record?.pet ?? preselectedPet ?? pets.first
        guard let record else { return }
        kind = record.kind
        date = record.date
        detail = record.detail
        weightText = record.weightKg.map { $0 == $0.rounded() ? String(format: "%.0f", $0) : String($0) } ?? ""
        hospitalName = record.hospitalName
        if let due = record.nextDueDate {
            hasNextDueDate = true
            nextDueDate = due
        }
        memo = record.memo
    }

    private func save() {
        guard let pet else { return }
        let target = record ?? HealthRecord()
        target.pet = pet
        target.kind = kind
        target.date = date
        target.detail = detail
        target.weightKg = weightKg
        target.hospitalName = hospitalName
        target.nextDueDate = hasNextDueDate ? nextDueDate : nil
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
