import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \GoshuinEntry.visitDate, order: .reverse) private var entries: [GoshuinEntry]
    @State private var yearFilter: Int?

    private var years: [Int] {
        let cal = Calendar.current
        let set = Set(entries.map { cal.component(.year, from: $0.visitDate) })
        return set.sorted(by: >)
    }

    private var scoped: [GoshuinEntry] {
        guard let yearFilter else { return entries }
        let cal = Calendar.current
        return entries.filter { cal.component(.year, from: $0.visitDate) == yearFilter }
    }

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    private var thisYearEntries: [GoshuinEntry] {
        let cal = Calendar.current
        return entries.filter { cal.component(.year, from: $0.visitDate) == currentYear }
    }

    private var shrineCount: Int { scoped.filter { $0.placeType == .shrine }.count }
    private var templeCount: Int { scoped.filter { $0.placeType == .temple }.count }

    private var visitedPrefectureCount: Int {
        let visited = Set(entries.map { $0.prefecture.trimmingCharacters(in: .whitespaces) })
        return visited.intersection(PrefectureData.set).count
    }

    private var byWish: [(WishType, Int)] {
        WishType.allCases.map { wish in
            (wish, scoped.filter { $0.wishType == wish }.count)
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

                Section("参拝回数") {
                    SummaryRow(label: "参拝回数（選択期間）", value: "\(scoped.count)回")
                    SummaryRow(label: "神社", value: "\(shrineCount)回")
                    SummaryRow(label: "寺", value: "\(templeCount)回")
                    SummaryRow(label: "初穂料・拝観料合計（選択期間）", value: yen(scoped.reduce(0) { $0 + $1.fee }))
                }

                Section {
                    SummaryRow(label: "参拝回数", value: "\(thisYearEntries.count)回")
                    SummaryRow(label: "初穂料・拝観料合計", value: yen(thisYearEntries.reduce(0) { $0 + $1.fee }))
                } header: {
                    Text("今年（\(currentYear)年）の集計")
                }

                Section {
                    SummaryRow(label: "訪れた都道府県", value: "\(visitedPrefectureCount) / \(PrefectureData.count)")
                } header: {
                    Text("都道府県カバレッジ")
                } footer: {
                    Text("記録した都道府県のうち、47都道府県のいずれかに一致した件数です（すべての年が対象）。")
                }

                if !byWish.isEmpty {
                    Section("祈願内容別") {
                        ForEach(byWish, id: \.0) { wish, count in
                            HStack {
                                Label(wish.label, systemImage: wish.icon)
                                    .foregroundStyle(wish.color)
                                Spacer()
                                Text("\(count)回")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }

                if entries.isEmpty {
                    ContentUnavailableView(
                        "まだ集計するデータがありません",
                        systemImage: "chart.pie",
                        description: Text("「記録一覧」タブから参拝の記録を追加すると、ここに集計が表示されます")
                    )
                }
            }
            .navigationTitle("集計")
        }
    }
}

private struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.toriiRed)
        }
    }
}
