# ai-companion — デスクトップコンパニオン自作計画

BOOTH の「Kawaii Agent V2」相当のものを、自分の手で作ってみるプロジェクト。
脳 (ローカルLLM)・声 (VOICEVOX)・体 (VRM) を「つなぐ係」を書くのが本体。

## ロードマップ

| Phase | 到達点 | 状態 |
|---|---|---|
| 0 | 人格つきの会話がターミナルで返る | ✅ `chat.mjs` |
| 1 | 返事が VOICEVOX の声で再生される | ✅ `chat.mjs` (VOICEVOX 起動時に自動で有効) |
| 2 | 透過ウィンドウに VRM キャラが立つ | ✅ `app/` (Electron + three.js + @pixiv/three-vrm) |
| 3 | 表情が会話に連動する | 未着手 |
| 4 | 口が動く (音量ベースのリップシンク) | 未着手 |
| 5 | 音声入力 (Whisper) | 未着手 |
| 6 | 記憶と親密度 (SQLite) | 未着手 |

## 動かし方 (自分の PC で)

必要なもの:

- Node.js 18 以上
- LM Studio (https://lmstudio.ai) + モデル (Gemma 4 など)
- VOICEVOX (https://voicevox.hiroshiba.jp) … 任意。あると声が出る

手順:

1. LM Studio を起動し、モデルをロード → Developer タブで **Start Server**
2. (声が欲しければ) VOICEVOX を起動しておく
3. このフォルダで:

   ```
   node chat.mjs
   ```

依存パッケージのインストールは不要 (`npm install` なし)。

## デスクトップに立たせる (Phase 2 / `app/`)

ターミナルではなく、デスクトップの上にキャラを立たせる版です。
背景が透過した枠なしウィンドウに VRM が立ち、話しかけると吹き出しと声で返します。

### 動かし方 (Windows / Mac 共通)

```
git pull
cd ai-companion/app
npm install
npm start
```

`npm install` は初回だけ。Electron 本体 (約 100〜200MB) を取りに行くので少し待ちます。
LM Studio と VOICEVOX の準備は `chat.mjs` と同じで、無くても起動はします
(LM Studio が無いときは、吹き出しに起動手順が出ます)。

### VRM モデルの入れ方

**モデルは同梱していません。**「あなたの推しを入れる器」なので、自分で用意した
`.vrm` ファイルを入れてください。

- 初回起動でパネルが出ます。**ファイルをドラッグ＆ドロップ**するか、
  「VRM ファイルを選ぶ」から選びます
- 選んだ場所は記憶され、次回の起動から自動で読み込まれます
- 別のモデルに変えるときは、キャラを**右クリック → 「別の VRM に変える」**
- VRM 0.x / 1.0 のどちらでも読めます

### 操作

| したいこと | 操作 |
|---|---|
| 話しかける | 下の入力欄に打って Enter |
| 入力欄を出す/しまう | キャラを**クリック** |
| メニュー (モデル変更・しまう・終了) | キャラを**右クリック** |
| 移動する | キャラを**ドラッグ** |
| 吹き出しやメニューを閉じる | Esc |

キャラと UI 以外の場所はクリックが下のウィンドウに素通りするので、
デスクトップの上に置いたままふつうに作業できます。

### 中身

| ファイル | 役割 |
|---|---|
| `app/main.js` | ウィンドウ作成、クリック透過、LM Studio / VOICEVOX との通信 |
| `app/preload.js` | 画面と Electron 本体をつなぐ窓口 |
| `app/renderer/stage.mjs` | three.js シーン、VRM 読み込み、まばたき・呼吸、当たり判定 |
| `app/renderer/talk.mjs` | 吹き出しと会話、声の再生 |
| `app/renderer/main.mjs` | 透過の切り替え、ドラッグ移動、UI の取りまとめ |

ビルドツール (vite 等) は使っていません。素の HTML + ES modules と importmap だけです。
画面を出さずにできる範囲の自己点検は `npm run check` で走ります。

## キャラを変える

`character.json` を書き換えるだけ (`chat.mjs` と `app/` の両方が同じファイルを読みます)。

- `name` … 表示名
- `systemPrompt` … 人格・口調・一人称など。ここが人格の半分
- `voicevoxSpeaker` … VOICEVOX の話者番号 (3 = ずんだもん ノーマル)。
  番号一覧は VOICEVOX 起動中に http://localhost:50021/speakers で見られる

## 設計メモ

- 脳への接続は OpenAI 互換 API (`localhost:1234/v1/chat/completions`)。
  クラウド (Claude API 等) に切り替えるときは、送り先の URL とキーを変えるだけ
- 会話履歴は直近 20 往復だけ保持。長期記憶は Phase 6 で SQLite に置く予定
- キャラクター (VRM モデル) は同梱しない方針。「あなたの推しを入れる器」にする

### Phase 2 で決めたこと

- **クリック透過**は 2 段構え。
  `setIgnoreMouseEvents(true, { forward: true })` で下のウィンドウへ素通りさせつつ、
  マウスの移動だけは受け取る。その座標を毎フレーム見て、
  ①UI 部品の上か (`elementFromPoint`) ②キャラの上か (画面上の矩形でふるい分け → レイキャスト)
  を判定し、当たっていれば透過を解除する。
  ピクセルの透明度を読む方式より軽く、髪の隙間などキャラの形どおりに抜ける。
  当たらなくなってから 150ms の猶予を置いているのは、輪郭で判定が高速に
  入れ替わってクリックを取りこぼすのを防ぐため
- **ウィンドウ移動**に CSS の `-webkit-app-region: drag` は使わない。
  あれは矩形単位でしか指定できず「キャラの形だけ掴む」ができないため、
  掴んだ瞬間のカーソル位置を覚えて main 側で追従させている
- **キャラの向き**は左右の上腕の位置から計算する。
  VRM 0.x / 1.0 で正面の基準が違うが、この方法なら必ず顔がこちらを向く
- **通信は main プロセスが代行**する。画面側から直接 LM Studio を叩くと
  CORS で弾かれるため。VOICEVOX の音声も main が取ってきて画面側で鳴らす
- ビルドツールは入れない。importmap で `node_modules` を直接 import している
