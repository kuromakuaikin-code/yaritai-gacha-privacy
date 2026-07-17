# 現報（Genpou）— 工事現場向け 日報・完了報告 PDF アプリ

工事現場の写真を案件ごとに整理し、日報 PDF / 完了報告 PDF を iPhone 内で生成・共有する SwiftUI アプリ。
サーバーレス MVP（iOS 17+ / SwiftData / PDFKit / StoreKit 2）。

「5分で完了報告」— LINE に散らばる写真を、案件単位の正式 PDF に。

## 構成

| ファイル | 内容 |
|---|---|
| `Genpou/Models.swift` | SwiftData モデル（CompanyProfile / Project / SitePhoto）と PhotoTag |
| `Genpou/MediaStore.swift` | 写真・ロゴのディスク保存（原画 2048px / サムネ 400px JPEG） |
| `Genpou/SubscriptionManager.swift` | StoreKit 2・14 日トライアル（UserDefaults）・課金状態 |
| `Genpou/GenpouApp.swift` | エントリポイント + RootView（タブ / オンボーディング分岐） |
| `Genpou/OnboardingView.swift` | 初回オンボーディング（紹介 3 ページ + 会社情報フォーム） |
| `Genpou/ProjectListView.swift` | 案件一覧（検索・スワイプ削除） |
| `Genpou/ProjectEditorView.swift` | 案件の新規・編集フォーム |
| `Genpou/ProjectDetailView.swift` | 案件詳細（タグフィルタ + 3 列グリッド + 下部アクション） |
| `Genpou/PhotoDetailSheet.swift` | 写真の拡大・タグ変更・キャプション・削除 |
| `Genpou/PhotoAddView.swift` | 写真追加（カメラ / アルバム複数選択、課金ゲート） |
| `Genpou/CameraCaptureView.swift` | AVFoundation 連続撮影カメラ |
| `Genpou/PDFReportService.swift` | 日報・完了報告 PDF 生成（A4 縦、オフライン） |
| `Genpou/ReportBuilderView.swift` | 写真選択 → PDF 作成 |
| `Genpou/PDFPreviewView.swift` | PDF プレビュー + 共有シート |
| `Genpou/PaywallView.swift` | 課金画面（購入・復元） |
| `Genpou/SettingsView.swift` | 設定（会社情報・プラン・規約・デバッグ用トライアル操作） |
| `Genpou.storekit` | ローカルテスト用 StoreKit Configuration |

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd genpou
xcodegen
open Genpou.xcodeproj
```

スキームに StoreKit Configuration（`Genpou.storekit`）が設定済み。シミュレータでそのまま購入テストできる。

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `Genpou`（表示名は後で「現報」に）
   - Interface: SwiftUI / Storage: **None**（SwiftData はコード側で設定済み）
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `genpou/Genpou/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. Info 設定に以下を追加
   - `NSCameraUsageDescription`: 施工状況を記録するためカメラを使用します。
   - `NSPhotoLibraryUsageDescription`: 報告書用の写真を選択するため写真ライブラリを使用します。
5. `Genpou.storekit` をプロジェクトに追加し、Scheme → Run → Options → StoreKit Configuration に設定
6. ビルド（⌘R）

## 課金まわり

- 商品 ID: `genpou.personal.monthly`（自動更新サブスク・月額・初回 14 日無料）
- **価格はコードに埋め込んでいない**。表示は `Product.displayPrice`（StoreKit から取得）なので、
  App Store Connect / `.storekit` ファイルの価格を変えるだけで反映される。`Genpou.storekit` の ¥1,480 は仮値。
- トライアル開始日は UserDefaults（`trialStartDate`）。期限切れ（expired）は
  **写真追加と PDF 生成のみブロック**し、既存データの閲覧・会社情報編集は可能。
- 設定 → デバッグ（DEBUG ビルドのみ）でトライアルの期限切れ / リセットを切り替えて受け入れ確認できる。

## リリース前チェックリスト

1. Bundle ID を正式なものに変更（現在は仮の `com.example.genpou`）
2. App Store Connect でサブスク作成
   - 商品 ID `genpou.personal.monthly` / サブスクグループ / 価格 / 14 日無料の Introductory Offer
   - 掲載文・審査メモ・スクショ構成は `store-listing.md` にコピペ用を用意済み
3. 規約・プライバシーポリシーは設定済み（`terms.html` / `privacy.html`、main へのマージ後に
   GitHub Pages で公開される。アプリ内リンク・store-listing.md の URL は設定済み）
4. Sandbox テスターで購入・復元を確認
5. アプリアイコンを Assets に設定

## 受け入れ確認（仕様 10 章）

- [ ] 屋号登録後、案件作成 → カメラで 3 枚保存
- [ ] タグ変更が PDF に反映される
- [ ] 日報・完了報告 PDF を共有シートで送れる
- [ ] 機内モードで PDF 生成できる
- [ ] トライアル期限切れで撮影ブロック + Paywall（設定 → デバッグで日付ずらし可）
- [ ] Sandbox で購入・復元

## 備考

- このコードは Linux 環境で作成したため **Xcode でのビルド未確認**です。
  ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- `Genpou.storekit` は Xcode のバージョンによりフォーマット差異で開けない場合があります。
  その場合は Xcode の File → New → File → StoreKit Configuration File で作り直し、
  同じ商品 ID・サブスク期間・Introductory Offer を設定してください。
