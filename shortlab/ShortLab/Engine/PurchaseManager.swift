import Foundation
import StoreKit

/// 買い切り課金(透かし解除+広告非表示)の管理。
/// - 製品IDはコードに直書きせず Info.plist の ShortLabPremiumProductID から読む
///   (値は Config/Store.xcconfig → Store.local.xcconfig で注入。未設定なら購入UIを出さない)。
/// - 購入状態の真実の源は StoreKit の Transaction.currentEntitlements。
///   UserDefaults は起動直後にオフラインでも表示を確定させるためのキャッシュ。
@MainActor
final class PurchaseManager: ObservableObject {

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case failed(String)
    }

    @Published private(set) var isPremium: Bool
    @Published private(set) var product: Product?
    @Published private(set) var state: PurchaseState = .idle

    private let productID: String?
    private var updatesTask: Task<Void, Never>?
    private static let cacheKey = "premiumUnlocked"

    /// xcconfig に製品IDが設定されているか(未設定のビルドでは購入導線を隠す)
    var isConfigured: Bool { productID != nil }

    init() {
        let id = (Bundle.main.object(forInfoDictionaryKey: "ShortLabPremiumProductID") as? String)?
            .trimmingCharacters(in: .whitespaces)
        productID = (id?.isEmpty == false) ? id : nil
        isPremium = UserDefaults.standard.bool(forKey: Self.cacheKey)

        guard productID != nil else { return }

        // アプリ外での購入完了(pending の承認・返金・ファミリー共有)を受け取る常駐リスナー
        updatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { [weak self] in
            await self?.refreshEntitlements()
            await self?.loadProduct()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func purchase() async {
        guard state != .purchasing else { return }
        if product == nil { await loadProduct() }
        guard let product else {
            state = .failed("商品情報を読みこめませんでした。通信環境を確認してください")
            return
        }
        state = .purchasing
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
                state = .idle
            case .userCancelled:
                state = .idle
            case .pending:
                // ファミリーの承認待ち等。完了は Transaction.updates 経由で届く
                state = .failed("承認待ちです。承認されると自動で反映されます")
            @unknown default:
                state = .idle
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// 「まえに購入した方はこちら」(機種変更・入れ直し後の復元)。
    /// 戻り値は同期に成功したか。false は「記録なし」ではなく「復元処理ができなかった」
    /// (通信障害・キャンセル等) — 呼び出し側はこの2つを別の文言で伝えること。
    func restore() async -> Bool {
        guard state != .purchasing else { return false }
        state = .purchasing
        defer { state = .idle }
        var synced = true
        do {
            try await AppStore.sync()
        } catch {
            synced = false
        }
        await refreshEntitlements()
        return synced
    }

    func refreshEntitlements() async {
        guard let productID else { return }
        var owned = false
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            if transaction.productID == productID, transaction.revocationDate == nil {
                owned = true
            }
        }
        setPremium(owned)
    }

    private func loadProduct() async {
        guard let productID, product == nil else { return }
        product = try? await Product.products(for: [productID]).first
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        guard transaction.productID == productID else { return }
        if transaction.revocationDate == nil {
            setPremium(true)
        } else {
            // 返金・共有解除の通知1件で即降格しない。返金後に再購入したケースなど
            // 別の有効な購入が残っている可能性があるため、権利全体から判定し直す
            await refreshEntitlements()
        }
    }

    private func setPremium(_ value: Bool) {
        isPremium = value
        UserDefaults.standard.set(value, forKey: Self.cacheKey)
    }
}
