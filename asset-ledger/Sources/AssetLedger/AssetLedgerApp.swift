import SwiftUI
import AppKit

/// 3D素材サムネ台帳 — TRELLIS2/ComfyUI等の出力フォルダを監視し、
/// GLB/usdz/画像を自動でサムネイル化して一覧表示するmacOSアプリ。
/// 完全ローカル・外部通信なし。
@main
struct AssetLedgerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = LibraryStore()

    var body: some Scene {
        WindowGroup("素材サムネ台帳", id: "main") {
            ContentView()
                .environmentObject(store)
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }

        // メニューバー常駐: 未閲覧があればバッジ（件数）を表示
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: store.unviewedCount > 0
                      ? "square.grid.2x2.fill" : "square.grid.2x2")
                if store.unviewedCount > 0 {
                    Text("\(store.unviewedCount)")
                        .font(.caption2)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// swift run（バンドル外実行）でもウインドウを前面に出すための調整
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
