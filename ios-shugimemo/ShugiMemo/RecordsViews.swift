import SwiftUI
import SwiftData

// MARK: - 記録一覧

struct RecordListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \GiftRecord.date, order: .reverse) private var records: [GiftRecord]

    @State private var searchText = ""
    @State private var directionFilter: Direction?
    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: GiftRecord?

    private var filtered: [GiftRecord] {
        records.filter { r in
            if let directionFilter, r.direction != directionFilter { return false }
            guard !searchText.isEmpty else { return true }
            return r.eventTitle.localizedCaseInsensitiveContains(searchText)
                || r.personName.localizedCaseInsensitiveContains(searchText)
                || r.memo.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "記録がありません",
                        systemImage: "list.bullet.rectangle",
                        description: Text("右上の＋から、ご祝儀・香典・お祝いの記録を追加しましょう")
                    )
                } else {
                    List {
                        if !AppConfig.freeTrial, !store.isUnlimited, records.count > AppConfig.freeRecordLimit {
                            Section {
                                Label("無料版は\(AppConfig.freeRecordLimit)件まで表示中。プレミアムで全件表示できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
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
            .searchable(text: $searchText, prompt: "名前・行事・メモで検索")
            .navigationTitle("ご祝儀・香典メモ")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("すべて") { directionFilter = nil }
                        ForEach(Direction.allCases) { d in
                            Button(d.label) { directionFilter = d }
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
                AddEditRecordView(record: nil)
            }
            .sheet(item: $editing) { record in
                AddEditRecordView(record: record)
            }
            .alert("記録上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版は\(AppConfig.freeRecordLimit)件まで記録できます。設定タブからプレミアムで無制限に記録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, records.count >= AppConfig.freeRecordLimit {
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

struct RecordRow: View {
    let record: GiftRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.eventKind.icon)
                .foregroundStyle(record.eventKind.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.eventTitle.isEmpty ? record.eventKind.label : record.eventTitle)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(record.personName.isEmpty ? "(名前未入力)" : record.personName)
                    Text("・").foregroundStyle(.tertiary)
                    Text(record.relation.label)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if record.direction == .received && record.returnStatus != .notNeeded {
                    Text(record.returnStatus.label)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(record.returnStatus.color.opacity(0.15))
                        .foregroundStyle(record.returnStatus.color)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text((record.direction == .given ? "-" : "+") + yen(record.amount))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(record.direction == .given ? .red : .green)
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

    let record: GiftRecord?

    @State private var eventTitle = ""
    @State private var personName = ""
    @State private var eventKind: EventKind = .wedding
    @State private var relation: Relation = .friend
    @State private var direction: Direction = .given
    @State private var amountText = ""
    @State private var date = Date()
    @State private var returnStatus: ReturnStatus = .notNeeded
    @State private var memo = ""

    private var isEditing: Bool { record != nil }

    private var amount: Int { Int(amountText) ?? 0 }

    private var matchingRates: [MarketRate] {
        MarketRateData.rates(for: eventKind).filter { $0.relation == relation }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("行事") {
                    Picker("種類", selection: $eventKind) {
                        ForEach(EventKind.allCases) { k in
                            Label(k.label, systemImage: k.icon).tag(k)
                        }
                    }
                    TextField("行事名（例：〇〇さん結婚式）", text: $eventTitle)
                }

                Section("相手・関係") {
                    TextField("お名前", text: $personName)
                    Picker("関係性", selection: $relation) {
                        ForEach(Relation.allCases) { r in
                            Text(r.label).tag(r)
                        }
                    }
                }

                Section("金額・方向") {
                    Picker("方向", selection: $direction) {
                        ForEach(Direction.allCases) { d in
                            Text(d.label).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("金額")
                        Spacer()
                        TextField("0", text: $amountText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("円")
                    }

                    DatePicker("日付", selection: $date, displayedComponents: .date)

                    if let rate = matchingRates.first {
                        Label("相場の目安：\(rate.rangeLabel)", systemImage: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if direction == .received {
                    Section(eventKind.returnLabel) {
                        Picker("状況", selection: $returnStatus) {
                            ForEach(ReturnStatus.allCases) { s in
                                Text(s.label).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)

                        if amount > 0 {
                            Label("お返しの目安：半返しで\(yen(suggestedReturn(for: amount)))前後", systemImage: "arrow.uturn.left")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("メモ") {
                    TextField("会場・のし袋の表書き・当日の様子など", text: $memo, axis: .vertical)
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
                        .disabled(personName.isEmpty && eventTitle.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let record else { return }
        eventTitle = record.eventTitle
        personName = record.personName
        eventKind = record.eventKind
        relation = record.relation
        direction = record.direction
        amountText = record.amount > 0 ? String(record.amount) : ""
        date = record.date
        returnStatus = record.returnStatus
        memo = record.memo
    }

    private func save() {
        let target = record ?? GiftRecord()
        target.eventTitle = eventTitle
        target.personName = personName
        target.eventKind = eventKind
        target.relation = relation
        target.direction = direction
        target.amount = amount
        target.date = date
        target.returnStatus = direction == .received ? returnStatus : .notNeeded
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
