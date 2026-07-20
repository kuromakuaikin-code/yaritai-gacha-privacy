# おうちの数字管理帳（KurashiNumberBook）iOS版（SwiftUI）

家計まわりの「数字」を記録する4つのモジュールを1つにまとめたアプリ。iOS 17+ / SwiftData。

Apple App Store Review Guideline 4.3（スパム・テンプレートアプリの禁止）への対応として、単機能アプリを乱立させるのではなく、関連性の高い家計記録機能をあえて1本のアプリにまとめている。4モジュールは共通のデザイン言語・共通の設定画面／IAPを共有し、1つの製品として体験できるようにしてある。

## 機能

- **光熱費記録**（電気／ガス／水道）：年月ごとの金額・使用量メモ・メモを記録。同種目を2件以上登録するとSwift Charts（`LineMark`/`PointMark`）で推移グラフを表示
- **ポイ活残高管理**：楽天ポイント・dポイント・Tポイント・PayPayポイントなどの残高と有効期限を一覧管理。期限が近い（30日以内）項目を色分け表示し、「残高を更新」でワンタップ上書き
- **記念日・ギフト履歴**：誕生日・結婚記念日・父の日などの「誰に・いつ・前回何を贈ったか」を記録し、次の記念日までの残り日数順に一覧表示（同じ贈り物の繰り返しを防止）
- **更新期限管理**：自動車保険・車検・運転免許証・パスポート・火災保険などの更新期限を残り日数順に色分け表示（7日以内=赤、30日以内=オレンジ）。「更新完了」で次回期限への繰り越しも可能
- プレミアム／広告なし（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ）。無料版は各モジュール独立に5件まで、プレミアム購入で4モジュールすべて無制限に
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（4モジュール全データを1つのJSONファイルに集約）

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-kurashinumbers
xcodegen
open KurashiNumberBook.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `KurashiNumberBook`（表示名は後で「おうちの数字管理帳」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-kurashinumbers/KurashiNumberBook/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.kurashinumbers.premium`（¥160）
   - `com.kuromakuaikin.kurashinumbers.adfree`（¥120）
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView` を GADBannerView に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/kurashi-number-book/privacy.html`
5. プライバシー「栄養表示」: ユーザーデータ収集なし（広告はAdMob SDKの申告に従う）
6. アプリアイコン（1024×1024）を用意してAssetsに設定すること（未作成）

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- 4つのモジュールは意図的に1本のアプリへ統合している（Apple 4.3対応のため、単機能アプリの量産をやめた経緯は本リポジトリ直下のREADMEを参照）。他の既存アプリ（`../ios-shugimemo/` など）とは別アプリ・別Xcodeプロジェクトです。
