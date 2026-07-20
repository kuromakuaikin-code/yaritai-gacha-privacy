import SwiftUI
import SwiftData
import Charts

// MARK: - グラフ

struct GrowthChartView: View {
    @Query(sort: \Child.createdAt) private var children: [Child]
    @State private var selectedChild: Child?

    private var currentChild: Child? {
        if let selectedChild, children.contains(where: { $0.persistentModelID == selectedChild.persistentModelID }) {
            return selectedChild
        }
        return children.first
    }

    private var sortedRecords: [GrowthRecord] {
        guard let currentChild else { return [] }
        return currentChild.records.sorted { $0.date < $1.date }
    }

    private var heightPoints: [GrowthPoint] {
        guard let currentChild else { return [] }
        return sortedRecords.compactMap { record in
            guard let h = record.heightCm else { return nil }
            return GrowthPoint(date: record.date, month: ageInMonths(birthday: currentChild.birthday, at: record.date), value: h)
        }
    }

    private var weightPoints: [GrowthPoint] {
        guard let currentChild else { return [] }
        return sortedRecords.compactMap { record in
            guard let w = record.weightKg else { return nil }
            return GrowthPoint(date: record.date, month: ageInMonths(birthday: currentChild.birthday, at: record.date), value: w)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if children.isEmpty {
                    ContentUnavailableView(
                        "お子さまが登録されていません",
                        systemImage: "chart.xyaxis.line",
                        description: Text("「記録一覧」タブからお子さまを登録すると、成長グラフが表示されます")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
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
                            }

                            GrowthChartCard(title: "身長", unit: "cm", color: .kodomoTeal, points: heightPoints)
                            GrowthChartCard(title: "体重", unit: "kg", color: .orange, points: weightPoints)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("グラフ")
        }
    }
}

struct GrowthPoint: Identifiable {
    let date: Date
    let month: Int
    let value: Double
    var id: Date { date }
}

struct GrowthChartCard: View {
    let title: String
    let unit: String
    let color: Color
    let points: [GrowthPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title)（\(unit)）")
                .font(.headline)

            if points.count >= 2 {
                Chart(points) { point in
                    LineMark(
                        x: .value("月齢", point.month),
                        y: .value(title, point.value)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("月齢", point.month),
                        y: .value(title, point.value)
                    )
                    .foregroundStyle(color)
                }
                .chartXAxisLabel("月齢（ヶ月）")
                .frame(height: 200)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("\(title)の記録が2件以上あるとグラフが表示されます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator).opacity(0.3)))
    }
}
