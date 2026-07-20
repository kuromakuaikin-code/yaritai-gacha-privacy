import Foundation
import StoreKit
import SwiftUI

// MARK: - アプリ設定

enum AppConfig {
    static let version = "1.0.0"
    /// テスト期間中は true（購入ボタンで無料解放）。App Store 提出前に false にして IAP を有効化する
    static let freeTrial = true

    /// 無料版で追加できるクリップ（動画）の上限本数
    static let freeClipLimit = 3
    /// 無料版で選べるテキストスタイルの種類数（先頭からこの数だけ）
    static let freeStyleCount = 2
    /// 無料版で選べる絵文字ステッカーの種類数（先頭からこの数だけ）
    static let freeStickerCount = 6
    /// 無料版で貼り付けられるステッカーの最大個数
    static let freeMaxPlacedStickers = 6
    /// 書き出す動画の合計尺の上限（秒）。プレミアムでもこの上限は超えられない
    static let maxTotalDurationSeconds: Double = 5 * 60

    /// 広告表示。子ども向けアプリのため既定で false（AdBannerView.swift のコメントも参照）
    static let adsEnabled = false

    static let premiumPriceLabel = "¥360"

    // App Store Connect で作成する非消耗型IAPのプロダクトID
    static let premiumProductID = "com.kuromakuaikin.kidsvideoeditor.premium"

    static let privacyURL = URL(string: "https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/kids-video-editor/privacy.html")!
    static let termsURL = URL(string: "https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/kids-video-editor/terms.html")!
}

// MARK: - 購入状態（StoreKit 2・買い切り1種類のみ）

@MainActor
final class PurchaseStore: ObservableObject {
    @AppStorage("premium") var premium = false

    @Published var products: [Product] = []
    private var updatesTask: Task<Void, Never>?

    init() {
        guard !AppConfig.freeTrial else { return }
        updatesTask = Task { await listenForTransactions() }
        Task { await load() }
    }

    deinit { updatesTask?.cancel() }

    func load() async {
        do {
            products = try await Product.products(for: [AppConfig.premiumProductID])
            await refreshEntitlements()
        } catch {
            // 読み込み失敗時は次回起動時に再試行
        }
    }

    func buyPremium() async {
        if AppConfig.freeTrial { premium = true; return }
        guard let product = products.first(where: { $0.id == AppConfig.premiumProductID }) else { return }
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result,
               case .verified(let transaction) = verification {
                premium = true
                await transaction.finish()
            }
        } catch {
            // キャンセル・失敗時は何もしない
        }
    }

    func restore() async {
        guard !AppConfig.freeTrial else { return }
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == AppConfig.premiumProductID {
                premium = true
            }
        }
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update,
               transaction.productID == AppConfig.premiumProductID {
                premium = true
                await transaction.finish()
            }
        }
    }
}
