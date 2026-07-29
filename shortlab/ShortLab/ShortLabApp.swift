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
struct RootView: View {
    @StateObject private var viewModel = EditorViewModel()
    @AppStorage("useSimpleMode") private var useSimpleMode = true

    var body: some View {
        Group {
            if useSimpleMode {
                SimpleModeView(viewModel: viewModel) {
                    useSimpleMode = false
                }
                // かんたんモードは明るい配色(シニアは白背景のほうが読みやすい)
                .preferredColorScheme(.light)
            } else {
                EditorView(viewModel: viewModel) {
                    useSimpleMode = true
                }
                .preferredColorScheme(.dark)
            }
        }
    }
}
