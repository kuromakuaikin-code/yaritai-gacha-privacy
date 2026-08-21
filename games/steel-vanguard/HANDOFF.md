# 引き継ぎ書: STEEL VANGUARD (PC 環境の Claude Code へ)

この文書は、claude.ai/code 上のリモートセッションからローカル PC (Windows) の Claude Code へ、開発を引き継ぐためのものです。まずこのファイルと `README.md` を読めば、経緯・現状・次の一手が把握できます。

## 経緯

- ユーザーの依頼: 「フロントミッションのガンハザードライクのゲーム作って」
- 『ガンハザード』(SFC) の要素 — 大型機兵・ホバリング・EN ゲージ・バルカン+サブ武装・向き固定・大型ボス — をオリジナル題材で再構成した横スクロールアクションとして実装した
- 権利面の方針: **実在 IP の名称・キャラ・デザインは使わない**。機体名・組織名・ボス名はすべてオリジナル (ヴァルチャー、ゼノスコーポ、ヴォルクグリフ等)。今後の追加要素も同方針で

## 成果物と現状

- `index.html` … ゲーム本体。**単一ファイル・外部依存ゼロ** (描画 Canvas 2D / 音 WebAudio 生成)。ダブルクリックで起動
- `README.md` … 遊び方・操作・ゲーム要素の一覧
- 検証済み: Playwright によるスモークテストで、タイトル→ブリーフィング→プレイ→ボス全パターン→クリア、死亡→ゲームオーバー→リトライ、ポーズまで **ページエラー 0** を確認済み (2026-08-21)

## 検証方法 (Windows)

```powershell
cd games/steel-vanguard/dev
npm install
npx playwright install chromium
node smoke.mjs
```

- 全遷移を自動プレイし、`dev/shots/` にスクリーンショットを保存する。終了コード 0 かつ `NO PAGE ERRORS` が合格
- コードを変更したら必ずこれを一周させること (過去にこのテストでボス停止位置のバグ等を 4 件検出している)

## コードマップ (`index.html` 内の `<script>`)

| セクション | 内容 |
| --- | --- |
| 入力 | `KEYMAP` / `keys` / `qpress` (keydown ラッチ。押下取りこぼし防止のため必須)。タッチボタンは `.tbtn` |
| サウンド | `initAudio` (初回入力で生成)、`SFX.*`、`musicTick` = 16 分音符スケジューラ (`BASS`/`LEADN`、ボス時は `bossMusic` で転調+テンポ増) |
| レベル | `STAGE_W=6400`, `GY=232` (地面)、`solids` (地形矩形)、`SPAWNS` (敵配置)、`ARENA_L/R`・`BOSS_TRIG` (ボス戦域)、`IND_X=3150` (工業地帯の境界)、`deco` (背景装飾。`mulberry` シード乱数で事前生成) |
| プレイヤー | `P` (feet 基準座標)。`stepPlayer` = 移動/ホバー (EN 0.62/f 消費・0.5/f 回復)/AABB 衝突/攻撃。`muzzlePos`・`fireVulcan`・`fireMissiles` |
| 敵 | `spawnEnemy` + `stepEnemy` の type 分岐 (walker/turret/drone/tank/heli/crate)。共通処理 `hitEnemy`/`explode` |
| ボス | `spawnBoss`/`stepBoss`。状態機械 st = enter→idle→(gat/msl/dash/mortar/laser)→die。HP45% 未満で `phase=2` (laser 解禁・高速化)。`armA` はワールド角。**待機時の腕はプレイヤー方向へ戻す (角度ラップ処理あり。壊すと腕が後ろを向く)** |
| 弾 | `pb` (自弾)/`eb` (敵弾。`grav`+`shell` で曲射)/`msl` (誘導弾。`hostile` はバルカンで迎撃可)/`beams` (ボスレーザー)/`marks` (迫撃着弾予告) |
| 描画 | 480×270 固定 → CSS 拡大 (pixelated)。`drawSky/Far/Mid` = 視差 0.06/0.18/0.45。HUD・各画面 (`drawTitle/Brief/Over/Clear/Pause`)・スキャンライン |
| ループ | 60fps 固定ステップ (`acc` 蓄積式)。`state` = TITLE/BRIEF/PLAY/OVER/CLEAR + `paused` |

## バランス調整の主なパラメータ

- プレイヤー: HP100 / EN100、バルカン dmg4・6f 間隔、ミサイル dmg26・初期 30 発、被弾無敵 55f
- ボス: HP950、ランク閾値は `finishStats` (S:13000 / A:10500 / B:8000)
- 敵の発射間隔・弾速は `stepEnemy` 内の `e.t%N` と `eshot` の引数

## 既知の注意点

- `qpress` ラッチと `Object.assign(pkeys,keys)` の消費順を変えると入力を取りこぼす
- ボス出現位置は「アリーナ左端にカメラがあるときの視界内」(ARENA_R-280) に停止させている。アリーナ寸法を変えるときはここも連動させること
- ボス戦開始時に `bossLock` で後方の残存敵を除去している (画面外狙撃の防止)
- ミュート解除時の BGM 暴発防止のため `musicTick` はミュート中に `musicNext` を現在時刻へ進めている

## 次の候補タスク (推奨順)

1. **強化ショップ**: クリア/スコアでバルカン威力・EN 容量・装甲を強化 (ガンハザードの中核要素。localStorage に保存)
2. **ステージ 2**: 夜の市街戦など。`solids`/`SPAWNS`/背景セットをステージ配列化する構造変更から
3. **武器切替**: 火炎放射 (近距離持続)・レーザー (貫通) を C 長押し or Tab 切替で
4. ゲームパッド対応 (Gamepad API)、難易度選択

## 参考

- 開発時のリモートセッション: https://claude.ai/code/session_01K7D41odiurStrHB9cncMrT
- 公開版 (ユーザー確認用 Artifact): https://claude.ai/code/artifact/7b3ffb2b-7824-4269-965e-2ac51b789b5c
