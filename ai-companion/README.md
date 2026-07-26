# ai-companion — デスクトップコンパニオン自作計画

BOOTH の「Kawaii Agent V2」相当のものを、自分の手で作ってみるプロジェクト。
脳 (ローカルLLM)・声 (VOICEVOX)・体 (VRM) を「つなぐ係」を書くのが本体。

## ロードマップ

| Phase | 到達点 | 状態 |
|---|---|---|
| 0 | 人格つきの会話がターミナルで返る | ✅ `chat.mjs` |
| 1 | 返事が VOICEVOX の声で再生される | ✅ `chat.mjs` (VOICEVOX 起動時に自動で有効) |
| 2 | 透過ウィンドウに VRM キャラが立つ | 未着手 (Electron + three.js + @pixiv/three-vrm) |
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

## キャラを変える

`character.json` を書き換えるだけ。

- `name` … 表示名
- `systemPrompt` … 人格・口調・一人称など。ここが人格の半分
- `voicevoxSpeaker` … VOICEVOX の話者番号 (3 = ずんだもん ノーマル)。
  番号一覧は VOICEVOX 起動中に http://localhost:50021/speakers で見られる

## 設計メモ

- 脳への接続は OpenAI 互換 API (`localhost:1234/v1/chat/completions`)。
  クラウド (Claude API 等) に切り替えるときは、送り先の URL とキーを変えるだけ
- 会話履歴は直近 20 往復だけ保持。長期記憶は Phase 6 で SQLite に置く予定
- キャラクター (VRM モデル) は同梱しない方針。「あなたの推しを入れる器」にする
