import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var subscriptions: [Subscription]

    private var active: [Subscription] { subscriptions.filter { $0.isActive } }

    private var totalMonthly: Double {
        active.reduce(0) { $0 + $1.monthlyEquivalent }
    }

    private var totalYearlyProjected: Double { totalMonthly * 12 }

    private var byCategory: [(SubscriptionCategory, Double)] {
        SubscriptionCategory.allCases.map { category in
            let total = active.filter { $0.category == category }
                .reduce(0.0) { $0 + $1.monthlyEquivalent }
            return (category, total)
        }
        .filter { $0.1 > 0 }
        .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("合計") {
                    SummaryRow(label: "契約中のサブスク数", valueText: "\(active.count)件")
                    SummaryRow(label: "月あたりの合計", valueText: yen(totalMonthly))
                    SummaryRow(label: "年間換算の合計", valueText: yen(totalYearlyProjected))
                }

                if !byCategory.isEmpty {
                    Section {
                        ForEach(byCategory, id: \.0) { category, total in
                            HStack {
                                Label(category.label, systemImage: category.icon)
                                    .foregroundStyle(category.color)
                                Spacer()
                                Text(yen(total) + " /月")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    } header: {
                        Text("カテゴリー別（月換算・多い順）")
                    }
                }

                if subscriptions.isEmpty {
                    ContentUnavailableView(
                        "まだ集計するデータがありません",
                        systemImage: "chart.pie",
                        description: Text("「一覧」タブからサブスクを追加すると、ここに集計が表示されます")
                    )
                } else if active.isEmpty {
                    ContentUnavailableView(
                        "契約中のサブスクがありません",
                        systemImage: "chart.pie",
                        description: Text("すべて解約・休止中になっています")
                    )
                }
            }
            .navigationTitle("統計")
        }
    }
}

private struct SummaryRow: View {
    let label: String
    let valueText: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(valueText)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.brand)
        }
    }
}
