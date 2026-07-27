// =============================================================
// Phase 3/4: VRM の表情をまぜる係
//
// 3 つの流れを 1 か所で足し合わせる:
//
//   ① 感情 (happy / sad / …)  … 会話の内容で決まる。0.25 秒でクロスフェード
//   ② 口の開き (aa)           … 声の音量で決まる (Phase 4)
//   ③ まばたき (blink)         … 感情とは無関係に、勝手に重なる
//
// 別々の場所で expressionManager.setValue を呼ぶと、あとから呼んだほうが
// 前の値を消してしまう (毎フレーム全部を入れ直すため)。
// そこで「今フレームの最終的な重み」をここで作り、まとめて 1 回だけ入れる。
//
// VRM 0.x / 1.0 の名前の違いもここで吸収する。three-vrm が旧名を新名へ
// 変換してくれる場合が多いが、変換しきれないモデルもあるので両方を当たる。
// =============================================================

/** 使う感情と、モデルに入っているかもしれない表情名 (先に見つかったほうを使う) */
export const EMOTION_EXPRESSIONS = {
  neutral: ["neutral"],
  happy: ["happy", "joy"], // joy は VRM 0.x の旧名
  angry: ["angry"],
  sad: ["sad", "sorrow"], // sorrow は VRM 0.x の旧名
  relaxed: ["relaxed", "fun"], // fun は VRM 0.x の旧名
  surprised: ["surprised", "surprise"],
};

/** 口の開き。VRM 1.0 は aa、VRM 0.x は a */
export const MOUTH_EXPRESSIONS = ["aa", "a"];
/** まばたき */
export const BLINK_EXPRESSIONS = ["blink", "blink_l"];

// --- 調整するならこのあたり ---------------------------------

/** 表情の切り替えにかける時間 (秒)。パッと変えず、ここでクロスフェードする */
export const EMOTION_FADE_SEC = 0.25;
/** 感情表情の最大の濃さ。1.0 だと顔が作りものっぽくなるモデルが多い */
export const EMOTION_MAX = 0.9;
/** 口の開きの上限。1.0 まで開くと大あくびになるので抑える */
export const MOUTH_MAX = 0.85;
/**
 * 口が開いている間、感情表情をどれだけ薄めるか。
 *
 * happy などの表情は口の形も一緒に動かすことが多く、リップシンクの aa と
 * 重なると口がねじれる。口が開いているぶんだけ感情側を譲る。
 * 0 にすると譲らない (表情優先)、1 にすると口が全開のとき感情が消える。
 */
export const EMOTION_DUCK_BY_MOUTH = 0.35;

export class ExpressionMixer {
  constructor() {
    /** 感情 → 実際に使う表情名 (モデルに無い感情は入らない) */
    this.resolved = new Map();
    /** モデルに定義が無くて諦めた感情 */
    this.missing = [];
    /** 感情 → いまの重み (0〜1)。クロスフェードの途中経過 */
    this.weights = new Map();
    /** 目指している感情 */
    this.target = "neutral";
    /** 口の開き (0〜1)。LipSync から毎フレーム入る */
    this.mouth = 0;
    /** まばたき (0〜1)。Stage の自動まばたきから入る */
    this.blink = 0;
    /** 実際に使う口・まばたきの表情名 (無ければ null) */
    this.mouthName = null;
    this.blinkName = null;
    /** @type {object|null} VRM の expressionManager */
    this.manager = null;
  }

  /**
   * VRM の expressionManager をつなぐ。
   * モデルに入っている表情を調べ、使えるものだけを覚える。
   * @param {object|null|undefined} manager vrm.expressionManager
   */
  bind(manager) {
    this.manager = manager ?? null;
    this.resolved = new Map();
    this.missing = [];
    this.weights = new Map();
    this.target = "neutral";
    this.mouth = 0;
    this.blink = 0;
    this.mouthName = null;
    this.blinkName = null;
    if (!manager) return;

    for (const [emotion, names] of Object.entries(EMOTION_EXPRESSIONS)) {
      const name = this.pick(names);
      // モデルに定義されていない表情は飛ばす (そのぶん neutral のままになる)
      if (name) this.resolved.set(emotion, name);
      else this.missing.push(emotion);
    }
    this.mouthName = this.pick(MOUTH_EXPRESSIONS);
    this.blinkName = this.pick(BLINK_EXPRESSIONS);
  }

  /** 候補の名前のうち、モデルに実在する最初のものを返す */
  pick(names) {
    const manager = this.manager;
    if (!manager) return null;
    for (const name of names) {
      const found = manager.getExpression?.(name) ?? manager.expressionMap?.[name];
      if (found) return name;
    }
    return null;
  }

  /** その感情がこのモデルで出せるか */
  supports(emotion) {
    return this.resolved.has(emotion);
  }

  /**
   * 目指す感情を変える (切り替えは update() が時間をかけて行う)。
   * 知らない感情・モデルに無い感情は neutral に落とす。
   * @param {string} emotion
   * @returns {string} 実際に採用した感情
   */
  setEmotion(emotion) {
    const next = this.resolved.has(emotion) ? emotion : "neutral";
    this.target = next;
    return next;
  }

  /** @param {number} level 口の開き 0〜1 */
  setMouth(level) {
    this.mouth = clamp01(level);
  }

  /** @param {number} weight まばたき 0〜1 */
  setBlink(weight) {
    this.blink = clamp01(weight);
  }

  /**
   * 毎フレーム呼ぶ。重みを進めて、VRM に入れる。
   * @param {number} delta 前フレームからの秒数
   */
  update(delta) {
    const step = EMOTION_FADE_SEC > 0 ? delta / EMOTION_FADE_SEC : 1;

    // 目標の感情は 1 へ、それ以外は 0 へ。同じ速さで動かすので入れ替わりが滑らか
    for (const emotion of this.resolved.keys()) {
      const goal = emotion === this.target ? 1 : 0;
      const now = this.weights.get(emotion) ?? 0;
      this.weights.set(emotion, approach(now, goal, step));
    }

    if (!this.manager) return;

    // 口が開いているぶん、感情表情を薄める (口の形の取り合いを避ける)
    const duck = 1 - EMOTION_DUCK_BY_MOUTH * this.mouth;
    for (const [emotion, name] of this.resolved) {
      const weight = (this.weights.get(emotion) ?? 0) * EMOTION_MAX * duck;
      this.manager.setValue(name, weight);
    }
    if (this.mouthName) this.manager.setValue(this.mouthName, this.mouth * MOUTH_MAX);
    // まばたきは感情と無関係に重ねる (笑いながらでも瞬きする)
    if (this.blinkName) this.manager.setValue(this.blinkName, this.blink);
  }

  /** 診断・テスト用に、いまの状態を数字で取り出す */
  snapshot() {
    const weights = {};
    for (const [emotion, name] of this.resolved) {
      weights[emotion] = round3((this.weights.get(emotion) ?? 0) * EMOTION_MAX);
    }
    return {
      target: this.target,
      weights,
      mouth: round3(this.mouth * MOUTH_MAX),
      blink: round3(this.blink),
      missing: this.missing.slice(),
      mouthName: this.mouthName,
      blinkName: this.blinkName,
    };
  }

  /** 診断ログ用の 1 行 */
  describe() {
    if (!this.manager) return "表情: モデルが読み込まれていません";
    const usable = [...this.resolved.entries()].map(([e, n]) => (e === n ? e : `${e}→${n}`));
    const lines = [
      `表情: 使える感情 ${usable.length}/${Object.keys(EMOTION_EXPRESSIONS).length} (${usable.join(", ") || "なし"})`,
      `  口 (リップシンク)=${this.mouthName ?? "なし"} / まばたき=${this.blinkName ?? "なし"}`,
    ];
    if (this.missing.length > 0) {
      lines.push(`  ※ このモデルに無い感情: ${this.missing.join(", ")} (neutral のままになります)`);
    }
    const s = this.snapshot();
    const live = Object.entries(s.weights)
      .map(([e, w]) => `${e}=${w}`)
      .join(" ");
    lines.push(`  いまの重み: ${live || "なし"} / 口=${s.mouth} / まばたき=${s.blink} (目標=${s.target})`);
    return lines.join("\n");
  }
}

/** 現在値を目標へ step だけ近づける (行き過ぎない) */
function approach(now, goal, step) {
  if (now === goal) return goal;
  const diff = goal - now;
  const move = Math.sign(diff) * Math.min(Math.abs(diff), Math.max(0, step));
  return clamp01(now + move);
}

function clamp01(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return 0;
  return n < 0 ? 0 : n > 1 ? 1 : n;
}

function round3(value) {
  return Math.round(value * 1000) / 1000;
}
