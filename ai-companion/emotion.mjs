// =============================================================
// Phase 3: 返事から「感情」を取り出す係 (chat.mjs と app/main.js の共用)
//
// なぜ必要か:
//   ローカルの小型モデル (Gemma 4 など) は、JSON を返せと言っても
//   前置きを付けたり、コードブロックで包んだり、思考の途中で止まったりする。
//   「返事そのものが壊れる」やり方は避けたい。
//
//   そこで主軸は【感情タグ】方式にした。
//
//     返事: "[happy] やったね、うまくいったよ。"
//              ↑ これを正規表現で剥がして、本文と感情に分ける
//
//   この方式の良いところは、失敗したときの壊れ方が軽いこと。
//   タグが無ければ感情が neutral になるだけで、本文はそのまま読める。
//   JSON を強制する方式は、外し方を間違えると返事ごと読めなくなる。
//
//   LM Studio の Structured Output (JSON Schema 強制) は、
//   「タグが取れなかったとき」の後追い判定にだけ使う (app/main.js を参照)。
//   そちらの下ごしらえ (スキーマと、緩い JSON の読み取り) もここに置く。
// =============================================================

/** 使う感情。VRM 1.0 の表情プリセット名にそのまま合わせてある */
export const EMOTIONS = ["neutral", "happy", "angry", "sad", "relaxed", "surprised"];

/**
 * 表記ゆれの吸収表 (すべて小文字で引く)。
 *
 * - VRM 0.x の旧名 (joy / sorrow / fun) を新名に寄せる
 * - モデルが英語の別語や日本語で書いてくることがあるので、よく出るものを拾う
 */
const ALIASES = {
  neutral: ["neutral", "normal", "none", "plain", "普通", "平常", "ふつう"],
  happy: ["happy", "joy", "joyful", "smile", "glad", "excited", "嬉しい", "うれしい", "喜び", "笑顔"],
  angry: ["angry", "anger", "mad", "annoyed", "怒り", "怒", "おこ", "むっ"],
  sad: ["sad", "sorrow", "sadness", "cry", "down", "悲しい", "悲しみ", "しょんぼり"],
  relaxed: ["relaxed", "relax", "fun", "calm", "relief", "peaceful", "安心", "落ち着き", "リラックス"],
  surprised: ["surprised", "surprise", "shocked", "shock", "驚き", "びっくり", "驚"],
};

/** 別名 → 正式名 の逆引き表 */
const ALIAS_TO_EMOTION = new Map();
for (const [emotion, words] of Object.entries(ALIASES)) {
  for (const word of words) ALIAS_TO_EMOTION.set(word, emotion);
}

/** タグに使われる括弧。全角も受ける (日本語入力のモデルは全角を混ぜてくる) */
const OPEN = "\\[［【（(＜<";
const CLOSE = "\\]］】）)＞>";
/** タグの中身として許す文字 (英数字と日本語。長い文はタグではないので 12 文字まで) */
const WORD = "[A-Za-z0-9_ぁ-んァ-ヶ一-龥ー]{1,12}";

/** 先頭の [happy] 形式 */
const HEAD_TAG = new RegExp(`^[\\s\\u3000]*[${OPEN}]\\s*(${WORD})\\s*[${CLOSE}][\\s\\u3000:：、，,]*`);
/** 先頭が括弧なしで「happy」だけの行になっている形式 */
const HEAD_BARE = new RegExp(`^[\\s\\u3000]*(${WORD})[\\s\\u3000]*[:：]?[\\s\\u3000]*\\n`);
/** 末尾に付けてくる場合 */
const TAIL_TAG = new RegExp(`[\\s\\u3000]*[${OPEN}]\\s*(${WORD})\\s*[${CLOSE}][\\s\\u3000]*$`);

/**
 * 感情らしき単語を、使う 6 種のどれかに正規化する。
 * 心当たりが無ければ null (＝タグとして扱わない)。
 * @param {unknown} word
 * @returns {string|null}
 */
export function normalizeEmotion(word) {
  if (typeof word !== "string") return null;
  const key = word.trim().toLowerCase();
  if (key === "") return null;
  return ALIAS_TO_EMOTION.get(key) ?? null;
}

/**
 * 返事を「本文」と「感情」に分ける。
 *
 * 大事なのは、**知らない単語のタグは剥がさない**こと。
 * 「(笑)」「(ため息)」で始まる返事を、タグと誤解して食べてしまわないように、
 * normalizeEmotion が通ったときだけ切り落とす。
 *
 * @param {unknown} text LLM が返した本文
 * @returns {{ text: string, emotion: string, source: "tag" | "none" }}
 */
export function splitEmotion(text) {
  if (typeof text !== "string") return { text: "", emotion: "neutral", source: "none" };

  let body = text;
  let found = null;

  // 1. 先頭の [happy] 形式
  const head = body.match(HEAD_TAG);
  if (head) {
    const emotion = normalizeEmotion(head[1]);
    if (emotion) {
      found = emotion;
      body = body.slice(head[0].length);
    }
  }

  // 2. 括弧を忘れて「happy」だけの行にしてくることがある
  if (!found) {
    const bare = body.match(HEAD_BARE);
    if (bare) {
      const emotion = normalizeEmotion(bare[1]);
      if (emotion) {
        found = emotion;
        body = body.slice(bare[0].length);
      }
    }
  }

  // 3. 末尾に付けてくることもある (先頭で見つかっていても、残っていれば落とす)
  const tail = body.match(TAIL_TAG);
  if (tail) {
    const emotion = normalizeEmotion(tail[1]);
    if (emotion) {
      if (!found) found = emotion;
      body = body.slice(0, body.length - tail[0].length);
    }
  }

  return {
    text: body.trim(),
    emotion: found ?? "neutral",
    source: found ? "tag" : "none",
  };
}

/**
 * システムプロンプトに足す、感情タグの指示。
 *
 * character.json にはあえて書かない。ユーザーが systemPrompt を自由に
 * 書き換えても表情が動かなくならないよう、コード側で自動的に足す方針にした
 * (キャラ設定の可搬性を優先する。既に自分で書いている人の指示は上書きしない)。
 */
export const EMOTION_GUIDE =
  "返事の先頭に、そのときの気持ちを表す感情タグを 1 つだけ付けてください。\n" +
  `使えるタグ: ${EMOTIONS.map((e) => `[${e}]`).join(" ")}\n` +
  "例: [happy] やったね、うまくいったよ。\n" +
  "半角の [ ] で囲んでタグを書き、そのあとに本文を続けてください。" +
  "本文の中にタグを書いたり、タグの説明をしたりしないでください。";

/** すでにユーザーが自分で感情タグの指示を書いているか */
function hasOwnGuide(prompt) {
  return typeof prompt === "string" && (/感情タグ/.test(prompt) || /\[(happy|neutral)\]/i.test(prompt));
}

/**
 * システムプロンプトに感情タグの指示を足す。
 * すでに自分で書いている人のプロンプトには触らない。
 * @param {string} systemPrompt
 * @returns {string}
 */
export function withEmotionGuide(systemPrompt) {
  const base = typeof systemPrompt === "string" ? systemPrompt : "";
  if (hasOwnGuide(base)) return base;
  return base.trim() === "" ? EMOTION_GUIDE : `${base.trim()}\n\n${EMOTION_GUIDE}`;
}

/**
 * messages 配列の system メッセージにだけ、感情タグの指示を足したものを返す。
 * 元の配列は書き換えない。system が無ければ先頭に足す。
 * @param {Array<{role: string, content: string}>} messages
 */
export function messagesWithEmotionGuide(messages) {
  if (!Array.isArray(messages)) return messages;
  const index = messages.findIndex((m) => m?.role === "system");
  if (index < 0) return [{ role: "system", content: EMOTION_GUIDE }, ...messages];
  const copy = messages.slice();
  copy[index] = { ...copy[index], content: withEmotionGuide(copy[index].content) };
  return copy;
}

// -------------------------------------------------------------
// もう一方のやり方: LM Studio の Structured Output (JSON Schema 強制)
//
// 主軸にはしない (理由はファイル冒頭)。タグが取れなかったときに、
// 「この返事の感情は何か」だけを別便で聞き直すのに使う。
// 本文の生成とは切り離してあるので、失敗しても会話は壊れない。
// -------------------------------------------------------------

/** Structured Output に渡すスキーマ (LM Studio / OpenAI 互換) */
export const EMOTION_JSON_SCHEMA = {
  name: "emotion",
  strict: true,
  schema: {
    type: "object",
    properties: {
      emotion: { type: "string", enum: EMOTIONS },
    },
    required: ["emotion"],
    additionalProperties: false,
  },
};

/** 感情だけを聞き直すときの指示文 */
export const EMOTION_CLASSIFY_PROMPT =
  "次のセリフを言っているキャラクターの気持ちに、いちばん近いものを 1 つ選んでください。\n" +
  `選べるのは ${EMOTIONS.join(" / ")} だけです。JSON で答えてください。`;

/**
 * 感情判定の返事 (JSON のはず) から感情を取り出す。
 *
 * JSON Schema を強制していても、コードブロックで包む・前置きを足すモデルがいる。
 * 素直な JSON.parse → 部分抜き出し → 単語探し、の順に緩めていく。
 *
 * @param {unknown} text
 * @returns {string|null}
 */
export function emotionFromJsonText(text) {
  if (typeof text !== "string" || text.trim() === "") return null;

  // 1. そのまま JSON として読めるか (```json で包まれている場合も剥がす)
  const unfenced = text.replace(/```(?:json)?/gi, "").trim();
  try {
    const parsed = JSON.parse(unfenced);
    const emotion = normalizeEmotion(parsed?.emotion ?? parsed?.感情);
    if (emotion) return emotion;
  } catch {
    /* JSON として読めなかった。下でもっと緩く探す */
  }

  // 2. "emotion": "happy" の形だけを拾う
  const pair = unfenced.match(/"?emotion"?\s*[:=]\s*"?([A-Za-z]+)"?/i);
  const fromPair = normalizeEmotion(pair?.[1]);
  if (fromPair) return fromPair;

  // 3. 知っている感情の単語が 1 つでも出ていれば、それを採る
  for (const word of unfenced.toLowerCase().split(/[^a-z一-龥ぁ-んァ-ヶー]+/)) {
    const emotion = normalizeEmotion(word);
    if (emotion) return emotion;
  }
  return null;
}
