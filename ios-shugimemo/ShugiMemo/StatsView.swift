import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \GiftRecord.date, order: .reverse) private var records: [GiftRecord]
    @State private var yearFilter: Int?

    private var years: [Int] {
        let cal = Calendar.current
        let set = Set(records.map { cal.component(.year, from: $0.date) })
        return set.sorted(by: >)
    }

    private var scoped: [GiftRecord] {
        guard let yearFilter else { return records }
        let cal = Calendar.current
        return records.filter { cal.component(.year, from: $0.date) == yearFilter }
    }

    private var totalGiven: Int { scoped.filter { $0.direction == .given }.reduce(0) { $0 + $1.amount } }
    private var totalReceived: Int { scoped.filter { $0.direction == .received }.reduce(0) { $0 + $1.amount } }

    private var pendingReturns: [GiftRecord] {
        records.filter { $0.direction == .received && $0.returnStatus == .pending }
            .sorted { $0.date < $1.date }
    }

    private var byKind: [(EventKind, Int)] {
        EventKind.allCases.map { kind in
            (kind, scoped.filter { $0.eventKind == kind }.reduce(0) { $0 + $1.amount })
        }.filter { $0.1 > 0 }
        .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack {
            List {
                if !years.isEmpty {
                    Section {
                        Picker("年で絞り込み", selection: $yearFilter) {
                            Text("すべての年").tag(Int?.none)
                            ForEach(years, id: \.self) { y in
                                Text("\(y)年").tag(Int?.some(y))
                            }
                        }
                    }
                }

                Section("合計") {
                    SummaryRow(label: "渡した合計", value: totalGiven, color: .red)
                    SummaryRow(label: "いただいた合計", value: totalReceived, color: .green)
                    SummaryRow(label: "差額（いただいた − 渡した）", value: totalReceived - totalGiven, color: .indigo)
                }

                if !byKind.isEmpty {
                    Section("行事別の合計") {
                        ForEach(byKind, id: \.0) { kind, total in
                            HStack {
                                Label(kind.label, systemImage: kind.icon)
                                    .foregroundStyle(kind.color)
                                Spacer()
                                Text(yen(total))
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }

                if !pendingReturns.isEmpty {
                    Section {
                        ForEach(pendingReturns) { record in
                            PendingReturnRow(record: record)
                        }
                    } header: {
                        Text("お返し未対応 (\(pendingReturns.count)件)")
                    } footer: {
                        Text("いただいた記録のうち「未対応」になっているものです。行をタップすると対応済みにできます。")
                    }
                }

                if records.isEmpty {
                    ContentUnavailableView(
                        "まだ集計するデータがありません",
                        systemImage: "chart.pie",
                        description: Text("「記録」タブから記録を追加すると、ここに集計が表示されます")
                    )
                }
            }
            .navigationTitle("集計")
        }
    }
}

private struct SummaryRow: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(yen(value))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
        }
    }
}

private struct PendingReturnRow: View {
    @Bindable var record: GiftRecord

    var body: some View {
        Button {
            record.returnStatus = .done
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.personName.isEmpty ? record.eventTitle : record.personName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(record.eventKind.returnLabel)の目安：\(yen(record.suggestedReturnAmount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
