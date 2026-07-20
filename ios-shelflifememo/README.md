# 冷蔵庫の賞味期限メモ（ShelfLifeMemo）iOS版（SwiftUI）

冷蔵庫・冷凍庫・常温保存の食品の賞味期限／消費期限を記録し、期限が近い食品をひと目で確認して食品ロスを減らすためのアプリ。iOS 17+ / SwiftData。

## 機能

- 食品管理（名前・保存区分「冷蔵／冷凍／常温」・期限日・数量・保存場所・メモ、名前で検索、区分／保存場所で絞り込み）
- 一覧は期限日が近い順に表示。期限までの日数に応じて色分け（期限切れ・当日〜1日＝赤、3日以内＝オレンジ、7日以内＝黄色）
- 追加・編集画面には「+3日／+1週間／+1ヶ月」のクイック入力ボタン付き
- スワイプ操作で「消費済みにする」「削除」
- 統計（期限切れ件数、今週中に消費すべき件数、区分別の内訳）
- プレミアム／広告なし（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ、無料版は登録\(20\)件まで）
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（JSON）

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-shelflifememo
xcodegen
open ShelfLifeMemo.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `ShelfLifeMemo`（表示名は後で「冷蔵庫の賞味期限メモ」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-shelflifememo/ShelfLifeMemo/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.shelflifememo.premium`（¥160）
   - `com.kuromakuaikin.shelflifememo.adfree`（¥120）
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView` を GADBannerView に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/shelf-life-memo/privacy.html`
5. プライバシー「栄養表示」: ユーザーデータ収集なし（広告はAdMob SDKの申告に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- 既存の「ご祝儀・香典メモ」（`../ios-shugimemo/`）などとは別アプリ・別Xcodeプロジェクトです。
