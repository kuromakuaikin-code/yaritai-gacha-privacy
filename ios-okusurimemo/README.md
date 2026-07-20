# お薬手帳メモ（OkusuriMemo）iOS版（SwiftUI）

ご家族一人ひとりのお薬（名前・用量・服用タイミング・処方病院・服用期間）を登録し、「今日、誰が・いつ・どのお薬を飲んだか」をチェックして記録するアプリ。iOS 17+ / SwiftData。

## 機能

- 今日の服薬チェック（朝／昼／晩／寝る前／頓服のタイミングごとに、本日服用が必要なお薬を家族横断でリスト表示。タップでチェックのON/OFF）
- お薬一覧（ご家族ごとにお薬をグルーピング表示。名前・用量・服用タイミング・処方病院・服用中/終了のバッジ・期間を表示）
- ご家族・お薬の追加・編集・削除（お薬は対象の家族選択、服用タイミングの複数選択、開始日／終了日〔継続中トグルあり〕、メモに対応）
- プレミアム／広告なし（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ、無料版はご家族2人・お薬5件まで）
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（JSON、ご家族・お薬・服薬記録を含む）
- 医療アドバイスではない旨の注意書きを「設定」タブに常時表示

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-okusurimemo
xcodegen
open OkusuriMemo.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `OkusuriMemo`（表示名は後で「お薬手帳メモ」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-okusurimemo/OkusuriMemo/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.okusurimemo.premium`（¥160）
   - `com.kuromakuaikin.okusurimemo.adfree`（¥120）
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView` を GADBannerView に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/okusuri-memo/privacy.html`
5. プライバシー「栄養表示」: ユーザーデータ収集なし（広告はAdMob SDKの申告に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定
7. 「本アプリは個人の記録用メモであり、医学的な助言を目的としたものではない」旨の注意書き（設定タブ内）は削除・改変せず、リリース後も常に表示されるようにすること

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- 既存の「婚活デートメモ」（`../ios/`）「ご祝儀・香典メモ」（`../ios-shugimemo/`）とは別アプリ・別Xcodeプロジェクトです。
