# ゴミ出しカレンダー（GomiCalendar）iOS版（SwiftUI）

家庭ごとに異なるゴミ・資源の収集ルール（曜日・頻度）を登録しておき、今日・明日・今後1週間で何を出せばよいかをひと目で確認できるアプリ。iOS 17+ / SwiftData。

## 機能

- 今日・今週（当日出せるカテゴリをカード表示、「明日は？」の簡易表示、今後7日間の一覧を色分けチップで表示）
- ルール設定（カテゴリ名・色・対象曜日（複数選択可）・頻度（毎週／隔週／第1・3／第2・4）・メモを登録、一覧はカラーチップと曜日要約付き、スワイプで削除）
- プレミアム／広告なし（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ、無料版はルール\(3\)件まで）
- リマインダー通知（プレミアム限定。時刻を指定すると、当日該当するカテゴリを知らせるローカル通知を登録。ベストエフォート実装で、内容はアプリ起動・設定変更のたびに当日分へ更新）
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（JSON）

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-gomicalendar
xcodegen
open GomiCalendar.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `GomiCalendar`（表示名は後で「ゴミ出しカレンダー」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-gomicalendar/GomiCalendar/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.gomicalendar.premium`（¥160）
   - `com.kuromakuaikin.gomicalendar.adfree`（¥120）
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView` を GADBannerView に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. リマインダー通知（`SettingsViews.swift` の `NotificationService`）：初回有効化時に `UNUserNotificationCenter` の通知許可ダイアログが出ます。Xcodeプロジェクトの Signing & Capabilities で Push は不要（ローカル通知のみ）ですが、通知文言や許可導線は必要に応じて Info.plist・UI 側で調整してください。現状は簡易実装（内容はアプリ起動・設定変更のたびに当日分へ更新）です。
5. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/gomi-calendar/privacy.html`
6. プライバシー「栄養表示」: ユーザーデータ収集なし（広告はAdMob SDKの申告に従う）
7. アプリアイコン（1024×1024）を用意して Assets に設定

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- 「隔週」「第1・3」「第2・4」の判定は `Calendar` の週番号・月内週番号による簡易ロジックです。自治体の実際の起算日とずれる場合があるため、あくまで目安としてご利用ください。
