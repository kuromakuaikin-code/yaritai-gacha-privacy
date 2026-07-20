import SwiftUI
import SwiftData

// MARK: - お薬一覧（家族ごと）

struct MedicationListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \FamilyMember.createdAt) private var members: [FamilyMember]
    @Query private var allMedications: [Medication]

    @State private var showAddMember = false
    @State private var editingMember: FamilyMember?
    @State private var addMedicationMember: FamilyMember?
    @State private var showAddMedication = false
    @State private var editingMedication: Medication?
    @State private var showMemberPaywall = false
    @State private var showMedicationPaywall = false

    private func medications(for member: FamilyMember) -> [Medication] {
        allMedications
            .filter { $0.member?.persistentModelID == member.persistentModelID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if members.isEmpty {
                    ContentUnavailableView(
                        "ご家族が登録されていません",
                        systemImage: "person.2",
                        description: Text("右上の＋から、ご家族を追加しましょう")
                    )
                } else {
                    List {
                        if !AppConfig.freeTrial, !store.isUnlimited, allMedications.count > AppConfig.freeMedicationLimit {
                            Section {
                                Label("無料版はお薬\(AppConfig.freeMedicationLimit)件まで登録できます。プレミアムで無制限に登録できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(members) { member in
                            Section {
                                let meds = medications(for: member)
                                if meds.isEmpty {
                                    Text("お薬が登録されていません")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(meds) { med in
                                        Button {
                                            editingMedication = med
                                        } label: {
                                            MedicationRow(medication: med)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .onDelete { offsets in deleteMedications(meds, at: offsets) }
                                }
                                Button {
                                    addMedicationTapped(for: member)
                                } label: {
                                    Label("お薬を追加", systemImage: "plus.circle")
                                }
                            } header: {
                                Button {
                                    editingMember = member
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(member.name.isEmpty ? "名前未設定" : member.name)
                                        if !member.relation.isEmpty {
                                            Text("（\(member.relation)）")
                                        }
                                        Spacer()
                                        Image(systemName: "pencil")
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onDelete(perform: deleteMembers)
                    }
                }
            }
            .navigationTitle("お薬一覧")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addMemberTapped()
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddMember) {
                AddEditMemberView(member: nil)
            }
            .sheet(item: $editingMember) { member in
                AddEditMemberView(member: member)
            }
            .sheet(isPresented: $showAddMedication) {
                AddEditMedicationView(medication: nil, preselectedMember: addMedicationMember)
            }
            .sheet(item: $editingMedication) { med in
                AddEditMedicationView(medication: med, preselectedMember: nil)
            }
            .alert("登録できるご家族の人数上限に達しました", isPresented: $showMemberPaywall) {
                Button("OK") {}
            } message: {
                Text("無料版はご家族\(AppConfig.freeMemberLimit)人まで登録できます。設定タブからプレミアムで無制限に登録できます。")
            }
            .alert("登録できるお薬の件数上限に達しました", isPresented: $showMedicationPaywall) {
                Button("OK") {}
            } message: {
                Text("無料版はお薬\(AppConfig.freeMedicationLimit)件まで登録できます。設定タブからプレミアムで無制限に登録できます。")
            }
        }
    }

    private func addMemberTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, members.count >= AppConfig.freeMemberLimit {
            showMemberPaywall = true
        } else {
            showAddMember = true
        }
    }

    private func addMedicationTapped(for member: FamilyMember) {
        if !AppConfig.freeTrial, !store.isUnlimited, allMedications.count >= AppConfig.freeMedicationLimit {
            showMedicationPaywall = true
        } else {
            addMedicationMember = member
            showAddMedication = true
        }
    }

    private func deleteMembers(at offsets: IndexSet) {
        for index in offsets {
            context.delete(members[index])
        }
    }

    private func deleteMedications(_ meds: [Medication], at offsets: IndexSet) {
        for index in offsets {
            context.delete(meds[index])
        }
    }
}

struct MedicationRow: View {
    let medication: Medication

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "pills.fill")
                .foregroundStyle(Color.appTint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(medication.name.isEmpty ? "(名称未設定)" : medication.name)
                        .font(.subheadline.weight(.semibold))
                    if medication.isActive {
                        Text("服用中")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.appTint)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.appTint.opacity(0.15))
                            .clipShape(Capsule())
                    } else {
                        Text("終了")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text("\(medication.dosage) ・ \(medication.timingSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !medication.hospitalName.isEmpty {
                    Text(medication.hospitalName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(dateRangeLabel(start: medication.startDate, end: medication.endDate))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 家族の追加・編集

struct AddEditMemberView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let member: FamilyMember?

    @State private var name = ""
    @State private var relation = ""
    @State private var memo = ""

    private var isEditing: Bool { member != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("ご家族の情報") {
                    TextField("名前", text: $name)
                    TextField("続柄（例：本人・長男・母）", text: $relation)
                }
                Section("メモ") {
                    TextField("アレルギー・体質など", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }
                if isEditing {
                    Section {
                        Button("このご家族を削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "ご家族を編集" : "ご家族を追加")
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
        guard let member else { return }
        name = member.name
        relation = member.relation
        memo = member.memo
    }

    private func save() {
        let target = member ?? FamilyMember()
        target.name = name
        target.relation = relation
        target.memo = memo
        if member == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let member {
            context.delete(member)
        }
        dismiss()
    }
}

// MARK: - お薬の追加・編集

struct AddEditMedicationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FamilyMember.createdAt) private var members: [FamilyMember]

    let medication: Medication?
    let preselectedMember: FamilyMember?

    @State private var selectedMember: FamilyMember?
    @State private var name = ""
    @State private var dosage = ""
    @State private var timing: Set<TimingSlot> = []
    @State private var hospitalName = ""
    @State private var startDate = Date()
    @State private var ongoing = true
    @State private var endDate = Date()
    @State private var memo = ""

    private var isEditing: Bool { medication != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("対象のご家族") {
                    Picker("ご家族", selection: $selectedMember) {
                        Text("選択してください").tag(FamilyMember?.none)
                        ForEach(members) { m in
                            Text(m.name.isEmpty ? "名前未設定" : m.name).tag(FamilyMember?.some(m))
                        }
                    }
                }

                Section("お薬の情報") {
                    TextField("お薬の名前", text: $name)
                    TextField("用量（例：1錠、5ml）", text: $dosage)
                    TextField("処方病院・薬局", text: $hospitalName)
                }

                Section("服用タイミング") {
                    ForEach(TimingSlot.allCases) { slot in
                        Toggle(isOn: Binding(
                            get: { timing.contains(slot) },
                            set: { isOn in
                                if isOn { timing.insert(slot) } else { timing.remove(slot) }
                            }
                        )) {
                            Label(slot.label, systemImage: slot.icon)
                        }
                    }
                }

                Section("期間") {
                    DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                    Toggle("継続中（終了日を設定しない）", isOn: $ongoing)
                    if !ongoing {
                        DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                    }
                }

                Section("メモ") {
                    TextField("服用時の注意点など", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isEditing {
                    Section {
                        Button("このお薬を削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "お薬を編集" : "お薬を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.isEmpty || selectedMember == nil)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        if let medication {
            selectedMember = medication.member
            name = medication.name
            dosage = medication.dosage
            timing = Set(medication.timing)
            hospitalName = medication.hospitalName
            startDate = medication.startDate
            if let end = medication.endDate {
                ongoing = false
                endDate = end
            } else {
                ongoing = true
            }
            memo = medication.memo
        } else if let preselectedMember {
            selectedMember = preselectedMember
        } else if selectedMember == nil, let first = members.first {
            selectedMember = first
        }
    }

    private func save() {
        let target = medication ?? Medication()
        target.member = selectedMember
        target.name = name
        target.dosage = dosage
        target.timing = TimingSlot.allCases.filter { timing.contains($0) }
        target.hospitalName = hospitalName
        target.startDate = startDate
        target.endDate = ongoing ? nil : endDate
        target.memo = memo
        if medication == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let medication {
            context.delete(medication)
        }
        dismiss()
    }
}
