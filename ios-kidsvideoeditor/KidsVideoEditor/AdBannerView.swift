import SwiftUI

// MARK: - 広告枠（プレースホルダー）
//
// AppConfig.adsEnabled は既定で false（このアプリは子ども向けのため、広告は既定オフとする）。
//
// もし将来この Kids 向けアプリで広告を有効化する場合は、必ず以下を守ること：
// 1. Google AdMob の「児童向け設定」（Tag For Child Directed Treatment / TFCD）および
//    「児童向けタグ設定」（tagged for child directed treatment）を有効にし、
//    行動ターゲティング広告ではなく非パーソナライズ（文脈）広告のみを配信すること。
// 2. COPPA 等、子ども向けアプリに関する規制に準拠していることが確認された
//    広告ネットワーク／SDK 設定のみを使用すること。
// 3. ATT（App Tracking Transparency）のトラッキング許可ダイアログは、
//    子ども向けカテゴリのアプリでは絶対に表示しない（トラッキングを一切行わない）こと。
//
// 実装時は Google-Mobile-Ads-SDK を追加し、ここを GADBannerView の
// UIViewRepresentable に置き換える。
struct AdBannerView: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("広告")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.4)))
            Text("ここに広告が表示されます（サンプル枠・既定は非表示）")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(.bar)
    }
}
