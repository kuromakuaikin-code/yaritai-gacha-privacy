# 今日の許可

自分に「今日はこれをやっていい」と許可を出す習慣を育てるアプリ（iOS専用）。

## 構成

- `lib/models/permission.dart` — データモデル（Firestore の `Timestamp` で保存、欠損フィールドに強い）
- `lib/services/permission_repository.dart` — Firestore 保存機能（`users/{uid}/permissions` に匿名認証の uid で分離）
- `lib/screens/` — ホーム（許可追加・チェック）／ふりかえり（★1〜5＋メモ）／履歴（カレンダー表示）
- `firestore.rules` — 本人のみ読み書き可のセキュリティルール

## セットアップ手順（iOS）

1. このディレクトリで `flutter create --platforms=ios .` を実行して iOS プロジェクトを生成
2. `flutter pub get`
3. Firebase コンソールでプロジェクトを作成し、iOS アプリを追加
   - `GoogleService-Info.plist` をダウンロードして `ios/Runner/` に配置（Xcode で Runner ターゲットに追加）
   - Authentication で「匿名」を有効化
   - Firestore を作成し、`firestore.rules` の内容をルールに設定
4. `flutter run`

## 実装済み

- Firebase 保存機能（匿名認証＋Cloud Firestore、リアルタイム反映）
- ホーム画面（許可追加・チェック・スワイプ削除）
- ふりかえり画面（許してよかった度★＋ひとことメモ）
- 履歴画面（table_calendar による月表示・日別リスト）

## これから

- プレミアム課金（StoreKit 2 / in_app_purchase。商品IDが決まったら実装）
- 通知機能（ローカル通知ならプライバシーポリシーの変更は不要）

## 公開ページ

- プライバシーポリシー: https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/today-permission/privacy.html
- 利用規約: https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/today-permission/terms.html
