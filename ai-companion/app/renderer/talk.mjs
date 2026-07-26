// =============================================================
// 会話まわり (吹き出し・LM Studio への送信・VOICEVOX の再生)
//
// 通信そのものは main.js が代行する。ここは「何を出すか」だけを持つ。
// 会話の流儀 (人格・履歴の長さ) は chat.mjs と揃えてある。
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
   */
  constructor({ bubble, character }) {
    this.bubble = bubble;
    this.character = character;
    this.messages = [{ role: "system", content: character.systemPrompt ?? "" }];
    this.hideTimer = null;
    this.audio = null;
    this.busy = false;
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
    this.messages.push({ role: "assistant", content: reply });
    // 履歴が伸びすぎたら古いものから忘れる (system は残す)。chat.mjs と同じ
    if (this.messages.length > 41) this.messages.splice(1, 2);

    // 途中で切れた場合は、黙って見せずにその旨を添える
    this.show(result.truncated ? reply + TRUNCATED_NOTE : reply);
    this.busy = false;

    // VOICEVOX が起動していれば声が返る。いなければ null が返るだけ
    // (注記は読ませない。読ませるのは本文だけ)
    this.playVoice(reply);
  }

  /** @param {string} text */
  async playVoice(text) {
    let wav;
    try {
      wav = await api.speak(text);
    } catch {
      return;
    }
    if (!wav || wav.length === 0) return;

    // 前の声が残っていたら止める
    if (this.audio) {
      this.audio.pause();
      URL.revokeObjectURL(this.audio.src);
      this.audio = null;
    }

    const url = URL.createObjectURL(new Blob([wav], { type: "audio/wav" }));
    const audio = new Audio(url);
    this.audio = audio;
    audio.addEventListener("ended", () => {
      URL.revokeObjectURL(url);
      if (this.audio === audio) this.audio = null;
    });
    audio.play().catch(() => {
      URL.revokeObjectURL(url);
    });
  }
}
