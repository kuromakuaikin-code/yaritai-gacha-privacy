// =============================================================
// 画面側の入口。ここで全部をつなぐ。
//
//   - VRM の読み込み (設定に記憶したパス / ダイアログ / ドラッグ＆ドロップ)
//   - クリック透過の切り替え  ← このアプリで一番むずかしいところ
//   - キャラを掴んでのウィンドウ移動
//   - 会話 UI (入力欄・吹き出し・右クリックメニュー)
// =============================================================
import { Stage } from "./stage.mjs";
import { Talk } from "./talk.mjs";

const api = window.companion;

const el = {
  canvas: document.getElementById("canvas"),
  bubble: document.getElementById("bubble"),
  menu: document.getElementById("menu"),
  bar: document.getElementById("bar"),
  input: document.getElementById("input"),
  setup: document.getElementById("setup"),
  setupPick: document.getElementById("setup-pick"),
  setupClose: document.getElementById("setup-close"),
  setupMessage: document.getElementById("setup-message"),
};

const stage = new Stage(el.canvas);
/** @type {Talk} */
let talk;

/** "setup" = モデル選択パネルを出している / "live" = キャラが立っている */
let mode = "setup";
/** いま透過を切っている (＝マウス操作を受けている) か */
let interactive = true;
/** キャラや UI に最後に当たった時刻。輪郭でのちらつきを抑えるために使う */
let lastHitAt = 0;
/** マウスの現在位置 (透過中も forward: true のおかげで届く) */
const pointer = { x: -1, y: -1 };
/** マウスが動いた等で、当たり判定をやり直す必要があるか */
let hitDirty = true;
/** 直前の当たり判定の結果 (動いていない間は使い回してレイキャストを省く) */
let lastHit = false;

let dragging = false;
let dragMoved = false;
let dragOrigin = { x: 0, y: 0 };
let menuOpen = false;
let dragEnterCount = 0;

const HIT_GRACE_MS = 150; // 当たらなくなってから透過に戻すまでの猶予
const DRAG_THRESHOLD = 4; // これ以下の動きは「クリック」とみなす

// =============================================================
// クリック透過
//
// 仕組み:
//   main.js が setIgnoreMouseEvents(true, { forward: true }) を掛けると、
//   クリックは下のウィンドウへ素通りするが、マウスの移動だけはこちらに届く。
//   その座標を毎フレーム見て、
//     ・UI 部品の上か        → elementFromPoint で判定
//     ・キャラの上か          → stage.hitTest (矩形でふるい分け → レイキャスト)
//   のどちらかなら透過を解除する。どちらでもない状態が少し続いたら透過に戻す。
//
// 猶予 (HIT_GRACE_MS) を入れているのは、髪の毛のような細い部分の上で
// 「当たる/当たらない」が高速に入れ替わると、クリックを取りこぼすため。
// =============================================================
function isOnUi(x, y) {
  if (x < 0 || y < 0) return false;
  const target = document.elementFromPoint(x, y);
  // canvas と吹き出しは pointer-events: none なので、ここには出てこない
  return !!(target && target.closest(".ui"));
}

function setInteractive(next) {
  if (interactive === next) return;
  interactive = next;
  api.setPassthrough(!next);
  document.body.classList.toggle("interactive", next);
}

function updatePassthrough() {
  // パネルを出している間・掴んでいる間・メニューを開いている間は、必ず操作を受ける
  if (mode === "setup" || dragging || menuOpen || dragEnterCount > 0) {
    lastHitAt = performance.now();
    setInteractive(true);
    return;
  }
  // マウスが動いていない間は前回の結果を使う (レイキャストは毎フレームやらない)
  if (hitDirty) {
    const onUi = isOnUi(pointer.x, pointer.y);
    lastHit = onUi || stage.hitTest(pointer.x, pointer.y);
    hitDirty = false;
  }

  const now = performance.now();
  if (lastHit) {
    lastHitAt = now;
    setInteractive(true);
  } else if (now - lastHitAt > HIT_GRACE_MS) {
    setInteractive(false);
  }
}

// 透過中でも届くのは「マウス移動」なので、pointermove ではなく mousemove を見る
window.addEventListener("mousemove", (event) => {
  if (event.clientX === pointer.x && event.clientY === pointer.y) return;
  pointer.x = event.clientX;
  pointer.y = event.clientY;
  hitDirty = true;
});

// ウィンドウの外に出たら、当たっていない扱いにする
document.addEventListener("mouseleave", () => {
  pointer.x = -1;
  pointer.y = -1;
  hitDirty = true;
});

// =============================================================
// キャラを掴んでウィンドウを動かす / クリックで入力欄を開閉する
// =============================================================
window.addEventListener("pointerdown", (event) => {
  if (menuOpen && !isOnUi(event.clientX, event.clientY)) closeMenu();
  if (event.button !== 0 || mode !== "live") return;
  if (isOnUi(event.clientX, event.clientY)) return;
  if (!stage.hitTest(event.clientX, event.clientY)) return;

  dragging = true;
  dragMoved = false;
  dragOrigin = { x: event.screenX, y: event.screenY };
  document.body.classList.add("dragging");
  // 掴んでいる間、離した合図を取りこぼさないようにする
  try {
    event.target?.setPointerCapture?.(event.pointerId);
  } catch {
    /* 捕まえられなくても、window の pointerup で拾えることが多い */
  }
  api.dragStart(); // 実際の移動は main.js がカーソルを追って行う
});

window.addEventListener("pointermove", (event) => {
  if (!dragging) return;
  // ウィンドウが動くので clientX は当てにならない。画面座標で判断する
  if (
    Math.abs(event.screenX - dragOrigin.x) > DRAG_THRESHOLD ||
    Math.abs(event.screenY - dragOrigin.y) > DRAG_THRESHOLD
  ) {
    dragMoved = true;
  }
});

/** @param {boolean} released 指を離したことによる終了か (途中で取り消された場合は false) */
function endDrag(released) {
  if (!dragging) return;
  dragging = false;
  hitDirty = true; // ウィンドウが動いたぶん、当たり判定はやり直す
  document.body.classList.remove("dragging");
  api.dragEnd();
  // ほとんど動かさなかったら「キャラをつついた」とみなして入力欄を開閉する
  if (released && !dragMoved) toggleBar();
}

window.addEventListener("pointerup", () => endDrag(true));
window.addEventListener("pointercancel", () => endDrag(false));
window.addEventListener("lostpointercapture", () => endDrag(false));
window.addEventListener("blur", () => endDrag(false));

// =============================================================
// 右クリックメニュー
// =============================================================
function openMenu(x, y) {
  el.menu.classList.remove("hidden");
  menuOpen = true;
  // はみ出さない位置に置く (大きさは表示してからでないと測れない)
  const rect = el.menu.getBoundingClientRect();
  const left = Math.max(4, Math.min(x, window.innerWidth - rect.width - 4));
  const top = Math.max(4, Math.min(y, window.innerHeight - rect.height - 4));
  el.menu.style.left = `${left}px`;
  el.menu.style.top = `${top}px`;
}

function closeMenu() {
  el.menu.classList.add("hidden");
  menuOpen = false;
}

window.addEventListener("contextmenu", (event) => {
  event.preventDefault();
  if (mode !== "live") return;
  if (isOnUi(event.clientX, event.clientY)) return;
  if (!stage.hitTest(event.clientX, event.clientY)) return;
  openMenu(event.clientX, event.clientY);
});

document.getElementById("menu-talk").addEventListener("click", () => {
  closeMenu();
  toggleBar(true);
});
document.getElementById("menu-model").addEventListener("click", () => {
  closeMenu();
  openSetup("別の VRM ファイルを選んでください。");
});
document.getElementById("menu-fallback").addEventListener("click", () => {
  closeMenu();
  toggleFallback();
});
document.getElementById("menu-devtools").addEventListener("click", () => {
  closeMenu();
  api.openDevTools();
});
document.getElementById("menu-minimize").addEventListener("click", () => {
  closeMenu();
  api.minimize();
});
document.getElementById("menu-quit").addEventListener("click", () => api.quit());

// =============================================================
// 描画モードの切り替え (MToon ↔ 標準マテリアル)
//
// MToon で正しく映らないときの逃げ道。見た目の質は落ちるが、
// まず「映る」ことを確かめられる。選んだモードは記憶する。
// =============================================================
async function toggleFallback(next) {
  if (!stage.ready) return;
  const on = stage.setFallback(next ?? !stage.fallback);
  await api.saveSettings({ fallbackMaterials: on });
  const label = on ? "代替 (MeshStandardMaterial)" : "通常 (MToon)";
  api.diag(`描画モードを切り替えました: ${label}`);
  talk?.show(`描画モード: ${label}`);
}

// =============================================================
// 会話の入力欄
// =============================================================
function toggleBar(forceOpen = false) {
  const hidden = el.bar.classList.contains("hidden");
  if (hidden || forceOpen) {
    el.bar.classList.remove("hidden");
    el.input.focus();
  } else {
    el.bar.classList.add("hidden");
    el.input.blur();
  }
}

el.bar.addEventListener("submit", (event) => {
  event.preventDefault();
  const text = el.input.value;
  el.input.value = "";
  talk?.send(text);
});

window.addEventListener("keydown", (event) => {
  // --- 開発用ショートカット -------------------------------------
  // F12 / Ctrl+Shift+I は main 側でも拾っているが、入力欄に
  // 焦点があるときのために画面側でも受ける
  if (event.key === "F12") {
    event.preventDefault();
    api.openDevTools();
    return;
  }
  // Ctrl+Shift+M: 描画モード (MToon ↔ 標準マテリアル) の切り替え
  if ((event.ctrlKey || event.metaKey) && event.shiftKey && event.key.toLowerCase() === "m") {
    event.preventDefault();
    toggleFallback();
    return;
  }
  // Ctrl+Shift+D: 今のモデルの診断ログをもう一度端末に出す
  if ((event.ctrlKey || event.metaKey) && event.shiftKey && event.key.toLowerCase() === "d") {
    event.preventDefault();
    reportDiagnostics();
    return;
  }

  if (event.key !== "Escape") return;
  if (menuOpen) return closeMenu();
  if (!el.bar.classList.contains("hidden")) {
    el.bar.classList.add("hidden");
    el.input.blur();
    return;
  }
  talk?.hide();
});

// =============================================================
// 診断ログ
//
// 画面側の console.log は DevTools にしか出ないので、
// 端末 (npm start したところ) に出したいものは api.diag で main に送る。
// 表示がおかしいときは、この出力をそのまま貼ってもらえば原因を追える。
// =============================================================
/** @type {object|null} three などの版 */
let versions = null;

function reportDiagnostics() {
  if (!stage.ready) {
    api.diag("診断: まだモデルが読み込まれていません");
    return;
  }
  api.diag(stage.describeDiagnostics(versions));
}

// 画面側で拾えなかったエラーも端末に出す (シェーダーのエラーなどが分かる)
window.addEventListener("error", (event) => {
  api.diag(`画面側のエラー: ${event.message} (${event.filename}:${event.lineno})`);
});
window.addEventListener("unhandledrejection", (event) => {
  api.diag(`画面側の未処理エラー: ${event.reason?.message ?? event.reason}`);
});

// =============================================================
// VRM の読み込み
// =============================================================
function setSetupMessage(text, trouble = false) {
  el.setupMessage.textContent = text;
  el.setupMessage.classList.toggle("trouble", trouble);
}

function openSetup(message) {
  mode = "setup";
  closeMenu();
  el.bar.classList.add("hidden");
  talk?.hide();
  el.setup.classList.remove("hidden");
  // すでにキャラがいるなら「やめる」で戻れるようにする
  el.setupClose.classList.toggle("hidden", !stage.ready);
  setSetupMessage(message ?? "選んだ場所は記憶され、次回の起動から自動で読み込まれます。");
}

function closeSetup() {
  if (!stage.ready) return; // キャラがいないうちは閉じられない
  el.setup.classList.add("hidden");
  mode = "live";
}

/**
 * VRM ファイルを読み込んで立たせる。
 * @param {string} filePath
 * @param {boolean} [quiet] 起動時の自動読み込みで、失敗しても静かに扱うか
 */
async function useVrm(filePath, quiet = false) {
  if (!filePath) return false;
  if (!/\.(vrm|glb)$/i.test(filePath)) {
    setSetupMessage("VRM ファイル (.vrm) を選んでください。", true);
    return false;
  }

  setSetupMessage("読み込んでいます…");
  const file = await api.readVrm(filePath);
  if (!file?.ok) {
    const reason =
      file?.reason === "missing"
        ? "ファイルが見つかりませんでした。移動または削除されたようです。"
        : "ファイルを読めませんでした。";
    if (!quiet) setSetupMessage(reason, true);
    else openSetup(reason);
    return false;
  }

  try {
    await stage.loadVrm(file.data);
  } catch (err) {
    const message = `VRM として読み込めませんでした。\n(${err?.message ?? "原因不明"})`;
    api.diag(`VRM の読み込みに失敗: ${err?.stack ?? err?.message ?? err}`);
    if (!quiet) setSetupMessage(message, true);
    else openSetup(message);
    return false;
  }

  // 読み込めた中身を端末に出しておく (表示不具合の切り分け用)
  reportDiagnostics();

  await api.saveSettings({ vrmPath: filePath });
  hitDirty = true;
  closeSetup();
  return true;
}

el.setupPick.addEventListener("click", async () => {
  const picked = await api.pickVrm();
  if (picked) await useVrm(picked);
});

el.setupClose.addEventListener("click", closeSetup);

// --- ドラッグ＆ドロップ -----------------------------------------
// ファイルを持ち込んでいる間はクリック透過を止める必要があるため、
// dragEnterCount で「いま持ち込み中か」を数えている。
window.addEventListener("dragenter", (event) => {
  event.preventDefault();
  dragEnterCount++;
  document.body.classList.add("dragover");
});

window.addEventListener("dragover", (event) => {
  event.preventDefault();
  if (event.dataTransfer) event.dataTransfer.dropEffect = "copy";
});

window.addEventListener("dragleave", (event) => {
  event.preventDefault();
  dragEnterCount = Math.max(0, dragEnterCount - 1);
  if (dragEnterCount === 0) document.body.classList.remove("dragover");
});

window.addEventListener("drop", async (event) => {
  event.preventDefault();
  dragEnterCount = 0;
  document.body.classList.remove("dragover");

  const file = event.dataTransfer?.files?.[0];
  if (!file) return;
  const filePath = api.pathOf(file);
  if (!filePath) {
    openSetup("ファイルの場所が取れませんでした。下のボタンから選んでください。");
    return;
  }
  if (!/\.(vrm|glb)$/i.test(filePath)) {
    openSetup("VRM ファイル (.vrm) を入れてください。");
    return;
  }
  if (mode !== "setup") openSetup("読み込んでいます…");
  await useVrm(filePath);
});

// =============================================================
// 起動
// =============================================================
window.addEventListener("resize", () => {
  stage.resize();
  hitDirty = true;
});

let previous = performance.now();
function tick(now) {
  const delta = Math.min(0.1, (now - previous) / 1000); // タブ復帰時の飛びを抑える
  previous = now;
  stage.update(delta);
  updatePassthrough();
  requestAnimationFrame(tick);
}

async function start() {
  const character = await api.getCharacter();
  talk = new Talk({ bubble: el.bubble, character });

  const capabilities = await api.getCapabilities();
  const settings = await api.getSettings();
  versions = await api.getVersions();

  // 前回「代替マテリアル」で見ていたなら、その状態で読み込む
  stage.fallback = !!settings.fallbackMaterials;

  requestAnimationFrame(tick);

  // 前回のモデルがあれば黙って読み込む。無ければ選んでもらう
  let loaded = false;
  if (settings.vrmPath) {
    openSetup("読み込んでいます…");
    loaded = await useVrm(settings.vrmPath, true);
  } else {
    openSetup();
  }

  // Linux では setIgnoreMouseEvents の forward が効かないので、透過は使えない
  const caution = capabilities.passthrough
    ? ""
    : `\n\n(この OS (${capabilities.platform}) ではクリック透過が使えないため、` +
      "ウィンドウ全体がマウス操作を受け取ります)";

  if (loaded) {
    talk.show(
      `${character.name} が来ました。\n` +
        "キャラをクリックで入力欄、右クリックでメニュー。ドラッグで動かせます。" +
        caution
    );
    el.bar.classList.remove("hidden");
    if (stage.fallback) api.diag("描画モード: 代替 (MeshStandardMaterial) で起動しました");
  } else if (caution) {
    setSetupMessage(caution.trim());
  }
}

start().catch((err) => {
  el.setup.classList.remove("hidden");
  setSetupMessage(`起動に失敗しました: ${err?.message ?? err}`, true);
});
