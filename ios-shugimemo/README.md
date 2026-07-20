# ご祝儀・香典メモ（ShugiMemo）iOS版（SwiftUI）

結婚式のご祝儀、お葬式の香典、出産・入学・新築祝いなど「誰に・いくら・いつ」渡した／いただいたかを記録し、相場の目安とお返し（香典返し・内祝い）の対応状況を管理するアプリ。iOS 17+ / SwiftData。

## 機能

- 記録管理（行事の種類・相手・関係性・金額・日付・メモ、検索／方向で絞り込み）
- 相場ガイド（行事×関係性ごとの金額の目安を一覧表示、静的データ）
- お返し管理（いただいた記録に「未対応／対応済み」を設定、半返し目安額を自動計算）
- 集計（渡した合計／いただいた合計／差額、行事別合計、年で絞り込み、お返し未対応の一覧）
- プレミアム／広告なし（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ、無料版は記録\(15\)件まで）
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（JSON）

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-shugimemo
xcodegen
open ShugiMemo.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `ShugiMemo`（表示名は後で「ご祝儀メモ」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-shugimemo/ShugiMemo/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.shugimemo.premium`（¥160）
   - `com.kuromakuaikin.shugimemo.adfree`（¥120）
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView` を GADBannerView に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/shugi-memo/privacy.html`
5. プライバシー「栄養表示」: ユーザーデータ収集なし（広告はAdMob SDKの申告に従う）
6. 相場データ（`Models.swift` の `MarketRateData`）はあくまで一般的な目安。地域差・慣習の変化があるため、リリース前に最新情報で見直すこと

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- 既存の「婚活デートメモ」（`../ios/`）とは別アプリ・別Xcodeプロジェクトです。
