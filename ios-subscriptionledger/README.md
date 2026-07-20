# サブスク管理帳（SubscriptionLedger）iOS版（SwiftUI）

動画配信・音楽配信・クラウドストレージ・ニュース・フィットネス・ゲームなど、家庭で契約している複数のサブスクリプションサービスの「サービス名・料金・支払いサイクル・次回更新日」をまとめて記録し、月あたりの合計コストを一目で把握できるアプリ。iOS 17+ / SwiftData。

## 機能

- サブスク管理（サービス名・カテゴリー・月払い/年払い・金額・支払日（年払いは支払月も）・契約開始日・契約中/解約済みの状態・メモ）
- 一覧（月換算の合計コストをサマリーカードで表示、契約中を先に・解約済みはグレー表示、次回更新日を自動計算して表示、スワイプで削除）
- 統計（契約中の件数、月あたりの合計、年間換算の合計、カテゴリー別の月換算コスト内訳を多い順に表示）
- プレミアム／広告なし（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ、無料版は登録\(5\)件まで）
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（JSON）

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-subscriptionledger
xcodegen
open SubscriptionLedger.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `SubscriptionLedger`（表示名は後で「サブスク管理帳」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-subscriptionledger/SubscriptionLedger/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.subscriptionledger.premium`（¥160）
   - `com.kuromakuaikin.subscriptionledger.adfree`（¥120）
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView` を GADBannerView に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/subscription-ledger/privacy.html`
5. プライバシー「栄養表示」: ユーザーデータ収集なし（広告はAdMob SDKの申告に従う）
6. アプリアイコンはまだ用意されていません。1024×1024のアイコン画像を作成し、Assets の AppIcon に設定すること

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- 既存の「ご祝儀・香典メモ」（`../ios-shugimemo/`）などとは別アプリ・別Xcodeプロジェクトです。
