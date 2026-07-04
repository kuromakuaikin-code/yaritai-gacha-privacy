# 婚活デートメモ iOS版（SwiftUI）

Web版（`../date-memo/`）と同じ機能構成のネイティブiOSアプリ。iOS 17+ / SwiftData。

## 機能

- お相手管理（検索・ステータス絞り込み・並び替え4種・無料3人制限）
- デート記録（★評価・次回予定日・振り返り）
- 話題リスト（4カテゴリ30話題＋会話フロー120フレーズ、お相手ごとの話したチェック）
- MYメモ（自由編集・並び替え・スワイプ削除）
- デート前カンペ・話題ガチャ
- プレミアム／広告なし（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ）
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（**Web版のJSONと相互互換**）

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios
xcodegen
open KonkatsuDateMemo.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `KonkatsuDateMemo`（表示名は後で「婚活デートメモ」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios/KonkatsuDateMemo/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは `../date-memo/icon-512.png` を Assets の AppIcon に設定。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.datememo.premium`（¥160）
   - `com.kuromakuaikin.datememo.adfree`（¥120）
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView` を GADBannerView に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/date-memo/privacy.html`
5. プライバシー「栄養表示」: ユーザーデータ収集なし（広告はAdMob SDKの申告に従う）

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- データ移行: Web版の設定→「バックアップを書き出す」で保存したJSONを、
  iOS版の設定→「バックアップを読み込む」でそのまま取り込めます。
