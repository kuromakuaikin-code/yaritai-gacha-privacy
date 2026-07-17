import Foundation
import Observation
import StoreKit

/// 課金状態の管理（StoreKit 2 / サーバーレス）。
/// トライアル開始日は UserDefaults に保存し、14 日経過かつ未購読なら expired。
@MainActor
@Observable
final class SubscriptionManager {
    enum Status: Equatable {
        case trial(daysLeft: Int)
        case subscribed
        case expired
    }

    static let productId = "genpou.personal.monthly"
    static let trialDays = 14
    static let trialStartKey = "trialStartDate"

    private(set) var status: Status = .expired
    private(set) var product: Product?
    private(set) var isPurchasing = false
    var purchaseError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        // 購入・返金などトランザクション更新の監視
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
    }

    /// expired 以外なら写真追加・PDF 生成が可能。
    var canUsePremiumFeatures: Bool { status != .expired }

    var statusLabelJP: String {
        switch status {
        case .trial(let daysLeft): return "無料トライアル（残り\(daysLeft)日）"
        case .subscribed: return "個人プラン 契約中"
        case .expired: return "未契約"
        }
    }

    /// オンボーディング完了時に一度だけ呼ぶ。
    func startTrialIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.trialStartKey) == nil {
            defaults.set(Date(), forKey: Self.trialStartKey)
        }
    }

    /// 起動時・フォアグラウンド復帰時に呼ぶ。
    func refresh() async {
        var hasEntitlement = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productId, transaction.revocationDate == nil {
                hasEntitlement = true
            }
        }
        if hasEntitlement {
            status = .subscribed
            return
        }
        guard let start = UserDefaults.standard.object(forKey: Self.trialStartKey) as? Date else {
            // オンボーディング前。ゲート対象機能には到達しない。
            status = .expired
            return
        }
        let elapsedDays = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        let daysLeft = Self.trialDays - elapsedDays
        status = daysLeft > 0 ? .trial(daysLeft: daysLeft) : .expired
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productId]).first
        } catch {
            // オフライン等。Paywall 表示時に再試行する。
        }
    }

    func purchase() async {
        guard !isPurchasing else { return }
        if product == nil { await loadProduct() }
        guard let product else {
            purchaseError = "商品情報を取得できませんでした。通信環境をご確認ください。"
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refresh()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = "購入に失敗しました。時間をおいて再度お試しください。"
        }
    }

    func restore() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
        } catch {
            purchaseError = "復元に失敗しました。時間をおいて再度お試しください。"
        }
        await refresh()
    }

    #if DEBUG
    /// 受け入れ確認用: トライアルを強制的に期限切れにする。
    func debugExpireTrial() {
        let past = Calendar.current.date(byAdding: .day, value: -(Self.trialDays + 1), to: Date())!
        UserDefaults.standard.set(past, forKey: Self.trialStartKey)
        Task { await refresh() }
    }

    /// 受け入れ確認用: トライアルを今日から開始し直す。
    func debugResetTrial() {
        UserDefaults.standard.set(Date(), forKey: Self.trialStartKey)
        Task { await refresh() }
    }
    #endif
}
