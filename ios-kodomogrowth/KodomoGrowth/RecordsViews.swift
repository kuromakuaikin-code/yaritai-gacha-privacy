import SwiftUI
import SwiftData

// MARK: - 記録一覧

struct RecordListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query(sort: \GrowthRecord.date, order: .reverse) private var allRecords: [GrowthRecord]

    @State private var selectedChild: Child?
    @State private var showAddChild = false
    @State private var showAddRecord = false
    @State private var editing: GrowthRecord?

    private var currentChild: Child? {
        if let selectedChild, children.contains(where: { $0.persistentModelID == selectedChild.persistentModelID }) {
            return selectedChild
        }
        return children.first
    }

    private var records: [GrowthRecord] {
        guard let currentChild else { return [] }
        return allRecords.filter { $0.child?.persistentModelID == currentChild.persistentModelID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if children.isEmpty {
                    emptyChildState
                } else {
                    VStack(spacing: 0) {
                        if children.count > 1 {
                            Picker("お子さま", selection: Binding(
                                get: { currentChild },
                                set: { selectedChild = $0 }
                            )) {
                                ForEach(children) { child in
                                    Text(child.name.isEmpty ? "(名前未設定)" : child.name).tag(Optional(child))
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding()
                        }

                        if records.isEmpty {
                            ContentUnavailableView(
                                "記録がありません",
                                systemImage: "list.bullet.rectangle",
                                description: Text("右上の＋から、身長・体重の記録を追加しましょう")
                            )
                        } else {
                            List {
                                ForEach(records) { record in
                                    Button {
                                        editing = record
                                    } label: {
                                        RecordRow(record: record, child: currentChild)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .onDelete(perform: delete)
                            }
                            .listStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("記録一覧")
            .toolbar {
                if !children.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddRecord = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddRecord) {
                AddEditRecordView(record: nil, defaultChild: currentChild)
            }
            .sheet(item: $editing) { record in
                AddEditRecordView(record: record, defaultChild: currentChild)
            }
            .sheet(isPresented: $showAddChild) {
                ChildEditView(child: nil)
            }
        }
    }

    private var emptyChildState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.2.and.child.holdinghands")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("お子さまが登録されていません")
                .font(.headline)
            Text("まずはお子さまのプロフィール（名前・誕生日）を登録しましょう")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showAddChild = true
            } label: {
                Label("お子さまを登録", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.kodomoTeal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(records[index])
        }
    }
}

struct RecordRow: View {
    let record: GrowthRecord
    let child: Child?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(mediumDate(record.date))
                    .font(.subheadline.weight(.semibold))
                if let child {
                    Text(ageLabel(birthday: child.birthday, at: record.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 14) {
                    Label(heightLabel(record.heightCm), systemImage: "ruler")
                    Label(weightLabel(record.weightKg), systemImage: "scalemass")
                }
                .font(.subheadline)
                .foregroundStyle(.kodomoTeal)

                if !record.memo.isEmpty {
                    Text(record.memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 追加・編集

struct AddEditRecordView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Child.createdAt) private var children: [Child]

    let record: GrowthRecord?
    let defaultChild: Child?

    @State private var selectedChild: Child?
    @State private var date = Date()
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var memo = ""

    private var isEditing: Bool { record != nil }

    var body: some View {
        NavigationStack {
            Form {
                if children.count > 1 {
                    Section("お子さま") {
                        Picker("お子さま", selection: $selectedChild) {
                            ForEach(children) { child in
                                Text(child.name.isEmpty ? "(名前未設定)" : child.name).tag(Optional(child))
                            }
                        }
                    }
                }

                Section("記録日") {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                    if let selectedChild {
                        Label("月齢：\(ageLabel(birthday: selectedChild.birthday, at: date))", systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("身長・体重") {
                    HStack {
                        Text("身長")
                        Spacer()
                        TextField("例：75.5", text: $heightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("cm").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("体重")
                        Spacer()
                        TextField("例：9.20", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("kg").foregroundStyle(.secondary)
                    }
                }

                Section("メモ") {
                    TextField("はじめて歩いた、離乳食開始 など", text: $memo, axis: .vertical)
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
                        .disabled(selectedChild == nil)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        selectedChild = record?.child ?? defaultChild ?? children.first
        guard let record else { return }
        date = record.date
        heightText = record.heightCm.map { formatInput($0) } ?? ""
        weightText = record.weightKg.map { formatInput($0) } ?? ""
        memo = record.memo
    }

    private func formatInput(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(value)
    }

    private func save() {
        let target = record ?? GrowthRecord()
        target.child = selectedChild
        target.date = date
        target.heightCm = Double(heightText.replacingOccurrences(of: "，", with: "."))
        target.weightKg = Double(weightText.replacingOccurrences(of: "，", with: "."))
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
