// =============================================================
// LLM の返事から「本文」を取り出す係 (chat.mjs と app/main.js の共用)
//
// なぜ必要か:
//   Gemma 4 や Qwen3 のような「考えてから答える」モデルは、
//   OpenAI 互換のレスポンスで本文の置き場所が一定しない。
//
//     パターン A: message.content に <think>…</think> 本文  が入る
//     パターン B: message.content は空文字で、思考が message.reasoning_content に入る
//     パターン C: 思考だけで max_tokens に達し、本文が生成されないまま終わる
//
//   素直に content を読むだけだと、A では思考がそのまま吹き出しに出て、
//   B と C では空っぽの返事になる。ここでその差を吸収する。
// =============================================================

/** 思考を包むタグとして実際に見かけるもの */
const THINK_TAGS = ["think", "thinking", "thought", "reason", "reasoning", "scratchpad"];

/** モデル名から「考えるモデル」らしさを見る (max_tokens を決めるのに使う) */
const REASONING_NAME =
  /(gemma-?[45]|qwen-?3|qwq|deepseek-?r1|magistral|glm-4\.[5-9]|exaone-deep|phi-4-reasoning|thinking|reasoner?|o[134]-(mini|preview))/i;

/**
 * 思考タグを取り除いて本文だけにする。
 *
 * 閉じタグだけ / 開きタグだけ、という壊れた出力も来るので、そこも面倒を見る。
 * @param {unknown} text
 * @returns {string}
 */
export function stripThinking(text) {
  if (typeof text !== "string") return "";
  let out = text;

  for (const tag of THINK_TAGS) {
    // 1. <think> … </think> が揃っている場合: まるごと落とす
    out = out.replace(new RegExp(`<${tag}\\b[^>]*>[\\s\\S]*?</${tag}>`, "gi"), "");

    // 2. 閉じタグだけがある場合: そこまでが思考なので、後ろだけ残す
    const close = new RegExp(`</${tag}\\s*>`, "i");
    if (close.test(out)) out = out.slice(out.search(close)).replace(close, "");

    // 3. 開きタグだけがある場合: 途中で打ち切られている。以降はすべて思考
    const open = new RegExp(`<${tag}\\b[^>]*>`, "i");
    if (open.test(out)) out = out.slice(0, out.search(open));
  }

  return out.trim();
}

/** モデル名から、考えるモデルらしいかを判定する */
export function looksLikeReasoningModel(modelId) {
  return typeof modelId === "string" && REASONING_NAME.test(modelId);
}

/** 最初に見つかった「中身のある文字列」を返す */
function firstText(...candidates) {
  for (const value of candidates) {
    if (typeof value === "string" && value.trim() !== "") return value;
  }
  return "";
}

/**
 * OpenAI 互換のレスポンスから本文を取り出す。
 *
 * @param {any} data /v1/chat/completions のレスポンス (JSON)
 * @returns {{
 *   reply: string,           取り出せた本文 (取れなければ空文字)
 *   source: "content" | "reasoning" | "none",  どこから取ったか
 *   truncated: boolean,      長さの上限で切られたか
 *   finishReason: string|null,
 *   model: string|null,
 *   contentLength: number,   生の content の長さ
 *   reasoningLength: number, 思考側の長さ
 *   thought: boolean,        思考の痕跡があったか
 * }}
 */
export function extractReply(data) {
  const choice = data?.choices?.[0] ?? {};
  const message = choice.message ?? {};

  const rawContent = typeof message.content === "string" ? message.content : "";
  // 置き場所は実装によって違う。よく見かける名前をひととおり当たる
  const rawReasoning = firstText(
    message.reasoning_content,
    message.reasoning,
    message.thinking,
    choice.reasoning_content,
    choice.reasoning
  );

  const finishReason = choice.finish_reason ?? null;
  const info = {
    reply: "",
    source: "none",
    truncated: finishReason === "length",
    finishReason,
    model: typeof data?.model === "string" ? data.model : null,
    contentLength: rawContent.length,
    reasoningLength: rawReasoning.length,
    thought: rawReasoning !== "" || /<\/?(think|thinking|thought)\b/i.test(rawContent),
  };

  // まず content。思考タグが混ざっていれば剥がす
  const fromContent = stripThinking(rawContent);
  if (fromContent !== "") {
    info.reply = fromContent;
    info.source = "content";
    return info;
  }

  // content が空だった。思考側に本文が入っているパターン
  const fromReasoning = stripThinking(rawReasoning);
  if (fromReasoning !== "") {
    info.reply = fromReasoning;
    info.source = "reasoning";
    return info;
  }

  return info; // 本文なし (思考だけで終わった / そもそも空)
}

/**
 * そのモデルに渡す max_tokens を決める。
 * 考えるモデルは思考ぶんを別に食うので、多めに積む。
 * @param {string|null} modelId
 * @param {boolean} knownReasoning 前回の返事で思考が確認できているか
 */
export function tokenBudget(modelId, knownReasoning = false) {
  return knownReasoning || looksLikeReasoningModel(modelId) ? 2048 : 1024;
}

/** 診断ログ用の 1 行にまとめる */
export function describeReply(info) {
  return (
    `model=${info.model ?? "?"} finish_reason=${info.finishReason ?? "?"} ` +
    `content=${info.contentLength}文字 reasoning=${info.reasoningLength}文字 ` +
    `本文の取り出し元=${info.source}${info.truncated ? " ※長さ上限で打ち切り" : ""}`
  );
}
