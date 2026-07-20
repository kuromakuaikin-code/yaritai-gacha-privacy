import SwiftUI

@main
struct KidsVideoEditorApp: App {
    @StateObject private var store = PurchaseStore()
    @StateObject private var project = VideoProject()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(project)
        }
    }
}

// MARK: - ルート画面（「つくる」「せってい」の2つのタブ）

struct RootView: View {
    @EnvironmentObject private var store: PurchaseStore
    @EnvironmentObject private var project: VideoProject

    var body: some View {
        TabView {
            NavigationStack(path: $project.path) {
                CreateFlowHomeView()
                    .navigationDestination(for: FlowStep.self) { step in
                        destination(for: step)
                    }
            }
            .tabItem { Label("つくる", systemImage: "video.badge.plus") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("せってい", systemImage: "gearshape.fill") }
        }
        .tint(.pink)
        .safeAreaInset(edge: .bottom) {
            if AppConfig.adsEnabled && !store.premium {
                AdBannerView()
            }
        }
    }

    @ViewBuilder
    private func destination(for step: FlowStep) -> some View {
        switch step {
        case .clipPicker:
            ClipPickerView()
        case .trim(let clipID):
            TrimView(clipID: clipID)
        case .caption:
            CaptionEditorView()
        case .stickers:
            StickerPickerView()
        case .music:
            MusicPickerView()
        case .export:
            ExportView()
        }
    }
}

// MARK: - 「つくる」フローのホーム画面

struct CreateFlowHomeView: View {
    @EnvironmentObject private var project: VideoProject

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("🎬")
                .font(.system(size: 90))

            Text("きっず どうが へんしゅう")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)

            Text("どうがを えらんで つなげて\nもじや シールを つけよう！")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                project.reset()
                project.path.append(FlowStep.clipPicker)
            } label: {
                Text("あたらしい どうがを つくる")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.vertical, 22)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(colors: [.pink, .orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .pink.opacity(0.4), radius: 10, y: 6)
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .navigationTitle("きっず動画編集")
        .navigationBarTitleDisplayMode(.inline)
    }
}
