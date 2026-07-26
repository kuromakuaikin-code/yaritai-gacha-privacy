#!/usr/bin/env node
// =============================================================
// 画面を出さずにできる範囲の自己点検 (npm run check)
//
//   1. すべての .js / .mjs が構文的に正しいか
//   2. index.html の importmap が指す先が実在するか (npm install 済みか)
//   3. 画面側から呼んでいる window.companion.* が preload.js にあるか
//   4. getElementById で探している id が index.html にあるか
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

// --- 結果 -----------------------------------------------------
for (const note of notes) console.log(`  ${note}`);
if (problems.length === 0) {
  console.log("\n問題は見つかりませんでした。");
} else {
  console.error("\n見つかった問題:");
  for (const problem of problems) console.error(`  - ${problem}`);
  process.exit(1);
}
