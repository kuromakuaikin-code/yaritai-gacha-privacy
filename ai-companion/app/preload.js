// =============================================================
// preload: 画面 (renderer) と Electron 本体 (main) をつなぐ窓口
//
// 画面側には Node.js の機能をそのまま渡さず、ここで用意した関数だけを
// window.companion として公開する (contextIsolation: true)。
// =============================================================
const { contextBridge, ipcRenderer, webUtils } = require("electron");

contextBridge.exposeInMainWorld("companion", {
  // --- 設定 ---
  getSettings: () => ipcRenderer.invoke("settings:get"),
  saveSettings: (patch) => ipcRenderer.invoke("settings:set", patch),

  // --- キャラクター設定 (人格) ---
  getCharacter: () => ipcRenderer.invoke("character:get"),

  // --- VRM ---
  pickVrm: () => ipcRenderer.invoke("vrm:pick"),
  readVrm: (filePath) => ipcRenderer.invoke("vrm:read", filePath),

  /**
   * ドラッグ＆ドロップされた File から、実ファイルの場所を取り出す。
   * 新しい Electron では File.path が使えないので webUtils を使う。
   */
  pathOf: (file) => {
    try {
      return webUtils.getPathForFile(file);
    } catch {
      return file?.path ?? "";
    }
  },

  // --- 会話 (LM Studio) と声 (VOICEVOX) ---
  chat: (messages) => ipcRenderer.invoke("chat:send", messages),
  hasVoice: () => ipcRenderer.invoke("voice:check"),
  speak: (text) => ipcRenderer.invoke("voice:speak", text),

  /**
   * 感情の後追い判定 (Phase 3) の結果を受け取る。
   * 返事にタグが付いていなかったとき、main 側が JSON 方式で判定し直して
   * 少し遅れて送ってくる。{ id, emotion } が届く
   */
  onEmotion: (callback) =>
    ipcRenderer.on("emotion:update", (_event, payload) => callback(payload)),

  // --- ウィンドウ操作 ---
  getCapabilities: () => ipcRenderer.invoke("window:capabilities"),
  setPassthrough: (ignore) => ipcRenderer.send("window:passthrough", ignore),
  dragStart: () => ipcRenderer.send("window:drag-start"),
  dragEnd: () => ipcRenderer.send("window:drag-end"),
  minimize: () => ipcRenderer.send("window:minimize"),
  quit: () => ipcRenderer.send("window:quit"),

  // --- 診断 / 開発用 ---
  /** three などの版を取る (診断ログに出す) */
  getVersions: () => ipcRenderer.invoke("app:versions"),
  /** npm start した端末に 1 行出す (画面側の console は DevTools にしか出ないため) */
  diag: (line) => ipcRenderer.send("app:diag", line),
  /** DevTools の開閉 */
  openDevTools: () => ipcRenderer.send("app:devtools"),
});
