# 3D素材サムネ台帳 (AssetLedger) — プロトタイプ v0.1

TRELLIS2/ComfyUI等で生成した3Dモデル(GLB/usdz)や画像が出力フォルダに散らかる問題を解決する、Mac用の素材ビューア。指定フォルダを監視し、新規ファイルを自動でサムネイル化して一覧表示する。完全ローカル・外部通信なし。

仕様書: 「3D素材サムネ台帳 仕様書 v0.1」

## 動作環境

- macOS 14 (Sonoma) 以降
- Xcode 15 以降（またはSwift 5.9ツールチェーン）

## ビルド・実行方法

### Xcodeで実行（推奨）

1. `asset-ledger/Package.swift` をXcodeで開く（ダブルクリック）
2. スキーム `AssetLedger`、実行先 `My Mac` を選択して Run（⌘R）

### CLIで実行

```sh
cd asset-ledger
swift run
```

初回起動後、設定（⌘,）から監視フォルダを追加してください。

## 実装状況（仕様書との対応）

| 項目 | 状況 |
|---|---|
| フォルダ監視（DispatchSource + 5秒間隔の再スキャン） | ✅ 実装済み |
| 画像(png/jpg/webp/heic等)サムネ生成（ImageIOダウンサンプリング） | ✅ 実装済み |
| usdzサムネ生成（SceneKit + SCNRendererオフスクリーンレンダリング） | ✅ 実装済み |
| GLBサムネ生成 | ⚠️ ModelIO経由の試行のみ（下記「GLB技術検証」参照） |
| サムネグリッド（新しい順・フォルダ横断） | ✅ 実装済み |
| フィルタ（種別/タグ/お気に入り/フォルダ） | ✅ 実装済み |
| NEWバッジ（未閲覧管理） | ✅ 実装済み |
| プレビューペイン（3Dドラッグ回転 / 画像拡大） | ✅ 実装済み |
| ダブルクリックでFinder表示・右クリックで既定アプリ | ✅ 実装済み |
| 元ファイル消失バッジ（参照のみ・コピーしない） | ✅ 実装済み |
| タグ・お気に入り・メモ | ✅ 実装済み |
| 設定（フォルダ追加削除・サムネ解像度256/512） | ✅ 実装済み |
| メニューバー常駐（未閲覧バッジ・直近5件ポップオーバー） | ✅ 実装済み |
| 永続化（JSON: `~/Library/Application Support/AssetLedger/`） | ✅ 実装済み |

## GLB技術検証（スパイク）の結論

仕様書の指示どおりGLBが最大の技術リスク。調査結果:

- **SceneKit / ModelIO は GLB/glTF を公式サポートしていない**（Appleの取り込み対応はUSD系・OBJ・STL等のみ）
- 実装では `MDLAsset.canImportFileExtension("glb")` を実行時にチェックし、読めた場合のみ `MDLAsset → SCNScene` 変換でレンダリングする「試行」パスを残した
- 読めない環境（＝ほぼすべてのmacOS）では **「GLB」ラベル入りプレースホルダサムネ**を生成し、プレビューには「GLBの3Dプレビューは未対応です（v0.2予定）」と表示する

**→ 仕様書の切り下げ条項どおり、v0.1は「usdz + 画像を本対応、GLBは台帳管理のみ（サムネはプレースホルダ）」とした。**

v0.2でのGLB本対応の推奨ルート: [GLTFKit2](https://github.com/warrenm/GLTFKit2)（SPMパッケージ）を依存に追加し、`GLTFSCNSceneSource` で SCNScene に変換 → 既存のレンダリングパイプラインへ接続。`ThumbnailGenerator.loadScene(url:type:)` の `.glb` 分岐を差し替えるだけで済む構造にしてある。

## アーキテクチャ

```
Sources/AssetLedger/
├── AssetLedgerApp.swift      # エントリポイント（WindowGroup / Settings / MenuBarExtra）
├── Models.swift              # WatchFolder / Asset / 永続化データ / パス定義
├── LibraryStore.swift        # 中核: 状態・永続化・スキャン・監視統括（ObservableObject）
├── FolderWatcher.swift       # DispatchSourceによるフォルダ監視
├── ThumbnailGenerator.swift  # 画像=ImageIO / 3D=SceneKitオフスクリーンレンダリング
└── Views/
    ├── ContentView.swift     # メイン画面（フィルタバー + グリッド + 右ペイン）
    ├── AssetGridView.swift   # サムネグリッド（NEW/消失/お気に入りバッジ）
    ├── PreviewPane.swift     # プレビュー（SceneViewで回転 / 画像ズーム）+ タグ・メモ
    ├── SettingsView.swift    # 監視フォルダ管理・サムネ解像度
    ├── MenuBarView.swift     # メニューバーポップオーバー（直近5件）
    └── ThumbnailImageView.swift # サムネ読み込み（NSCacheつき）
```

設計メモ:

- 元ファイルは**参照のみ**（filePath保持）。サムネJPEGだけをアプリ管理領域に保存
- サムネはJPEG品質0.8・最大辺256px（既定）→ 1枚あたり概ね10〜40KB。1GB分の素材（数百ファイル想定）でも数MB〜十数MB程度で成功基準4（50MB以下）を満たす見込み
- DispatchSourceはフォルダ直下のイベントのみ拾うため、サブフォルダ対応として5秒間隔の軽量再スキャン（パス集合の差分比較）を併用。成功基準2（10秒以内に出現）はこの二重化で満たす
- スキャン・サムネ生成は単一の直列キューで実行し、競合状態を避ける
- セキュリティスコープ付きブックマークは保存・解決とも実装済み（swift run等の非サンドボックス実行では単に不要になるだけ）

## 成功基準の検証手順（Mac上で実施）

> ⚠️ このプロトタイプはLinux CI環境で開発したため、**macOSでのビルド・実行検証は未実施**。以下のチェックリストをMac上で実施し、スクリーンショット/ログを添えて完了判定すること（仕様書の完了報告要件）。

1. **起動時一覧化**: フォルダを2つ登録 → 既存の画像/usdzがグリッドに出ることを確認（スクリーンショット）
2. **10秒以内のNEW検出**: 監視中にFinderで画像をコピー → 10秒以内にNEWバッジ付きで出現（`date; cp test.png ~/watched/` とアプリ画面の動画/連続スクショ）
3. **3Dサムネと回転**: usdzを置いてサムネ生成を確認 → 選択してプレビューをドラッグ回転（スクリーンショット）
4. **サムネ容量**: 元ファイル1GB分を投入後 `du -sh ~/Library/Application\ Support/AssetLedger/` が50MB以下
5. **再起動後の保持**: タグ・お気に入り・フォルダ設定を付けて再起動 → 保持されていること
6. **1時間常駐**: 1時間放置してクラッシュしないこと（`log show --predicate 'process == "AssetLedger"' --last 1h` で確認）

うまく動かない場合（テストループは5回まで、3回失敗したら一時停止して報告）:

- usdzサムネが真っ暗 → `ThumbnailGenerator.renderScene` のライト強度/カメラ距離(`r * 2.8`)を調整
- NEWが10秒超え → 再スキャン間隔（`LibraryStore.init`の`withTimeInterval: 5`）を短縮

## v0.2以降（プロトタイプに含めない）

- GLB本対応（GLTFKit2導入）
- 動画(mp4)サムネ
- ComfyUIワークフローメタデータ(PNG埋込)の読み取り表示
- 重複ファイル検出
- 配布用の署名・公証・Xcodeプロジェクト化（App Sandbox有効化。ブックマーク処理は実装済み）
