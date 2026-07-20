import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var allItems: [FoodItem]

    private var activeItems: [FoodItem] { allItems.filter { !$0.isConsumed } }
    private var consumedItems: [FoodItem] { allItems.filter { $0.isConsumed } }

    /// 期限切れ（当日を含まない、期限日を過ぎている）の未消費食品
    private var expiredItems: [FoodItem] { activeItems.filter { $0.daysUntilExpiry < 0 } }

    /// 3日以内に期限を迎える（まだ期限切れではない）未消費食品＝今週消費すべき
    private var expiringSoonItems: [FoodItem] {
        activeItems.filter { $0.daysUntilExpiry >= 0 && $0.daysUntilExpiry <= 3 }
    }

    private var byCategory: [(FoodCategory, Int)] {
        FoodCategory.allCases.map { c in (c, activeItems.filter { $0.category == c }.count) }
    }

    /// 食品ロス削減の目安：消費済みにした件数と、期限切れのまま残っている件数の簡易集計
    /// （このモデルには「消費した日」を持たせていないため、正確な期間集計ではなく
    ///  現時点のスナップショットとして扱う）
    private var wasteRatioText: String {
        let total = consumedItems.count + expiredItems.count
        guard total > 0 else { return "データがまだありません" }
        let percent = Int((Double(consumedItems.count) / Double(total) * 100).rounded())
        return "使い切れた食品の割合：約\(percent)%"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("状況") {
                    StatRow(label: "今週消費すべき（3日以内）", value: expiringSoonItems.count, color: .orange)
                    StatRow(label: "期限切れ", value: expiredItems.count, color: .red)
                    StatRow(label: "登録中の食品", value: activeItems.count, color: .shelfGreen)
                }

                Section {
                    StatRow(label: "消費済みにした件数", value: consumedItems.count, color: .shelfGreen)
                    StatRow(label: "期限切れのまま残っている件数", value: expiredItems.count, color: .red)
                    Text(wasteRatioText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("食品ロス削減の目安")
                } footer: {
                    Text("「消費済み」に切り替えた件数と、期限切れのまま残っている件数の簡易的な目安です。消費した日付までは記録していないため、期間ごとの正確な集計ではなく現在時点のスナップショットです。")
                }

                if !activeItems.isEmpty {
                    Section("保存区分の内訳") {
                        ForEach(byCategory, id: \.0) { category, count in
                            HStack {
                                Label(category.label, systemImage: category.icon)
                                    .foregroundStyle(category.color)
                                Spacer()
                                Text("\(count)件")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }

                if !expiredItems.isEmpty {
                    Section("期限切れの食品") {
                        ForEach(expiredItems) { item in
                            HStack {
                                Text(item.name.isEmpty ? "(名前未入力)" : item.name)
                                Spacer()
                                Text(mediumDate(item.expiryDate))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if allItems.isEmpty {
                    ContentUnavailableView(
                        "まだ集計するデータがありません",
                        systemImage: "chart.pie",
                        description: Text("「一覧」タブから食品を登録すると、ここに統計が表示されます")
                    )
                }
            }
            .navigationTitle("統計")
        }
    }
}

private struct StatRow: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)件")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
        }
    }
}
