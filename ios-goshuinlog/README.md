# 御朱印帳ログ（GoshuinLog）iOS版（SwiftUI）

神社・お寺で受けた御朱印の参拝記録（参拝先・都道府県・参拝日・初穂料/拝観料・祈願内容・評価・メモ）を残せるアプリ。写真は保存せず、御朱印のデザインなどはメモに記述する方式。iOS 17+ / SwiftData。

## 機能

- 記録管理（参拝先名・神社/寺の種類・都道府県・参拝日・初穂料/拝観料・祈願内容・5段階評価・メモ、検索／種類で絞り込み）
- 集計（参拝回数、神社/寺の内訳、訪れた都道府県のカバレッジ「N / 47」、祈願内容別の件数、今年の初穂料・拝観料合計、年で絞り込み）
- プレミアム／広告なし（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ、無料版は記録\(20\)件まで）
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（JSON）

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-goshuinlog
xcodegen
open GoshuinLog.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `GoshuinLog`（表示名は後で「御朱印帳ログ」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-goshuinlog/GoshuinLog/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.goshuinlog.premium`（¥160）
   - `com.kuromakuaikin.goshuinlog.adfree`（¥120）
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView` を GADBannerView に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/goshuin-log/privacy.html`
5. プライバシー「栄養表示」: ユーザーデータ収集なし（広告はAdMob SDKの申告に従う）

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- 既存の「婚活デートメモ」（`../ios/`）・「ご祝儀・香典メモ」（`../ios-shugimemo/`）とは別アプリ・別Xcodeプロジェクトです。
