// =============================================================
// Phase 2: 透過ウィンドウに VRM キャラを立たせる (Electron メインプロセス)
//
// このファイルの役割:
//   - 枠なし・背景透過・最前面のウィンドウを作る
//   - 画面 (renderer) からの依頼を受けて、OS 側の仕事を代行する
//       * VRM ファイルの選択・読み込み
//       * 設定の保存と読み出し
//       * LM Studio / VOICEVOX への HTTP 通信 (CORS を避けるため main 側で行う)
//       * クリック透過の切り替え、ウィンドウのドラッグ移動
//
// 画面側のコードは renderer/ にあります。
// =============================================================
const {
  app,
  BrowserWindow,
  ipcMain,
  dialog,
  protocol,
  net,
  screen,
} = require("electron");
const path = require("node:path");
const fs = require("node:fs");
const { pathToFileURL } = require("node:url");

const LMSTUDIO = "http://localhost:1234"; // 脳: LM Studio の窓口
const VOICEVOX = "http://localhost:50021"; // 声: VOICEVOX の窓口

// アプリ本体のフォルダ。ここより外のファイルは companion:// では配信しない
const ROOT = __dirname;
// character.json は ai-companion/ 直下 (chat.mjs と共用)
const CHARACTER_FILE = path.join(ROOT, "..", "character.json");
// 返事の取り出し (思考タグ・reasoning_content の処理) も chat.mjs と共用する。
// ESM なので require ではなく import() で読む。1 回だけ読んで使い回す。
const REPLY_MODULE = pathToFileURL(path.join(ROOT, "..", "reply.mjs")).toString();
let replyToolsPromise = null;
function replyTools() {
  if (!replyToolsPromise) replyToolsPromise = import(REPLY_MODULE);
  return replyToolsPromise;
}

// -------------------------------------------------------------
// 独自スキーム companion:// の登録
//
// file:// のままだと ES modules (import 文) が読めないブラウザ制約があるため、
// アプリのフォルダを companion://local/ として配信する。
// これで <script type="module"> と importmap がそのまま使える。
// 事前登録は app.whenReady() より前に行う必要がある。
// -------------------------------------------------------------
protocol.registerSchemesAsPrivileged([
  {
    scheme: "companion",
    privileges: {
      standard: true,
      secure: true,
      supportFetchAPI: true,
      corsEnabled: true,
    },
  },
]);

// -------------------------------------------------------------
// 設定ファイル (OS ごとのユーザーデータフォルダに置く)
//   Windows: %APPDATA%/ai-companion-app/settings.json
//   macOS:   ~/Library/Application Support/ai-companion-app/settings.json
// -------------------------------------------------------------
const DEFAULT_SETTINGS = {
  vrmPath: "", // 前回選んだ VRM の場所
  bounds: null, // 前回のウィンドウ位置とサイズ
  fallbackMaterials: false, // MToon をやめて標準マテリアルで描くか (表示不具合の逃げ道)
};

function settingsFile() {
  return path.join(app.getPath("userData"), "settings.json");
}

function loadSettings() {
  try {
    const raw = fs.readFileSync(settingsFile(), "utf8");
    return { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
  } catch {
    return { ...DEFAULT_SETTINGS };
  }
}

function saveSettings(patch) {
  const next = { ...loadSettings(), ...patch };
  try {
    fs.mkdirSync(path.dirname(settingsFile()), { recursive: true });
    fs.writeFileSync(settingsFile(), JSON.stringify(next, null, 2), "utf8");
  } catch (err) {
    console.error("設定の保存に失敗しました:", err.message);
  }
  return next;
}

// -------------------------------------------------------------
// キャラクター設定 (人格) の読み込み。無ければ最低限の既定値で動かす
// -------------------------------------------------------------
function loadCharacter() {
  try {
    return JSON.parse(fs.readFileSync(CHARACTER_FILE, "utf8"));
  } catch {
    return {
      name: "コンパニオン",
      voicevoxSpeaker: 3,
      systemPrompt: "あなたはデスクトップコンパニオンです。返事は短めに、話し言葉で。",
    };
  }
}

// -------------------------------------------------------------
// 診断ログ
//
// 画面側 (renderer) の console.log は DevTools にしか出ないので、
// 「npm start した端末に出したい」情報はここを通して main の標準出力に流す。
// 困ったときは、この出力をそのまま貼ってもらえば原因が追える。
// -------------------------------------------------------------
function diag(line) {
  console.log(`[診断] ${line}`);
}

/** 使っているライブラリの版を集める (three と three-vrm の組み合わせが要注意なので) */
function collectVersions() {
  const read = (name) => {
    try {
      const file = path.join(ROOT, "node_modules", ...name.split("/"), "package.json");
      return JSON.parse(fs.readFileSync(file, "utf8")).version;
    } catch {
      return "(不明)";
    }
  };
  return {
    three: read("three"),
    threeVrm: read("@pixiv/three-vrm"),
    electron: process.versions.electron,
    chrome: process.versions.chrome,
    node: process.versions.node,
    platform: `${process.platform} ${process.arch}`,
  };
}

// -------------------------------------------------------------
// ウィンドウ
// -------------------------------------------------------------
/** @type {BrowserWindow | null} */
let win = null;

/** DevTools を開く (画面側のエラーを見てもらうため) */
function openDevTools() {
  if (!win || win.isDestroyed()) return;
  // 枠なし・透過ウィンドウなので、必ず別ウィンドウで開く
  if (win.webContents.isDevToolsOpened()) win.webContents.closeDevTools();
  else win.webContents.openDevTools({ mode: "detach" });
}

function createWindow() {
  const settings = loadSettings();
  const area = screen.getPrimaryDisplay().workArea;
  const width = settings.bounds?.width ?? 380;
  const height = settings.bounds?.height ?? 620;

  // 既定の位置は画面の右下すこし内側
  const bounds = {
    width,
    height,
    x: settings.bounds?.x ?? area.x + area.width - width - 40,
    y: settings.bounds?.y ?? area.y + area.height - height - 20,
  };

  win = new BrowserWindow({
    ...bounds,
    transparent: true, // 背景を完全に透過させる
    frame: false, // タイトルバー・枠なし
    alwaysOnTop: true, // 常に最前面
    hasShadow: false, // 影が四角く出るのを防ぐ
    resizable: true,
    maximizable: false,
    fullscreenable: false,
    skipTaskbar: false, // タスクバーには残す (見失ったときの逃げ道)
    backgroundColor: "#00000000",
    title: "ai-companion",
    show: false,
    webPreferences: {
      preload: path.join(ROOT, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      // preload.js は electron のモジュールしか使わないので、サンドボックスを有効にできる
      sandbox: true,
    },
  });

  // 他の「最前面」ウィンドウよりさらに上に置く
  win.setAlwaysOnTop(true, "floating");
  // macOS: 別のデスクトップや全画面アプリの上でも見えるようにする
  if (process.platform === "darwin") {
    win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  }

  // 画面側の console と、拾えなかった例外を端末にも流す。
  // WebGL のシェーダーエラーはここに出るので、表示不具合の切り分けに効く。
  win.webContents.on("console-message", (...args) => {
    // Electron の版で引数の形が変わるので、両方に備える
    const detail = typeof args[1] === "object" && args[1] !== null ? args[1] : null;
    const level = detail ? detail.level : args[1];
    const message = detail ? detail.message : args[2];
    // 情報レベルは画面側から明示的に送ってもらう方針なので、警告以上だけ拾う
    const noisy = level === "info" || level === 0 || level === 1;
    if (!noisy && typeof message === "string") diag(`画面側: ${message}`);
  });
  win.webContents.on("render-process-gone", (_e, details) => {
    diag(`画面プロセスが落ちました: ${details.reason}`);
  });

  // 開発用ショートカット: F12 / Ctrl(⌘)+Shift+I で DevTools
  win.webContents.on("before-input-event", (_event, input) => {
    if (input.type !== "keyDown") return;
    const modifier = process.platform === "darwin" ? input.meta : input.control;
    if (input.key === "F12" || (modifier && input.shift && input.key.toLowerCase() === "i")) {
      openDevTools();
    }
  });

  win.loadURL("companion://local/renderer/index.html");
  win.once("ready-to-show", () => win.show());

  // 位置やサイズを変えたら覚えておく (連続で呼ばれるので少し待ってから書く)
  let saveTimer = null;
  const rememberBounds = () => {
    if (!win || win.isDestroyed()) return;
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      if (!win || win.isDestroyed()) return;
      saveSettings({ bounds: win.getBounds() });
    }, 400);
  };
  win.on("move", rememberBounds);
  win.on("resize", rememberBounds);
  win.on("closed", () => {
    win = null;
  });
}

// -------------------------------------------------------------
// companion:// の中身を返す (アプリのフォルダ内のファイルだけ)
// -------------------------------------------------------------
function handleCompanionProtocol() {
  protocol.handle("companion", (request) => {
    let filePath;
    try {
      const url = new URL(request.url);
      filePath = path.normalize(path.join(ROOT, decodeURIComponent(url.pathname)));
    } catch {
      return new Response("bad request", { status: 400 });
    }
    // アプリのフォルダの外に出る要求 (../ など) は拒否する
    if (filePath !== ROOT && !filePath.startsWith(ROOT + path.sep)) {
      return new Response("forbidden", { status: 403 });
    }
    return net.fetch(pathToFileURL(filePath).toString());
  });
}

// =============================================================
// 画面 (renderer) からの依頼を受ける窓口
// =============================================================

// --- 設定 ---
ipcMain.handle("settings:get", () => loadSettings());
ipcMain.handle("settings:set", (_e, patch) => saveSettings(patch ?? {}));

// --- キャラクター設定 (人格) ---
ipcMain.handle("character:get", () => loadCharacter());

// --- VRM ファイルを選ぶダイアログ ---
ipcMain.handle("vrm:pick", async () => {
  const options = {
    title: "VRM ファイルを選ぶ",
    properties: ["openFile"],
    filters: [{ name: "VRM モデル", extensions: ["vrm", "glb"] }],
  };
  // 親ウィンドウを渡す形と渡さない形で引数の意味が変わるので、明示的に分ける
  const alive = win && !win.isDestroyed();
  const result = alive
    ? await dialog.showOpenDialog(win, options)
    : await dialog.showOpenDialog(options);
  if (result.canceled || result.filePaths.length === 0) return null;
  return result.filePaths[0];
});

// --- VRM ファイルの中身を読む (画面側で three.js に渡す) ---
ipcMain.handle("vrm:read", async (_e, filePath) => {
  try {
    if (typeof filePath !== "string" || filePath === "") {
      return { ok: false, reason: "empty" };
    }
    const data = await fs.promises.readFile(filePath);
    // Uint8Array にして渡す (Buffer のままだと画面側で扱いにくい)
    return { ok: true, path: filePath, data: new Uint8Array(data) };
  } catch (err) {
    return { ok: false, reason: err.code === "ENOENT" ? "missing" : "unreadable" };
  }
});

// -------------------------------------------------------------
// 脳 (LM Studio) との通信。
// 画面側から直接 fetch すると CORS で弾かれるので、ここで代行する。
// -------------------------------------------------------------
let cachedModel = null;
/** 一度でも思考 (reasoning) を返したモデルを覚えておき、次から枠を広く取る */
const knownReasoningModels = new Set();

async function detectModel() {
  const res = await fetch(`${LMSTUDIO}/v1/models`, {
    signal: AbortSignal.timeout(3000),
  });
  const data = await res.json();
  const id = data.data?.[0]?.id;
  if (!id) throw new Error("モデルがロードされていません");
  return id;
}

ipcMain.handle("chat:send", async (_e, messages) => {
  if (!Array.isArray(messages)) return { ok: false, kind: "bad-request" };
  try {
    if (!cachedModel) cachedModel = await detectModel();
  } catch {
    cachedModel = null;
    return { ok: false, kind: "no-lmstudio" };
  }

  const { extractReply, tokenBudget, describeReply } = await replyTools();
  const maxTokens = tokenBudget(cachedModel, knownReasoningModels.has(cachedModel));

  try {
    const res = await fetch(`${LMSTUDIO}/v1/chat/completions`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: cachedModel,
        messages,
        temperature: 0.8,
        // 考えるモデル (Gemma 4 など) は思考ぶんもここから食う。
        // 300 だと思考だけで使い切って本文が出ないため、大きめに取る
        max_tokens: maxTokens,
      }),
      signal: AbortSignal.timeout(180000),
    });
    if (!res.ok) {
      cachedModel = null;
      return { ok: false, kind: "server-error", status: res.status };
    }

    const data = await res.json();
    const info = extractReply(data);
    diag(`LLM: ${describeReply(info)} max_tokens=${maxTokens}`);

    // 思考するモデルだと分かったら覚えておく (次回から枠を広げる)
    if (info.thought) knownReasoningModels.add(cachedModel);

    if (info.reply === "") {
      // 無言で終わらせず、何が起きたのかを画面側に伝える
      return {
        ok: false,
        kind: info.thought ? "thinking-only" : "empty-reply",
        truncated: info.truncated,
      };
    }
    return {
      ok: true,
      reply: info.reply,
      source: info.source,
      truncated: info.truncated,
    };
  } catch (err) {
    cachedModel = null;
    return { ok: false, kind: err.name === "TimeoutError" ? "timeout" : "no-lmstudio" };
  }
});

// -------------------------------------------------------------
// 声 (VOICEVOX)。起動していなければ黙って諦める (テキストだけで動く)
// -------------------------------------------------------------
ipcMain.handle("voice:check", async () => {
  try {
    const res = await fetch(`${VOICEVOX}/version`, { signal: AbortSignal.timeout(1000) });
    return res.ok;
  } catch {
    return false;
  }
});

ipcMain.handle("voice:speak", async (_e, text) => {
  if (typeof text !== "string" || text.trim() === "") return null;
  const speaker = loadCharacter().voicevoxSpeaker ?? 3;
  try {
    const q = await fetch(
      `${VOICEVOX}/audio_query?speaker=${speaker}&text=${encodeURIComponent(text)}`,
      { method: "POST", signal: AbortSignal.timeout(10000) }
    );
    if (!q.ok) return null;
    const query = await q.json();
    const s = await fetch(`${VOICEVOX}/synthesis?speaker=${speaker}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(query),
      signal: AbortSignal.timeout(30000),
    });
    if (!s.ok) return null;
    return new Uint8Array(await s.arrayBuffer());
  } catch {
    return null;
  }
});

// -------------------------------------------------------------
// クリック透過の切り替え。
//
// ignore = true  … マウスの操作は下のウィンドウに素通りする
//          false … このウィンドウが操作を受け取る
//
// { forward: true } を付けると、素通りさせている間もマウスの移動だけは
// 画面側に届く。これが無いと「キャラの上に戻ってきた」ことを検知できない。
// forward は Windows と macOS のみ対応。Linux では透過を使わず常に受け取る。
// -------------------------------------------------------------
const SUPPORTS_PASSTHROUGH = process.platform === "win32" || process.platform === "darwin";

ipcMain.on("window:passthrough", (_e, ignore) => {
  if (!win || win.isDestroyed()) return;
  if (!SUPPORTS_PASSTHROUGH) {
    win.setIgnoreMouseEvents(false);
    return;
  }
  win.setIgnoreMouseEvents(!!ignore, { forward: true });
});

ipcMain.handle("window:capabilities", () => ({
  passthrough: SUPPORTS_PASSTHROUGH,
  platform: process.platform,
}));

// -------------------------------------------------------------
// ウィンドウのドラッグ移動。
//
// CSS の -webkit-app-region: drag は「キャラの形だけ掴む」ができないので使わない。
// 代わりに、掴んだ瞬間のカーソル位置とウィンドウ位置を覚えておき、
// カーソルの移動量そのぶんウィンドウを動かす。
// カーソル位置は main 側 (screen.getCursorScreenPoint) で読む方がぶれない。
// -------------------------------------------------------------
let dragTimer = null;

function stopDrag() {
  if (dragTimer) {
    clearInterval(dragTimer);
    dragTimer = null;
  }
  if (win && !win.isDestroyed()) saveSettings({ bounds: win.getBounds() });
}

ipcMain.on("window:drag-start", () => {
  if (!win || win.isDestroyed() || dragTimer) return;
  const start = screen.getCursorScreenPoint();
  const [originX, originY] = win.getPosition();
  dragTimer = setInterval(() => {
    if (!win || win.isDestroyed()) return stopDrag();
    const now = screen.getCursorScreenPoint();
    win.setPosition(originX + (now.x - start.x), originY + (now.y - start.y));
  }, 16);
});

ipcMain.on("window:drag-end", () => stopDrag());

// --- 診断 / 開発用 ---
ipcMain.handle("app:versions", () => collectVersions());
ipcMain.on("app:diag", (_e, line) => {
  if (typeof line === "string") diag(line);
});
ipcMain.on("app:devtools", () => openDevTools());

// --- その他 ---
ipcMain.on("window:quit", () => app.quit());
ipcMain.on("window:minimize", () => win && !win.isDestroyed() && win.minimize());

// =============================================================
// 起動
// =============================================================
// 二重起動を防ぐ (同じキャラが 2 体立たないように)
if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on("second-instance", () => {
    if (win && !win.isDestroyed()) {
      if (win.isMinimized()) win.restore();
      win.focus();
    }
  });

  app.whenReady().then(() => {
    const versions = collectVersions();
    diag(
      `起動: three ${versions.three} / @pixiv/three-vrm ${versions.threeVrm} / ` +
        `Electron ${versions.electron} (Chrome ${versions.chrome}) / ${versions.platform}`
    );
    diag("DevTools は F12 または Ctrl+Shift+I (Mac は ⌘+Shift+I)、右クリックメニューからも開けます");

    handleCompanionProtocol();
    createWindow();

    app.on("activate", () => {
      if (BrowserWindow.getAllWindows().length === 0) createWindow();
    });
  });

  app.on("window-all-closed", () => {
    // macOS でも終了させる (デスクトップに常駐するアプリなので、閉じたら消えてよい)
    app.quit();
  });

  app.on("before-quit", () => stopDrag());
}
