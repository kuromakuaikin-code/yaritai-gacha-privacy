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
// ウィンドウ
// -------------------------------------------------------------
/** @type {BrowserWindow | null} */
let win = null;

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
  try {
    const res = await fetch(`${LMSTUDIO}/v1/chat/completions`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: cachedModel,
        messages,
        temperature: 0.8,
        max_tokens: 300,
      }),
      signal: AbortSignal.timeout(120000),
    });
    if (!res.ok) {
      cachedModel = null;
      return { ok: false, kind: "server-error", status: res.status };
    }
    const data = await res.json();
    const reply = data.choices?.[0]?.message?.content?.trim();
    if (!reply) return { ok: false, kind: "empty-reply" };
    return { ok: true, reply };
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
