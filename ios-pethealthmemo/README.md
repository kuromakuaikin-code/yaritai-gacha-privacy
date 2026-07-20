# ペット健康手帳（PetHealthMemo）iOS版（SwiftUI）

犬・猫などペットのワクチン接種、通院・健診、体重測定、トリミングなどの記録を管理し、体重の推移をグラフで確認できるアプリ。iOS 17+ / SwiftData。

## 機能

- ペット管理（名前・種類・犬種猫種・誕生日・メモ、複数匹登録可）
- 健康記録（種類：ワクチン接種／通院・健診／体重測定／トリミング／その他、日付・内容・体重・病院名・次回予定日・メモ）
- 記録一覧（ペットごとに表示、種類で絞り込み、Swift Charts による体重推移の簡易グラフ）
- 次回予定（全ペット横断でワクチン・通院などの次回予定日を昇順表示、残り日数表示、対応済みにすると予定日をクリア）
- プレミアム／広告なし（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ、無料版はペット\(1\)匹・記録\(30\)件まで）
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（JSON、ペット・記録とも対応）

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-pethealthmemo
xcodegen
open PetHealthMemo.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `PetHealthMemo`（表示名は後で「ペット健康手帳」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-pethealthmemo/PetHealthMemo/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.pethealthmemo.premium`（¥160）
   - `com.kuromakuaikin.pethealthmemo.adfree`（¥120）
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView` を GADBannerView に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/pet-health-memo/privacy.html`
5. プライバシー「栄養表示」: ユーザーデータ収集なし（広告はAdMob SDKの申告に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- 既存の「ご祝儀・香典メモ」（`../ios-shugimemo/`）などとは別アプリ・別Xcodeプロジェクトです。
