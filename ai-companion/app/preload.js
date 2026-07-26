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

  // --- ウィンドウ操作 ---
  getCapabilities: () => ipcRenderer.invoke("window:capabilities"),
  setPassthrough: (ignore) => ipcRenderer.send("window:passthrough", ignore),
  dragStart: () => ipcRenderer.send("window:drag-start"),
  dragEnd: () => ipcRenderer.send("window:drag-end"),
  minimize: () => ipcRenderer.send("window:minimize"),
  quit: () => ipcRenderer.send("window:quit"),
});
