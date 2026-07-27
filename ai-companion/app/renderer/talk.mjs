// =============================================================
// 会話まわり (吹き出し・LM Studio への送信・VOICEVOX の再生)
//
// 通信そのものは main.js が代行する。ここは「何を出すか」だけを持つ。
// 会話の流儀 (人格・履歴の長さ) は chat.mjs と揃えてある。
//
// Phase 3/4 でここに増えた仕事:
//   - 返事に付いてきた感情を Stage に渡して、表情を切り替える
//   - VOICEVOX の音声を LipSync に渡して、口を動かす
//     (声が返らなかったときは、本文を渡して擬似口パクにする)
// =============================================================

const api = window.companion;

/** 吹き出しを自動で消すまでの時間 (文字数に応じて伸ばす) */
function hideDelay(text) {
  return Math.min(20000, 3500 + text.length * 110);
}

/** つながらないときの案内文。日本語で手順まで書く */
const TROUBLE = {
  "no-lmstudio":
    "LM Studio につながりませんでした。\n\n" +
    "1. LM Studio を起動して、モデルをロードする\n" +
    "2. 「Developer」タブで Start Server を押す (localhost:1234)\n\n" +
    "を確かめてから、もう一度話しかけてください。",
  timeout:
    "返事に時間がかかりすぎたので、いったん待つのをやめました。\n" +
    "モデルが大きすぎないか確かめて、もう一度話しかけてください。",
  "server-error":
    "LM Studio がエラーを返しました。\n" +
    "モデルがロードされているか、Developer タブで確かめてください。",
  "empty-reply": "返事が空っぽで返ってきました。もう一度話しかけてみてください。",
  "bad-request": "うまく送れませんでした。もう一度話しかけてみてください。",
  // Gemma 4 や Qwen3 のような「考えてから答える」モデルで起きる。
  // 思考だけで長さの上限に達し、本文が出ないまま終わった状態
  "thinking-only":
    "モデルが考えるだけで終わってしまいました (本文が返ってきていません)。\n\n" +
    "・もう一度、短めに話しかけてみてください\n" +
    "・LM Studio 側で thinking / reasoning を切れるモデルなら切ってみてください\n" +
    "・それでも続くなら、端末に出ている [診断] LLM: の行を控えてください",
};

/** finish_reason が length のときに末尾へ足す注記 */
const TRUNCATED_NOTE = "\n\n(※ 長さの上限に達したため、途中で切れています)";

export class Talk {
  /**
   * @param {object} options
   * @param {HTMLElement} options.bubble 吹き出しの要素
   * @param {object} options.character character.json の中身
   * @param {import("./stage.mjs").Stage} options.stage 表情を入れる先
   * @param {import("./lipsync.mjs").LipSync} options.lipSync 口を動かす係
   */
  constructor({ bubble, character, stage, lipSync }) {
    this.bubble = bubble;
    this.character = character;
    this.stage = stage;
    this.lipSync = lipSync;
    this.messages = [{ role: "system", content: character.systemPrompt ?? "" }];
    this.hideTimer = null;
    this.busy = false;
    /** いま表情に反映している返事の番号 (後追い判定が古い返事を上書きしないように) */
    this.emotionId = 0;
  }

  // -----------------------------------------------------------
  // 吹き出し
  // -----------------------------------------------------------
  /**
   * @param {string} text 出す文章
   * @param {object} [options]
   * @param {"normal"|"thinking"|"trouble"} [options.kind] 見た目の種類
   * @param {boolean} [options.keep] 自動で消さない
   */
  show(text, { kind = "normal", keep = false } = {}) {
    clearTimeout(this.hideTimer);
    // LLM の返事は何が入っているか分からないので、必ず textContent で入れる
    this.bubble.textContent = text;
    this.bubble.classList.remove("hidden", "thinking", "trouble");
    if (kind !== "normal") this.bubble.classList.add(kind);
    if (!keep) {
      this.hideTimer = setTimeout(() => this.hide(), hideDelay(text));
    }
  }

  hide() {
    clearTimeout(this.hideTimer);
    this.bubble.classList.add("hidden");
  }

  // -----------------------------------------------------------
  // 送信 → 返事 → 声
  // -----------------------------------------------------------
  /** @param {string} text ユーザーが打った文章 */
  async send(text) {
    const input = text.trim();
    if (input === "" || this.busy) return;
    this.busy = true;
    this.show("……", { kind: "thinking", keep: true });

    this.messages.push({ role: "user", content: input });

    let result;
    try {
      result = await api.chat(this.messages);
    } catch {
      result = { ok: false, kind: "no-lmstudio" };
    }

    if (!result?.ok) {
      // 失敗した発言は履歴に残さない (次に話しかけたとき二重にならないように)
      this.messages.pop();
      this.busy = false;
      const guide = TROUBLE[result?.kind] ?? TROUBLE["no-lmstudio"];
      this.show(result?.truncated ? guide + TRUNCATED_NOTE : guide, {
        kind: "trouble",
        keep: true,
      });
      return;
    }

    const reply = result.reply;
    // 履歴に積むのは、感情タグが付いたままの生の返事 (main.js の raw)。
    // タグを外したものを積むと、モデルが「タグは要らない」と思って付けなくなる
    this.messages.push({ role: "assistant", content: result.raw ?? reply });
    // 履歴が伸びすぎたら古いものから忘れる (system は残す)。chat.mjs と同じ
    if (this.messages.length > 41) this.messages.splice(1, 2);

    // 表情を先に切り替えてから吹き出しを出す (0.25 秒かけて変わる)
    this.applyEmotion(result.emotion, result.emotionId);

    // 途中で切れた場合は、黙って見せずにその旨を添える
    this.show(result.truncated ? reply + TRUNCATED_NOTE : reply);
    this.busy = false;

    // VOICEVOX が起動していれば声が返る。いなければ null が返るだけ
    // (注記は読ませない。読ませるのは本文だけ)
    this.playVoice(reply);
  }

  // -----------------------------------------------------------
  // 表情 (Phase 3)
  // -----------------------------------------------------------
  /**
   * 感情を表情に反映する。
   * @param {string} emotion
   * @param {number} [id] 何回目の返事か (後追い判定の取り違えを防ぐ)
   */
  applyEmotion(emotion, id) {
    if (typeof id === "number") this.emotionId = id;
    const wanted = emotion ?? "neutral";
    const used = this.stage?.setEmotion(wanted) ?? "neutral";
    if (used !== wanted) {
      api.diag(`感情: ${wanted} はこのモデルに定義が無いので neutral にしました`);
    }
  }

  /**
   * main 側の後追い判定 (JSON 方式) が返ってきたときに呼ばれる。
   * すでに次の返事に進んでいたら無視する。
   * @param {{id: number, emotion: string}} payload
   */
  onEmotionUpdate(payload) {
    if (!payload || payload.id !== this.emotionId) return;
    this.applyEmotion(payload.emotion);
  }

  // -----------------------------------------------------------
  // 声と口 (Phase 4)
  //
  // 音声の再生は LipSync に任せる。AnalyserNode を挟んで音量を測るため。
  // 声が返らなくても、本文の長さから擬似的に口を動かす。
  // -----------------------------------------------------------
  /** @param {string} text */
  async playVoice(text) {
    let wav = null;
    try {
      wav = await api.speak(text);
    } catch {
      wav = null; // 声が出せなくても、口だけは動かす
    }
    if (!this.lipSync) return;
    const report = await this.lipSync.speak(wav, text);
    api.diag(
      `口パク: 駆動源=${report.driver === "voice" ? "実音声 (AnalyserNode)" : "擬似 (テキスト長)"} ` +
        `— ${report.detail}`
    );
  }
}
