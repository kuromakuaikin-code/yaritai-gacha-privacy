# 防災グッズチェックリスト（BousaiCheck）iOS版（SwiftUI）

家庭の防災グッズ（非常食・飲料水・衛生用品・情報収集グッズ・貴重品・子供や高齢者・ペット用品など）の準備状況をチェックリストで管理し、家族の緊急連絡先・避難時の集合場所をカード形式で記録できるアプリ。iOS 17+ / SwiftData。

## 機能

- チェックリスト（カテゴリー別にグループ表示、準備状況をチェック、上部に「準備できているもの N / M」の進捗バー）
- 初回起動時に約20件の標準防災グッズ項目を自動投入（食料・水・衛生用品・情報収集・貴重品・子供や高齢者やペット用品・その他）
- 消費期限・使用期限の管理（非常食・飲料水などのローリングストック向け、期限切れ／期限間近を警告表示）
- カスタム項目の追加（品目名・カテゴリー・期限・メモ）、標準項目は削除不可（チェック・編集は可能）、カスタム項目はスワイプで削除可能
- 家族の連絡先カード（氏名・続柄・電話番号・集合場所・メモ、追加/編集/削除）
- プレミアム／広告なし（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ、無料版はカスタム項目\(5\)件まで。標準項目は無料版でも無制限）
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（JSON、チェックリストと連絡先の両方を含む）

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-bousaicheck
xcodegen
open BousaiCheck.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `BousaiCheck`（表示名は後で「防災グッズチェックリスト」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-bousaicheck/BousaiCheck/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.bousaicheck.premium`（¥160）
   - `com.kuromakuaikin.bousaicheck.adfree`（¥120）
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView` を GADBannerView に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/bousai-check/privacy.html`
5. プライバシー「栄養表示」: ユーザーデータ収集なし（広告はAdMob SDKの申告に従う）
6. 標準チェックリスト（`Models.swift` の `PresetChecklistData`）はあくまで一般的な目安。世帯構成・地域のハザードにより過不足があるため、リリース前に内容を見直すこと

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- 既存の「ご祝儀・香典メモ」（`../ios-shugimemo/`）などとは別アプリ・別Xcodeプロジェクトです。
