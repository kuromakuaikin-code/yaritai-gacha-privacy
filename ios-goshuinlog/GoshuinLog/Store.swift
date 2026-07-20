import Foundation
import StoreKit
import SwiftUI
import CryptoKit

// MARK: - アプリ設定

enum AppConfig {
    static let version = "1.0.0"
    /// テスト期間中は true（購入ボタンで無料解放）。App Store 提出前に false にして IAP を有効化する
    static let freeTrial = true
    /// 無料版で登録できる記録の上限
    static let freeRecordLimit = 20
    /// 広告表示（広告なし/プレミアム購入者には出ない）。AdMob 組み込みまでサンプル枠
    static let adsEnabled = true

    static let premiumPriceLabel = "¥160"
    static let adFreePriceLabel = "¥120"

    // App Store Connect で作成する非消耗型IAPのプロダクトID
    static let premiumProductID = "com.kuromakuaikin.goshuinlog.premium"
    static let adFreeProductID = "com.kuromakuaikin.goshuinlog.adfree"

    static let privacyURL = URL(string: "https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/goshuin-log/privacy.html")!
    static let termsURL = URL(string: "https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/goshuin-log/terms.html")!
}

// MARK: - 購入状態（StoreKit 2）

@MainActor
final class PurchaseStore: ObservableObject {
    @AppStorage("premium") var premium = false
    @AppStorage("adFree") var adFree = false

    @Published var products: [Product] = []
    private var updatesTask: Task<Void, Never>?

    var isAdFree: Bool { adFree || premium }
    var isUnlimited: Bool { premium }

    init() {
        guard !AppConfig.freeTrial else { return }
        updatesTask = Task { await listenForTransactions() }
        Task { await load() }
    }

    deinit { updatesTask?.cancel() }

    func load() async {
        do {
            products = try await Product.products(for: [AppConfig.premiumProductID,
                                                        AppConfig.adFreeProductID])
            await refreshEntitlements()
        } catch {
            // 読み込み失敗時は次回起動時に再試行
        }
    }

    func buyPremium() async {
        if AppConfig.freeTrial { premium = true; return }
        await buy(productID: AppConfig.premiumProductID)
    }

    func buyAdFree() async {
        if AppConfig.freeTrial { adFree = true; return }
        await buy(productID: AppConfig.adFreeProductID)
    }

    func restore() async {
        guard !AppConfig.freeTrial else { return }
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func buy(productID: String) async {
        guard let product = products.first(where: { $0.id == productID }) else { return }
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result,
               case .verified(let transaction) = verification {
                apply(transaction)
                await transaction.finish()
            }
        } catch {
            // キャンセル・失敗時は何もしない
        }
    }

    private func refreshEntitlements() async {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement {
                apply(transaction)
            }
        }
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                apply(transaction)
                await transaction.finish()
            }
        }
    }

    private func apply(_ transaction: Transaction) {
        switch transaction.productID {
        case AppConfig.premiumProductID: premium = true
        case AppConfig.adFreeProductID: adFree = true
        default: break
        }
    }
}

// MARK: - パスコード（SHA-256で保存）

enum Passcode {
    static func hash(_ code: String) -> String {
        let digest = SHA256.hash(data: Data(("goshuinlog:" + code).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
