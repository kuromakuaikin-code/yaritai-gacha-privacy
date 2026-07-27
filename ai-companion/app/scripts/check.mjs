#!/usr/bin/env node
// =============================================================
// 画面を出さずにできる範囲の自己点検 (npm run check)
//
//   1. すべての .js / .mjs が構文的に正しいか
//   2. index.html の importmap が指す先が実在するか (npm install 済みか)
//   3. 画面側から呼んでいる window.companion.* が preload.js にあるか
//   4. getElementById で探している id が index.html にあるか
//   5. 表情 (Phase 3) と口パク (Phase 4) の計算が期待どおりか
//
// GUI のない環境でも壊れに気づけるようにするための、簡単な確認です。
// =============================================================
import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join, dirname, extname } from "node:path";
import { fileURLToPath } from "node:url";

const APP = dirname(dirname(fileURLToPath(import.meta.url)));
const problems = [];
const notes = [];

// --- 1. 構文チェック -----------------------------------------
function collect(dir, found = []) {
  for (const name of readdirSync(dir)) {
    if (name === "node_modules" || name.startsWith(".")) continue;
    const full = join(dir, name);
    if (statSync(full).isDirectory()) collect(full, found);
    else if ([".js", ".mjs"].includes(extname(name))) found.push(full);
  }
  return found;
}

const files = collect(APP);
for (const file of files) {
  try {
    execFileSync(process.execPath, ["--check", file], { stdio: "pipe" });
  } catch (err) {
    problems.push(`構文エラー: ${file}\n${err.stderr?.toString() ?? err.message}`);
  }
}
notes.push(`構文チェック: ${files.length} ファイル`);

// --- 2. importmap の行き先 -----------------------------------
const html = readFileSync(join(APP, "renderer", "index.html"), "utf8");
const mapText = html.match(/<script type="importmap">([\s\S]*?)<\/script>/)?.[1];
if (!mapText) {
  problems.push("index.html に importmap が見つかりません");
} else {
  const imports = JSON.parse(mapText).imports ?? {};
  for (const [name, target] of Object.entries(imports)) {
    // 末尾が / のものはフォルダ指定
    const path = join(APP, target.replace(/^\//, ""));
    if (!existsSync(path)) {
      problems.push(`importmap の "${name}" が指す ${target} がありません (npm install 済み?)`);
    }
  }
  notes.push(`importmap: ${Object.keys(imports).length} 件を確認`);
}

// --- 2.5 CSP が VRM のテクスチャを止めていないか ----------------
// three.js の GLTFLoader は .vrm 内の画像を blob: URL 経由 (fetch) で読む。
// connect-src に blob: が無いと全テクスチャが読めず、キャラが真っ白になる。
// 一度これで丸一日溶かしたので、ここで見張る。
const csp = html.match(/http-equiv="Content-Security-Policy"[\s\S]*?content="([^"]+)"/)?.[1];
if (!csp) {
  problems.push("index.html に Content-Security-Policy がありません");
} else {
  const connectSrc = csp.match(/connect-src ([^;"]+)/)?.[1] ?? "";
  if (!connectSrc.includes("blob:")) {
    problems.push(
      "CSP の connect-src に blob: がありません " +
        "(VRM のテクスチャが読めず、キャラが輪郭だけ・真っ白になります)"
    );
  }
  notes.push(`CSP: connect-src = ${connectSrc.trim() || "(なし)"}`);
}

// --- 3. preload が公開している API と、画面側の呼び出しの照合 ---
const preload = readFileSync(join(APP, "preload.js"), "utf8");
const exposed = new Set([...preload.matchAll(/^\s{2}(\w+):/gm)].map((m) => m[1]));
const used = new Set();
for (const file of files.filter((f) => f.includes("renderer"))) {
  const source = readFileSync(file, "utf8");
  for (const m of source.matchAll(/\bapi\.(\w+)\(/g)) used.add(m[1]);
}
for (const name of used) {
  if (!exposed.has(name)) problems.push(`preload.js に api.${name} がありません`);
}
notes.push(`preload の API: ${exposed.size} 個公開 / 画面側で ${used.size} 個使用`);

// --- 4. getElementById の id が HTML にあるか -------------------
const htmlIds = new Set([...html.matchAll(/\bid="([^"]+)"/g)].map((m) => m[1]));
const wantedIds = new Set();
for (const file of files.filter((f) => f.includes("renderer"))) {
  const source = readFileSync(file, "utf8");
  for (const m of source.matchAll(/getElementById\("([^"]+)"\)/g)) wantedIds.add(m[1]);
}
for (const id of wantedIds) {
  if (!htmlIds.has(id)) problems.push(`index.html に id="${id}" がありません`);
}
notes.push(`要素の id: ${wantedIds.size} 個を index.html と照合`);

// --- 5. 表情 (Phase 3) と口パク (Phase 4) のしくみ --------------
// 画面を出さなくても確かめられる部分は、ここで数値として検証する。
// (three.js や WebAudio に触らない純粋な計算だけを切り出してあるため)
let checked = 0;
function ok(condition, label) {
  checked++;
  if (!condition) problems.push(`しくみのテスト: ${label}`);
}
function near(actual, expected, tolerance, label) {
  ok(Math.abs(actual - expected) <= tolerance, `${label} (実際: ${actual})`);
}

const emotion = await import("../../emotion.mjs");
const expression = await import("../renderer/expression.mjs");
const lipsync = await import("../renderer/lipsync.mjs");

// 感情タグの取り出し
{
  const cases = [
    ["[happy] やったね", "happy", "やったね"],
    ["【うれしい】ありがとう", "happy", "ありがとう"],
    ["(joy) おはよう", "happy", "おはよう"], // VRM 0.x の旧名も吸収する
    ["surprised\nびっくりした", "surprised", "びっくりした"], // 括弧を忘れた形
    ["きょうは疲れたね [sad]", "sad", "きょうは疲れたね"], // 末尾に付けてくる形
    ["ふつうの返事です", "neutral", "ふつうの返事です"], // タグ無し
  ];
  for (const [input, wanted, body] of cases) {
    const parted = emotion.splitEmotion(input);
    ok(parted.emotion === wanted, `"${input}" の感情が ${wanted} にならない (${parted.emotion})`);
    ok(parted.text === body, `"${input}" の本文が "${body}" にならない ("${parted.text}")`);
  }
  // 知らない括弧書きは剥がさない ((笑) を食べてしまわないこと)
  const laugh = emotion.splitEmotion("(笑) そうだね");
  ok(laugh.text === "(笑) そうだね", "知らない括弧書きを本文から剥がしてしまっている");
  ok(laugh.source === "none", "知らない括弧書きをタグ扱いしている");

  // 指示の付加。二重に足さないこと・元の配列を壊さないこと
  const guided = emotion.withEmotionGuide("あなたはコンパニオンです。");
  ok(guided.includes("[happy]"), "システムプロンプトに感情タグの指示が足されていない");
  ok(emotion.withEmotionGuide(guided) === guided, "感情タグの指示を二重に足している");
  const original = [{ role: "system", content: "人格" }, { role: "user", content: "やあ" }];
  const patched = emotion.messagesWithEmotionGuide(original);
  ok(original[0].content === "人格", "messagesWithEmotionGuide が元の配列を書き換えている");
  ok(patched[0].content.includes("[happy]"), "messagesWithEmotionGuide が指示を足していない");

  // JSON 方式 (フォールバック) の緩い読み取り
  ok(
    emotion.emotionFromJsonText('```json\n{"emotion": "sorrow"}\n```') === "sad",
    "コードブロックで包まれた JSON から感情を読めていない"
  );
  ok(emotion.emotionFromJsonText("たぶん surprised です") === "surprised", "緩い JSON 読み取りが効いていない");
  ok(emotion.emotionFromJsonText("わかりません") === null, "知らない返事から感情をでっち上げている");
}

// 表情の合成 (クロスフェード・まばたきとの両立・口との調停)
{
  // モデルに happy と sad はあるが angry は無い、という想定の作りもの
  const values = new Map();
  const has = ["neutral", "happy", "sad", "aa", "blink"];
  const manager = {
    expressionMap: Object.fromEntries(has.map((n) => [n, { name: n }])),
    setValue: (name, weight) => values.set(name, weight),
  };
  const mixer = new expression.ExpressionMixer();
  mixer.bind(manager);

  ok(mixer.supports("happy"), "モデルにある happy を使えていない");
  ok(!mixer.supports("angry"), "モデルに無い angry を使えることになっている");
  ok(mixer.setEmotion("angry") === "neutral", "モデルに無い感情が neutral に落ちていない");

  mixer.setEmotion("happy");
  mixer.update(expression.EMOTION_FADE_SEC / 2); // 半分の時間だけ進める
  near(values.get("happy"), expression.EMOTION_MAX / 2, 0.02, "クロスフェードの中間が半分になっていない");
  mixer.update(expression.EMOTION_FADE_SEC); // 残り
  near(values.get("happy"), expression.EMOTION_MAX, 0.001, "クロスフェードが最大まで届いていない");

  // 別の感情へ移ると、前の感情が消えて新しい感情が立つ
  mixer.setEmotion("sad");
  mixer.update(expression.EMOTION_FADE_SEC);
  near(values.get("happy"), 0, 0.001, "前の感情が消えていない");
  near(values.get("sad"), expression.EMOTION_MAX, 0.001, "新しい感情が立っていない");

  // まばたきは感情と独立して重なる
  mixer.setBlink(1);
  mixer.update(1 / 60);
  ok(values.get("blink") === 1, "まばたきが表情に入っていない");
  ok(values.get("sad") > 0, "まばたきが感情を消してしまっている");

  // 口を開けると、感情はそのぶん譲る (口の形の取り合いを避ける)
  const before = values.get("sad");
  mixer.setMouth(1);
  mixer.update(1 / 60);
  near(values.get("aa"), expression.MOUTH_MAX, 0.001, "口の開きが表情に入っていない");
  ok(values.get("sad") < before, "口が開いても感情が譲っていない");
  near(
    values.get("sad"),
    expression.EMOTION_MAX * (1 - expression.EMOTION_DUCK_BY_MOUTH),
    0.01,
    "口が開いたときの感情の薄め方がおかしい"
  );
}

// 口パクの計算
{
  ok(lipsync.levelFromRms(0) === 0, "無音で口が開いている");
  ok(lipsync.levelFromRms(lipsync.MOUTH_GATE) === 0, "小さすぎる音で口が開いている");
  ok(lipsync.levelFromRms(0.12) > 0.2, "ふつうの声量で口がほとんど開かない");
  ok(lipsync.levelFromRms(9) <= 1, "口の開きが上限を超えている");

  // 開くのは速く、閉じるのはゆっくり
  const opening = lipsync.smoothMouth(0, 1, 1 / 60);
  const closing = 1 - lipsync.smoothMouth(1, 0, 1 / 60);
  ok(opening > closing, "口が閉じるほうが開くより速くなっている");
  ok(opening < 1, "口の動きにならしが効いていない (いきなり全開)");

  // 擬似口パク: 文字数ぶんの長さがあり、値が 0〜1 に収まり、動いていること
  const score = lipsync.buildPseudoScore("こんにちは、げんきですか");
  ok(score.duration > 1, `擬似口パクが短すぎる (${score.duration}秒)`);
  ok(score.duration <= lipsync.PSEUDO_MAX_SEC, "擬似口パクが上限を超えている");
  let min = 1;
  let max = 0;
  for (let t = 0; t < score.duration; t += 1 / 60) {
    const level = lipsync.pseudoLevelAt(score, t);
    ok(level >= 0 && level <= 1, `擬似口パクの値が範囲外 (${level})`);
    min = Math.min(min, level);
    max = Math.max(max, level);
  }
  ok(max > 0.5, "擬似口パクで口がほとんど開いていない");
  ok(min < 0.2, "擬似口パクで口が閉じる瞬間がない");
  ok(lipsync.pseudoLevelAt(score, score.duration + 1) === 0, "擬似口パクが終わっても口が開いている");
  ok(lipsync.buildPseudoScore("").duration === 0, "空文字で口パクが動いている");
}

notes.push(`しくみのテスト: ${checked} 項目 (感情タグ・表情の合成・口パク)`);

// --- 結果 -----------------------------------------------------
for (const note of notes) console.log(`  ${note}`);
if (problems.length === 0) {
  console.log("\n問題は見つかりませんでした。");
} else {
  console.error("\n見つかった問題:");
  for (const problem of problems) console.error(`  - ${problem}`);
  process.exit(1);
}
