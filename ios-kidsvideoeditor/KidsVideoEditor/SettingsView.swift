import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: PurchaseStore
    @State private var pendingAction: PendingAction?
    @State private var showGate = false

    private enum PendingAction {
        case buyPremium, restore, privacy, terms
    }

    var body: some View {
        List {
            Section("プレミアム") {
                if store.premium {
                    Label("プレミアム きのう ON", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.pink)
                } else {
                    Button {
                        request(.buyPremium)
                    } label: {
                        HStack {
                            Label("プレミアムに アップグレード", systemImage: "star.fill")
                            Spacer()
                            Text(AppConfig.premiumPriceLabel).foregroundStyle(.secondary)
                        }
                    }
                    Button("こうにゅうを ふくげんする") {
                        request(.restore)
                    }
                }
            } footer: {
                Text("プレミアム：すかしを けす・どうが むせいげん（あわせて さいだい5ふん）・ぜんぶの もじスタイルと シールが つかえます。こうにゅうには おうちの人による かくにん（かんたんな けいさん）が ひつようです。")
            }

            Section("このアプリについて") {
                Button("プライバシーポリシー") { request(.privacy) }
                Button("りようきやく") { request(.terms) }
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text(AppConfig.version).foregroundStyle(.secondary)
                }
            } footer: {
                Text("このアプリは こどもが つかうことを かんがえて つくられています。がいぶへの リンクを ひらく まえに、おうちの人への かくにんが あります。")
            }
        }
        .navigationTitle("せってい")
        .parentalGate(isPresented: $showGate) {
            performPendingAction()
        }
    }

    private func request(_ action: PendingAction) {
        pendingAction = action
        showGate = true
    }

    private func performPendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .buyPremium:
            Task { await store.buyPremium() }
        case .restore:
            Task { await store.restore() }
        case .privacy:
            UIApplication.shared.open(AppConfig.privacyURL)
        case .terms:
            UIApplication.shared.open(AppConfig.termsURL)
        }
    }
}
