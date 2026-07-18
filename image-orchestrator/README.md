# Image Orchestrator

クラウド上のComfyUIをバックエンドにして、スマホ・PCのブラウザから画像生成する自分専用フロントエンド。
ビルド不要の単一HTMLファイル(`index.html`)で、GitHub Pagesでそのまま動く。

- 公開URL: https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/image-orchestrator/

## 機能

- **ワークフロー取り込み**: ComfyUIの「Save (API Format)」でエクスポートしたJSONを貼るだけ。プロンプト・シード・ステップ・CFG・サンプラー・解像度・チェックポイント・LoRAを自動検出してフォーム化。検出外の項目も「全ノード詳細編集」から変更可能
- **Dynamic Prompt**: `{a|b|c}` ランダム選択 / `__name__` ワイルドカード / `${x=...}`・`${x}` 変数(選んだ結果を複数箇所で再利用)
- **X/Yプロット**: 任意パラメータ+プロンプトS/R(検索置換)の総当たり比較グリッド
- **ライブプレビュー**: WebSocket経由で生成途中の画像を表示
- **ギャラリー**: 生成画像をメタデータ(プロンプト・シード等)付きで端末内IndexedDBに保存。「この設定を再利用」でシード込み再現
- **設定エクスポート/インポート**: 端末間の引っ越し用JSON

データは全てブラウザ内(localStorage / IndexedDB)に保存。外部送信先はComfyUIエンドポイントのみ。

## バックエンド(ComfyUI)のセットアップ

### RunPodの場合

1. ComfyUI入りのテンプレートでPodを起動(ポート8188をHTTPで公開)
2. ComfyUIをCORS許可付きで起動する:
   ```
   python main.py --listen 0.0.0.0 --port 8188 --enable-cors-header "*"
   ```
   テンプレートによっては起動引数の環境変数に `--enable-cors-header "*"` を追記
3. Podの「Connect」からポート8188のプロキシURL(`https://<pod-id>-8188.proxy.runpod.net`)をコピー
4. アプリの設定タブに貼り付けて「接続テスト」→ 保存

### 注意

- このページはhttpsなので、エンドポイントもhttps必須(RunPodプロキシURLはhttps)
- `--enable-cors-header` がないとブラウザからのアクセスがCORSでブロックされる
- ComfyUIには認証がない。RunPodのプロキシURLは推測困難だが公開状態なので、URLを人に教えない・使い終わったらPodを停止する

## ワークフローJSONの出し方

ComfyUIの設定(歯車)→「Dev mode」を有効化 → メニューに「Save (API Format)」が出るので、それでエクスポートしたJSONを設定タブに貼る。
