import SwiftUI

@main
struct ShortLabApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// かんたんモード(既定)としっかり編集の切替。
/// EditorViewModel を1つだけ持ち、両モードで共有する(切替しても編集内容が引きつがれる)。
/// PurchaseManager(課金状態)も同様にここで1つだけ作って配る。
struct RootView: View {
    @StateObject private var viewModel = EditorViewModel()
    @StateObject private var purchase = PurchaseManager()
    @AppStorage("useSimpleMode") private var useSimpleMode = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if useSimpleMode {
                SimpleModeView(viewModel: viewModel, purchase: purchase) {
                    useSimpleMode = false
                }
                // かんたんモードは明るい配色(シニアは白背景のほうが読みやすい)
                .preferredColorScheme(.light)
            } else {
                EditorView(viewModel: viewModel, purchase: purchase) {
                    useSimpleMode = true
                }
                .preferredColorScheme(.dark)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // 自動保存はデバウンス(500ms)のため、バックグラウンド移行時に確定させる
            if phase == .background {
                viewModel.saveNow()
            }
        }
    }
}
