import SwiftUI

@main
struct ShortLabApp: App {
    var body: some Scene {
        WindowGroup {
            EditorView()
                .preferredColorScheme(.dark)
        }
    }
}
