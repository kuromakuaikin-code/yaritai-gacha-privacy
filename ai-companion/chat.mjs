#!/usr/bin/env node
// =============================================================
// Phase 0-1: ローカルLLM (LM Studio) と会話し、VOICEVOX があれば声で返す
//
// 使い方:
//   1. LM Studio を起動し、モデル (Gemma 4 など) をロード
//      → Developer タブで「Start Server」(localhost:1234)
//   2. (任意) VOICEVOX を起動しておくと、返事が声になる
//   3. node chat.mjs
//
// 依存パッケージなし。Node.js 18 以上だけで動きます。
// =============================================================
import { createInterface } from "node:readline/promises";
import { readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

// キャラクター設定 (人格の半分はこのファイル。自由に書き換えてOK)
const character = JSON.parse(readFileSync(join(here, "character.json"), "utf8"));

const LMSTUDIO = "http://localhost:1234"; // 脳: LM Studio の窓口
const VOICEVOX = "http://localhost:50021"; // 声: VOICEVOX の窓口

// --- 脳 (LM Studio) に接続できるか確認し、ロード中のモデル名を取る ---
async function detectModel() {
  try {
    const res = await fetch(`${LMSTUDIO}/v1/models`, { signal: AbortSignal.timeout(3000) });
    const data = await res.json();
    const id = data.data?.[0]?.id;
    if (!id) throw new Error("no model");
    return id;
  } catch {
    console.error("LM Studio に接続できませんでした。");
    console.error("  1. LM Studio を起動してモデルをロードする");
    console.error("  2. Developer タブで「Start Server」を押す (localhost:1234)");
    console.error("を確認してから、もう一度実行してください。");
    process.exit(1);
  }
}

// --- 声 (VOICEVOX) が起動しているか確認する。なければテキストのみで動く ---
async function detectVoicevox() {
  try {
    const res = await fetch(`${VOICEVOX}/version`, { signal: AbortSignal.timeout(1000) });
    return res.ok;
  } catch {
    return false;
  }
}

// --- 返事の文章を VOICEVOX で音声にして再生する ---
async function speak(text) {
  const speaker = character.voicevoxSpeaker;
  const q = await fetch(
    `${VOICEVOX}/audio_query?speaker=${speaker}&text=${encodeURIComponent(text)}`,
    { method: "POST" }
  );
  const query = await q.json();
  const s = await fetch(`${VOICEVOX}/synthesis?speaker=${speaker}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(query),
  });
  const wav = Buffer.from(await s.arrayBuffer());
  const file = join(tmpdir(), "companion-voice.wav");
  writeFileSync(file, wav);
  if (process.platform === "win32") {
    spawnSync("powershell", ["-c", `(New-Object Media.SoundPlayer '${file}').PlaySync()`]);
  } else if (process.platform === "darwin") {
    spawnSync("afplay", [file]);
  } else {
    spawnSync("aplay", [file]);
  }
}

// --- メイン: 会話ループ ---
const model = await detectModel();
const hasVoice = await detectVoicevox();

console.log(`--- ${character.name} (モデル: ${model} / 声: ${hasVoice ? "VOICEVOX" : "なし"}) ---`);
console.log("話しかけてください。終わるときは Ctrl+C か「バイバイ」\n");

const messages = [{ role: "system", content: character.systemPrompt }];
const rl = createInterface({ input: process.stdin, output: process.stdout });

while (true) {
  const input = (await rl.question("きみ > ")).trim();
  if (!input) continue;

  messages.push({ role: "user", content: input });

  const res = await fetch(`${LMSTUDIO}/v1/chat/completions`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model,
      messages,
      temperature: 0.8,
      max_tokens: 300,
    }),
  });
  const data = await res.json();
  const reply = data.choices?.[0]?.message?.content?.trim() ?? "(返事が取れませんでした)";

  messages.push({ role: "assistant", content: reply });
  // 履歴が伸びすぎたら古いものから忘れる (system は残す)
  if (messages.length > 41) messages.splice(1, 2);

  console.log(`${character.name} > ${reply}\n`);
  if (hasVoice) await speak(reply);

  if (input === "バイバイ") {
    rl.close();
    break;
  }
}
