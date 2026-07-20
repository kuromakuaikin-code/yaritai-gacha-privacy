# 学び・習い事記録帳（ManabiRecord）iOS版（SwiftUI）

お子さまの習い事・読書・勉強・学校行事をまとめて記録するアプリ。iOS 17+ / SwiftData。

Apple App Store Review Guideline 4.3（スパム・テンプレートアプリの禁止）を踏まえ、
単機能アプリを乱発するとデベロッパアカウント自体が停止されるリスクがあるため、
関連性の高い4つの記録機能を「学び・習い事」という1つのテーマのもとに統合し、
共通のデザイン言語・設定・課金基盤を持つ1本のアプリとして提供する。

## 機能

- 習い事の出席・月謝記録（お子さま名・習い事名・月謝・曜日メモを登録し、出席/欠席の履歴を記録。「今日出席したことを記録」ボタンでワンタップ記録）
- 読書記録（お子さま名・タイトル・著者・読了日・評価（★0〜5）・ページ数・感想メモ。お子さま名で絞り込み、「今年読んだ冊数」を表示）
- 資格・勉強進捗管理（目標名・目標日・目標時間（分）を登録し、勉強ログを積み上げて進捗率と目標日までの残り日数を表示）
- 学校行事・持ち物チェックリスト（運動会・参観日・遠足などの行事を日付順に管理し、行事ごとに自由入力のチェックリストを作成）
- プレミアム／広告なし（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ。1回のプレミアム購入で上記4モジュールすべてが無制限になる。広告非表示のみの単独購入も可能。無料版は各モジュール独立で\(5\)件まで登録可、記録に紐づく出席履歴・勉強ログ・チェック項目などの子データは無制限）
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（4モジュール分をまとめた1つのJSON）

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-manabirecord
xcodegen
open ManabiRecord.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `ManabiRecord`（表示名は後で「学び・習い事記録帳」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-manabirecord/ManabiRecord/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.manabirecord.premium`（¥160）
   - `com.kuromakuaikin.manabirecord.adfree`（¥120）
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView` を GADBannerView に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/manabi-record/privacy.html`
5. プライバシー「栄養表示」: ユーザーデータ収集なし（広告はAdMob SDKの申告に従う）。ただしお子さまの氏名・記録を端末内に保存するため、App Store Connect の「データの取り扱い」フォームでは「収集はしないが、端末内にユーザー入力データを保持する」旨を正確に申告すること
6. アプリアイコン（1024×1024）を用意して Assets に設定

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- 既存の各アプリ（`../ios-shugimemo/` 等）とは別アプリ・別Xcodeプロジェクトです。
- 4モジュール（習い事・読書記録・勉強進捗・行事チェック）はそれぞれ独立したSwiftDataモデルを持つが、
  `AppConfig` / `PurchaseStore` / `Passcode` / `RootTabView` / `SettingsView` / `BackupService` は全モジュール共通の基盤として1つにまとめている。
