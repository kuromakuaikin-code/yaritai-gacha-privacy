# お守り返納リマインダー（OmamoriReminder）iOS版（SwiftUI）

神社・お寺でいただいたお守り・御札・破魔矢を記録し、返納の時期（授与から約1年後が目安、どんど焼きや授与された社寺への返納）を忘れないためのリマインダーアプリ。iOS 17+ / SwiftData。

## 機能

- 登録管理（社寺名・種類「お守り／御札／破魔矢／その他」・ご利益「開運招福／交通安全／縁結び／健康祈願／学業成就／安産祈願／その他」・授与日・返納目安日・メモ）
- 返納目安日は授与日の1年後を自動計算しつつ、ユーザーが自由に調整可能
- 一覧は「返納時期が近い・過ぎている」ものを優先表示（「返納時期です」バッジ付き）、返納済みは折りたたみ表示。種類での絞り込み・スワイプ削除に対応
- お守りの作法ガイド（返納方法・時期の目安・複数の社寺のお守りを持つことについて・古いお守りの処分方法など、静的な一般情報を掲載）
- プレミアム／広告なし（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ、無料版は登録\(10\)件まで）
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（JSON）

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-omamorireminder
xcodegen
open OmamoriReminder.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `OmamoriReminder`（表示名は後で「お守り返納リマインダー」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-omamorireminder/OmamoriReminder/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.omamorireminder.premium`（¥160）
   - `com.kuromakuaikin.omamorireminder.adfree`（¥120）
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView` を GADBannerView に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/omamori-reminder/privacy.html`
5. プライバシー「栄養表示」: ユーザーデータ収集なし（広告はAdMob SDKの申告に従う）
6. 作法ガイドの内容（`Models.swift` の `GuideData`）はあくまで一般的な参考情報。神社・お寺により考え方・受け付け方法が異なるため、リリース前に内容を見直すこと

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- 既存の「ご祝儀・香典メモ」（`../ios-shugimemo/`）などとは別アプリ・別Xcodeプロジェクトです。
