import SwiftUI
import StoreKit

/// PAY-01: 課金画面（購入・復元・規約リンク）
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscription

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "doc.badge.clock")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)

                Text("個人プラン")
                    .font(.title.bold())

                VStack(alignment: .leading, spacing: 14) {
                    featureRow(symbol: "photo.stack", text: "現場写真を案件ごとに無制限で保存")
                    featureRow(symbol: "doc.richtext", text: "日報・完了報告書 PDF を何枚でも作成")
                    featureRow(symbol: "square.and.arrow.up", text: "LINE・メールでそのまま共有")
                }
                .padding(.horizontal, 32)

                if let product = subscription.product {
                    Text("\(product.displayPrice) / 月・初回14日間無料")
                        .font(.headline)
                } else {
                    Text("初回14日間無料")
                        .font(.headline)
                }

                VStack(spacing: 10) {
                    Button {
                        Task {
                            await subscription.purchase()
                            if subscription.status == .subscribed { dismiss() }
                        }
                    } label: {
                        Group {
                            if subscription.isPurchasing {
                                ProgressView()
                            } else {
                                Text("購入する")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(subscription.isPurchasing)

                    Button("購入を復元") {
                        Task {
                            await subscription.restore()
                            if subscription.status == .subscribed { dismiss() }
                        }
                    }
                    .disabled(subscription.isPurchasing)
                }
                .padding(.horizontal, 32)

                HStack(spacing: 16) {
                    Link("利用規約", destination: URL(string: "https://example.com/terms")!)
                    Link("プライバシーポリシー", destination: URL(string: "https://example.com/privacy")!)
                }
                .font(.footnote)
                .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("閉じる")
                }
            }
            .task {
                if subscription.product == nil {
                    await subscription.loadProduct()
                }
            }
            .alert("エラー", isPresented: Binding(
                get: { subscription.purchaseError != nil },
                set: { if !$0 { subscription.purchaseError = nil } }
            )) {
                Button("OK") { subscription.purchaseError = nil }
            } message: {
                Text(subscription.purchaseError ?? "")
            }
        }
    }

    private func featureRow(symbol: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionManager())
}
