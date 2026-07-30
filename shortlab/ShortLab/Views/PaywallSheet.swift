import SwiftUI
import StoreKit

/// 買い切り(透かし解除+広告非表示)の購入シート。
/// かんたんモードとしっかり編集の両方から開くため、文言はかんたんモード基準
/// (カタカナ専門語なし・大ボタン・「マーク」=透かし)。
struct PaywallSheet: View {
    @ObservedObject var purchase: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var restoreMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if purchase.isPremium {
                    purchasedContent
                } else if !purchase.isConfigured {
                    unavailableContent
                } else {
                    offerContent
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("マークなしにする")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("とじる") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var offerContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 12) {
                benefitRow("できあがる動画に「ShortLab」のマークが入らなくなります")
                benefitRow("広告が出なくなります")
                benefitRow("お支払いは一回だけです(月々の料金はありません)")
            }

            if case .failed(let message) = purchase.state {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await purchase.purchase() }
            } label: {
                Group {
                    if purchase.state == .purchasing {
                        ProgressView()
                            .tint(.white)
                    } else if let product = purchase.product {
                        Text("\(product.displayPrice) で購入する")
                    } else {
                        Text("読みこんでいます…")
                    }
                }
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .frame(minHeight: 60)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
            }
            .disabled(purchase.product == nil || purchase.state == .purchasing)
            .opacity(purchase.product == nil ? 0.5 : 1)

            Button {
                Task {
                    let synced = await purchase.restore()
                    if purchase.isPremium {
                        restoreMessage = nil
                    } else if synced {
                        restoreMessage = "購入の記録が見つかりませんでした"
                    } else {
                        // 復元処理そのものの失敗は「記録なし」とは別の文言で伝える
                        restoreMessage = "復元できませんでした。通信環境を確認して、もう一度お試しください"
                    }
                }
            } label: {
                Text("まえに購入したことがある方はこちら")
                    .font(.subheadline)
                    .frame(minHeight: 44)
            }
            .disabled(purchase.state == .purchasing)

            if let restoreMessage {
                Text(restoreMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var purchasedContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("購入済みです")
                .font(.title2.bold())
            Text("マークなし・広告なしで使えます。ありがとうございます!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    /// 製品ID未設定のビルド(開発中・CI)で誤って開いたときの表示
    private var unavailableContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("準備中です")
                .font(.headline)
            Text("開発者向け: Config/Store.local.xcconfig に SHORTLAB_PREMIUM_PRODUCT_ID を設定してください")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .padding(.top, 2)
            Text(text)
                .font(.headline)
        }
    }
}
