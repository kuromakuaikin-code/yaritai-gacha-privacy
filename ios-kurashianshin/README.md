# 暮らしの安心手帳（KurashiAnshinBook）iOS版（SwiftUI）

家の中の「うっかり忘れ」を防ぐための記録アプリ。家電の保証期限・住まいの定期メンテナンス・観葉植物の水やり・日用品の在庫という4つの家事記録機能を1つのアプリにまとめている。iOS 17+ / SwiftData。

### なぜ4機能を1本にまとめているか

Apple App Store Review Guideline 4.3は、同一開発者アカウントから似た構成の「テンプレート量産アプリ」を大量に提出することを禁じており、違反と判断されると新規アプリだけでなく既存の公開済みアプリを含むアカウント全体が停止するリスクがある。そのため本アプリでは、単機能アプリを乱発するのではなく、関連性のある家事記録機能をひとつの筋の通ったアプリ体験（共通のデザイン・共通の設定画面・共通のIAP）としてまとめている。

なお、本アプリは既存の「防災グッズチェックリスト」（`ios-bousaicheck/`）とはスコープが異なる別アプリである。防災グッズチェックリストは災害への備え（非常持ち出し品・緊急連絡先）を扱うのに対し、本アプリは平常時の暮らしの維持・管理（家電保証・住宅メンテナンス・植物・日用品在庫）を扱う。

## 機能

- **家電保証**：家電（名前・購入日・購入店・保証年数・購入金額・メモ）を登録し、保証期限が近い順に一覧表示。期限切れ・30日以内は赤、90日以内は橙で警告表示
- **メンテナンス**：住まいの定期メンテナンス項目（名前・前回実施日・周期月数・メモ）を管理。初回起動時にエアコンフィルター掃除・換気扇掃除・火災報知器の電池交換など標準項目を自動投入（削除・編集可）。「完了」ボタンで前回実施日を今日に更新し、次回目安日を自動再計算
- **植物**：観葉植物の水やり管理（名前・品種・前回水やり日・周期日数・メモ）。「水やりした」ボタンでワンタップ記録、水やり忘れは赤で表示
- **在庫管理**：トイレットペーパー・洗剤・ゴミ袋などの日用品在庫を管理。＋／−ボタンでその場で在庫数を増減、閾値以下は「そろそろ買い足し」バッジを表示
- **プレミアム／広告なし**（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ）：無料版は各モジュール独立で5件まで（メンテナンスの標準項目はカウント対象外）。プレミアム購入で4モジュールすべて無制限＋広告非表示に
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（4モジュール全データを1つのJSONファイルに集約）

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-kurashianshin
xcodegen
open KurashiAnshinBook.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `KurashiAnshinBook`（表示名は後で「暮らしの安心手帳」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-kurashianshin/KurashiAnshinBook/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.kurashianshin.premium`（¥160）
   - `com.kuromakuaikin.kurashianshin.adfree`（¥120）
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView` を GADBannerView に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/kurashi-anshin-book/privacy.html`
5. プライバシー「栄養表示」: ユーザーデータ収集なし（広告はAdMob SDKの申告に従う）
6. 標準メンテナンス項目（`Models.swift` の `PresetMaintenanceData`）はあくまで一般的な目安。住宅の設備構成・築年数により過不足があるため、リリース前に最新情報で見直すこと
7. アプリアイコン（1024×1024）を用意して Assets に設定

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- 既存の「防災グッズチェックリスト」（`../ios-bousaicheck/`）とは別アプリ・別Xcodeプロジェクトです（スコープの違いは本READMEの冒頭を参照）。
