# 子どもの成長記録（KodomoGrowth）iOS版（SwiftUI）

母子手帳の成長曲線ページのように、お子さまの身長・体重を日々記録し、グラフで成長を振り返れるアプリ。iOS 17+ / SwiftData。

## 機能

- お子さまのプロフィール管理（お名前・誕生日・性別・メモ、複数人登録可）
- 成長記録（日付・身長・体重・メモ、記録時点の年齢を「2歳3ヶ月」のように自動表示、スワイプで削除）
- グラフ（Swift Charts。身長・体重をそれぞれ月齢の推移で折れ線表示。記録が2件以上ある項目のみ表示）
- プレミアム／広告なし（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ、無料版はお子さま1人まで登録可）
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（JSON、お子さまのプロフィール＋成長記録を含む）

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-kodomogrowth
xcodegen
open KodomoGrowth.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `KodomoGrowth`（表示名は後で「子どもの成長記録」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-kodomogrowth/KodomoGrowth/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.kodomogrowth.premium`（¥160）
   - `com.kuromakuaikin.kodomogrowth.adfree`（¥120）
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView` を GADBannerView に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/kodomo-growth/privacy.html`
5. プライバシー「栄養表示」: ユーザーデータ収集なし（広告はAdMob SDKの申告に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定すること

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- 既存の「婚活デートメモ」（`../ios/`）、「ご祝儀・香典メモ」（`../ios-shugimemo/`）とは別アプリ・別Xcodeプロジェクトです。
