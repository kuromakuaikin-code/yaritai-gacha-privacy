import SwiftUI
import SwiftData

@main
struct GenpouApp: App {
    @State private var subscription = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(subscription)
                .task {
                    await subscription.loadProduct()
                    await subscription.refresh()
                }
        }
        .modelContainer(for: [CompanyProfile.self, Project.self, SitePhoto.self])
    }
}

struct RootView: View {
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [CompanyProfile]

    /// 屋号未登録ならオンボーディング必須
    private var needsOnboarding: Bool {
        (profiles.first?.companyName ?? "").isEmpty
    }

    var body: some View {
        TabView {
            NavigationStack {
                ProjectListView()
            }
            .tabItem { Label("案件", systemImage: "folder") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .fullScreenCover(isPresented: .constant(needsOnboarding)) {
            OnboardingView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await subscription.refresh() }
            }
        }
    }
}

#Preview {
    RootView()
        .environment(SubscriptionManager())
        .modelContainer(PreviewData.container)
}
