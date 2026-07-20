# おでかけ思い出手帳（OdekakeMemories）iOS版（SwiftUI）

家族のおでかけ先を「公園・遊び場」「花見・紅葉スポット」「キャンプ・BBQ場」「観光・お城スタンプ帳」の4カテゴリで記録できるアプリ。iOS 17+ / SwiftData。

## 機能

- 4モジュール構成のタブ（公園・遊び場／花見・紅葉／キャンプ・BBQ／観光スタンプ）。各タブは記録一覧・検索・追加・編集・スワイプ削除に対応
  - 公園・遊び場：場所名・訪問日・評価・設備メモ（滑り台／砂場／トイレなど）・メモ
  - 花見・紅葉スポット：場所名・種類（桜／紅葉／その他）・訪問日・評価・見頃メモ・メモ
  - キャンプ・BBQ場：場所名・種類（キャンプ場／BBQ場／その他）・訪問日・評価・設備メモ・メモ
  - 観光・お城スタンプ帳：場所名・種類（城／観光地／博物館・美術館／その他）・訪問日・評価・カテゴリメモ・メモ
- **設計上の工夫**：4カテゴリは「場所名・訪問日・評価・メモ」という基本構造が共通しているため、4つの似たようなSwiftDataモデルに分割せず、単一の `OutingVisit` モデルを `module`（カテゴリ）で絞り込んで使い回す設計にしている（`Models.swift` の `OutingModule` enum が各タブのラベル・ピッカー選択肢・プレースホルダーを切り替える）。タブごとのビューも `ModuleListView` / `AddEditVisitView` という共通ビューをパラメータ化して再利用しており、4タブがバラバラの実装にならないようにしている
- プレミアム／広告なし（テスト期間は無料解放、StoreKit 2実装済みでフラグ切替のみ、無料版は**4カテゴリ合計**で記録\(15\)件まで）
- パスコードロック（SHA-256）、バックアップ書き出し/読み込み（JSON、4カテゴリ全記録をまとめて対象）

### なぜ4つの記録機能を1本のアプリにまとめているか

Apple App Store Review Guideline 4.3（Spam）は、同一開発者アカウントからほぼ同じ構造・体裁の「テンプレート的」な単機能アプリを大量に提出することを問題視しており、該当すると判断された場合はそのアプリだけでなく**開発者アカウント自体が停止**されるリスクがある（既に公開済みの他アプリも道連れになりうる）。そのため本アプリでは、単機能アプリを4本個別に出すのではなく、関連性の高い記録管理機能（おでかけ記録）を1つの首尾一貫したアプリにまとめて提出する方針としている。共通の設定・IAP・デザイン言語（コーラルオレンジ #E0673C のアクセントカラー）を4モジュールで共有し、「4アプリを1つに貼り合わせた」のではなく「1つのアプリの中に4つの記録帳がある」体験になるようにしている。

### 既存の「御朱印帳ログ」（ios-goshuinlog）との違い

本アプリは神社・お寺の御朱印参拝記録には対応しない。あくまで公園遊び・お花見/紅葉狩り・キャンプ/BBQ・一般的な観光（お城・観光地・博物館等）という「一般的なおでかけ・レジャー」を対象としたスコープであり、`ios-goshuinlog`（神社・お寺での御朱印参拝ログに特化）とはテーマ・データモデルとも明確に異なる別アプリとして設計している。

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-odekakememories
xcodegen
open OdekakeMemories.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `OdekakeMemories`（表示名は後で「おでかけ思い出手帳」に）
   - Interface: SwiftUI / Storage: **None**（SwiftDataはコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-odekakememories/OdekakeMemories/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - `com.kuromakuaikin.odekakememories.premium`（¥160）
   - `com.kuromakuaikin.odekakememories.adfree`（¥120）＋「購入の復元」
3. AdMob: Google-Mobile-Ads-SDK を SPM で追加し、`AdBannerView`（`OdekakeMemoriesApp.swift`）を GADBannerView の UIViewRepresentable に置き換え
   - ATT対応（`NSUserTrackingUsageDescription`）または非パーソナライズ配信
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/odekake-memories/privacy.html`
5. プライバシー「栄養表示」：データ収集なし（広告関連は AdMob SDK の申告に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定

## 備考

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- 既存の「御朱印帳ログ」（`../ios-goshuinlog/`）とは別アプリ・別Xcodeプロジェクトです（神社・お寺の御朱印参拝記録と、一般的なおでかけ・レジャー記録という異なるスコープ）。
