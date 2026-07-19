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

接続先は複数登録でき、設定タブ・生成タブのプルダウンでワンタップ切替できる(例: Mac / Windows / RunPod)。

### Mac(Apple Silicon)の場合

M系チップならMPS(Metal)でローカル生成できる。M5・16GBならSDXLクラスまで実用的。

```bash
# Homebrewが未導入なら https://brew.sh の手順でインストール
brew install python@3.12 git
git clone https://github.com/comfyanonymous/ComfyUI
cd ComfyUI
python3.12 -m venv venv
source venv/bin/activate
pip install torch torchvision torchaudio
pip install -r requirements.txt
python main.py --enable-cors-header "*"
```

- モデル(checkpoint)は `ComfyUI/models/checkpoints/` に置く
- アプリの接続先には `http://127.0.0.1:8188` を登録
- **ブラウザはChrome推奨**: httpsページ(GitHub Pages)からlocalhostのhttpへの接続はChrome系では許可されるが、Safariではブロックされることがある
- 2回目以降の起動は `cd ComfyUI && source venv/bin/activate && python main.py --enable-cors-header "*"`

### Windows(NVIDIA GPU)の場合

[ComfyUI公式のポータブル版](https://github.com/comfyanonymous/ComfyUI/releases)(Windows用zip)を展開し、`run_nvidia_gpu.bat` の起動引数に `--enable-cors-header "*"` を追記して起動。接続先はそのマシン上のブラウザから `http://127.0.0.1:8188`。

GPUがないWindows機の場合はローカル生成は現実的でないので、RunPod等のクラウドを使う。

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

- このページはhttpsなので、エンドポイントはhttpsか、localhost宛のhttp(`http://127.0.0.1:8188`)のみ接続可能。LAN上の別マシン(例: スマホ→MacのIP)へのhttp接続は混在コンテンツとしてブロックされる。別端末から使いたい場合はTailscale等のhttps化か、クラウドを使う
- `--enable-cors-header` がないとブラウザからのアクセスがCORSでブロックされる
- ComfyUIには認証がない。RunPodのプロキシURLは推測困難だが公開状態なので、URLを人に教えない・使い終わったらPodを停止する

## ワークフローJSONの出し方

ComfyUIの設定(歯車)→「Dev mode」を有効化 → メニューに「Save (API Format)」が出るので、それでエクスポートしたJSONを設定タブに貼る。
