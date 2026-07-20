# 年賀状・贈り物管理（NengaMemo）iOS版（SwiftUI）

年賀状、お中元・お歳暮などの季節の贈り物について「誰に・いつ・送ったか／もらったか」を記録し、送り忘れや重複を防ぐアプリ。iOS 17+ / SwiftData。

## 機能

- 宛先管理（氏名・ご住所・続柄／関係・メモを登録、名前・続柄・住所で検索、スワイプで削除）
- 宛先ごとの贈答履歴（年賀状・お中元・お歳暮の「送った／もらった」を年別に一覧表示）
- 今年の記録（対象年を選び、宛先ごとに年賀状・お中元・お歳暮の送付／受領チェックをその場で記録。上部に送付済み件数のサマリー表示）
- プレミアム／広告なし（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ、無料版は宛先\(30\)件まで）
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（JSON、宛先と贈答記録をまとめて保存）

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-nengamemo
xcodegen
open NengaMemo.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `NengaMemo`（表示名は後で「年賀状・贈り物管理」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-nengamemo/NengaMemo/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.nengamemo.premium`（¥160）
   - `com.kuromakuaikin.nengamemo.adfree`（¥120）
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView` を GADBannerView に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/nenga-memo/privacy.html`
5. プライバシー「栄養表示」: ユーザーデータ収集なし（広告はAdMob SDKの申告に従う）
   - 注：本アプリは宛先（第三者）の氏名・住所を端末内に保存するが、外部送信は行わない
6. アプリアイコン（1024×1024）を用意して Assets に設定

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- 既存の「婚活デートメモ」（`../ios/`）「ご祝儀・香典メモ」（`../ios-shugimemo/`）とは別アプリ・別Xcodeプロジェクトです。
