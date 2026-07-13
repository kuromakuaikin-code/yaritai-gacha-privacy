import SwiftUI
import SwiftData
import Charts
import UIKit

// MARK: - タブ2: グラフ（このアプリの核）
// 収益/DLの折れ線に、施策の実施日を縦線+ラベルでオーバーレイする。

enum ChartRange: Int, CaseIterable, Identifiable {
    case week = 7, month = 30, quarter = 90

    var id: Int { rawValue }
    var days: Int { rawValue }
    var label: String { "\(rawValue)日" }
}

struct ChartPoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

struct ChartTabView: View {
    @Query(sort: \TrackedApp.createdAt) private var allApps: [TrackedApp]
    @Query private var metrics: [DailyMetric]
    @Query(sort: \Action.date) private var actions: [Action]
    @AppStorage("selectedAppId") private var selectedAppId = ""

    @State private var range: ChartRange = .month
    @State private var kind: MetricKind = .revenue
    @State private var tappedAction: Action?

    private var apps: [TrackedApp] { allApps.filter { !$0.isArchived } }
    private var selectedApp: TrackedApp? { resolveSelectedApp(apps, selectedAppId) }

    private var domainStart: Date { Day.add(Day.today(), -(range.days - 1)) }

    private var appMetrics: [DailyMetric] {
        guard let app = selectedApp else { return [] }
        return metrics.filter { $0.appId == app.id }
    }

    private var points: [ChartPoint] {
        appMetrics
            .filter { Day.start($0.date) >= domainStart }
            .compactMap { m -> ChartPoint? in
                let value: Double? = kind == .revenue ? m.revenue : m.downloads.map(Double.init)
                guard let value else { return nil }
                return ChartPoint(date: Day.start(m.date), value: value)
            }
            .sorted { $0.date < $1.date }
    }

    private var visibleActions: [Action] {
        guard let app = selectedApp else { return [] }
        return actions.filter {
            $0.appId == app.id
                && Day.start($0.date) >= domainStart
                && Day.start($0.date) <= Day.today()
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if apps.isEmpty {
                    ContentUnavailableView("アプリが未登録です", systemImage: "chart.xyaxis.line",
                                           description: Text("記録タブでアプリを追加してください"))
                } else {
                    ScrollView {
                        content
                            .padding()
                    }
                }
            }
            .navigationTitle("グラフ")
            .sheet(item: $tappedAction) { action in
                NavigationStack {
                    ActionDetailView(action: action)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppScopeHeader(apps: apps, selectedId: $selectedAppId)

            Picker("指標", selection: $kind) {
                ForEach(MetricKind.allCases) { k in
                    Text(k.label).tag(k)
                }
            }
            .pickerStyle(.segmented)

            Picker("期間", selection: $range) {
                ForEach(ChartRange.allCases) { r in
                    Text(r.label).tag(r)
                }
            }
            .pickerStyle(.segmented)

            chart

            Text("縦線＝施策の実施日。縦線の近くをタップすると前後比較を表示します")
                .font(.caption2)
                .foregroundStyle(.secondary)

            actionListSection
        }
    }

    // MARK: グラフ本体

    private var chart: some View {
        Chart {
            ForEach(points) { p in
                LineMark(
                    x: .value("日付", p.date, unit: .day),
                    y: .value(kind.label, p.value)
                )
                .interpolationMethod(.monotone)
                PointMark(
                    x: .value("日付", p.date, unit: .day),
                    y: .value(kind.label, p.value)
                )
                .symbolSize(range == .quarter ? 10 : 22)
            }
            ForEach(visibleActions) { action in
                RuleMark(x: .value("施策", Day.start(action.date), unit: .day))
                    .foregroundStyle(Color.orange.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading, spacing: 0) {
                        Text(action.title)
                            .font(.system(size: 9))
                            .lineLimit(1)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(.orange)
                    }
            }
        }
        .chartXScale(domain: domainStart...Day.add(Day.today(), 1))
        .chartYAxisLabel(kind == .revenue ? "円" : "件")
        .frame(height: 280)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleTap(location, proxy: proxy, geo: geo)
                    }
            }
        }
        .overlay {
            if points.isEmpty {
                Text("この期間のデータがありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// タップ位置に最も近い施策の縦線を探して詳細を開く
    private func handleTap(_ location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let x = location.x - geo[plotFrame].origin.x
        guard let date = proxy.value(atX: x, as: Date.self) else { return }
        // 表示期間の1/20（最低1日）を許容範囲とする
        let tolerance = max(1.0, Double(range.days) / 20.0) * 86_400
        guard let nearest = visibleActions.min(by: {
            abs(Day.start($0.date).timeIntervalSince(date)) < abs(Day.start($1.date).timeIntervalSince(date))
        }) else { return }
        if abs(Day.start(nearest.date).timeIntervalSince(date)) <= tolerance {
            tappedAction = nearest
        }
    }

    // MARK: 期間内の施策リスト

    private var actionListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("この期間の施策")
                .font(.headline)
            if visibleActions.isEmpty {
                Text("この期間に施策はありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(visibleActions.reversed()) { action in
                Button {
                    tappedAction = action
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            CategoryChip(category: action.category)
                            Text(mediumDate(action.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(action.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(comparisonSummary(
                            Comparison.beforeAfter(actionDate: action.date,
                                                   samples: appMetrics.samples(kind)),
                            unit: kind.unit))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
