import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// AdMob バナーの掲載口。編集画面には出さない設計のため、置いてよいのは保存・書き出し完了まわりのみ。
/// - GoogleMobileAds は SPM パッケージ(Xcode で追加)が入っているときだけ実体化する。
///   未追加でもビルドが通るよう canImport でガード(CI はパッケージなしでビルドする)。
/// - 広告ユニットIDは Info.plist の ShortLabAdMobBannerUnitID(xcconfig 注入)。未設定なら何も出さない。
/// - 購入者(isPremium)には表示しない。
/// - ATT ダイアログを出さない方針のため、非パーソナライズ配信(npa=1)に固定。
struct AdBannerView: View {
    @ObservedObject var purchase: PurchaseManager

    private var adUnitID: String? {
        let id = (Bundle.main.object(forInfoDictionaryKey: "ShortLabAdMobBannerUnitID") as? String)?
            .trimmingCharacters(in: .whitespaces)
        return (id?.isEmpty == false) ? id : nil
    }

    var body: some View {
#if canImport(GoogleMobileAds)
        if let adUnitID, !purchase.isPremium {
            BannerContainer(adUnitID: adUnitID)
                .frame(width: 320, height: 50)
        }
#else
        EmptyView()
#endif
    }
}

#if canImport(GoogleMobileAds)
/// GoogleMobileAds 12.x の Swift API 前提(11.x 以前は GADBannerView 等の GAD 接頭辞に読み替え)。
private struct BannerContainer: UIViewRepresentable {
    let adUnitID: String

    static var sdkStarted = false

    func makeUIView(context: Context) -> BannerView {
        if !Self.sdkStarted {
            Self.sdkStarted = true
            MobileAds.shared.start()
        }
        let view = BannerView(adSize: AdSizeBanner)
        view.adUnitID = adUnitID
        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        view.load(request)
        return view
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
#endif
