import SwiftUI
import SwiftData

@main
struct ShisakuLogApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [TrackedApp.self, DailyMetric.self, Action.self])
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            RecordView()
                .tabItem { Label("記録", systemImage: "square.and.pencil") }
            ChartTabView()
                .tabItem { Label("グラフ", systemImage: "chart.xyaxis.line") }
            ActionListView()
                .tabItem { Label("施策ノート", systemImage: "list.bullet.rectangle") }
        }
        .tint(.indigo)
    }
}
