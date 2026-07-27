// =============================================================
// Phase 4: 口パク (音量ベースのリップシンク)
//
// 何をしているか:
//   VOICEVOX の音声を WebAudio で鳴らし、その途中に AnalyserNode を挟んで
//   「いま鳴っている音の大きさ」を毎フレーム測る。それを口 (aa) の重みにする。
//   音素 (あいうえお) の判別まではしない。音量だけでも、しゃべっている感じは出る。
//
//        wav → AudioBufferSourceNode → AnalyserNode → スピーカー
//                                          ↓
//                                   音量 → 口の開き
//
//   声が出せない環境 (VOICEVOX 未起動) では、返事の文字数から
//   それらしい口パクを組み立てて動かす。無言の棒立ちにはしない。
//
// 音量をそのまま口の開きにすると、機械的にカクカクする。
//   - 開くのは速く、閉じるのはゆっくり (人の口はゆっくり閉じる)
//   - 小さすぎる音は無音として口を閉じる (息や無音区間で口が震えるのを防ぐ)
//   - 上限で頭打ちにする (大あくびにしない)
// の 3 つを入れてある。調整はこのファイル上部の定数で行う。
// =============================================================

// --- 調整するならこのあたり ---------------------------------

/** 口が開くときの追従の速さ (秒)。小さいほど機敏 */
export const MOUTH_ATTACK_SEC = 0.04;
/** 口が閉じるときの追従の速さ (秒)。開くときより遅くするのが自然 */
export const MOUTH_RELEASE_SEC = 0.13;
/** これ以下の音量は無音とみなす (息づかいで口が震えるのを防ぐ) */
export const MOUTH_GATE = 0.015;
/** 音量 (RMS) から口の開きへの倍率。声が小さくて口が動かないならここを上げる */
export const MOUTH_GAIN = 4.5;

/** 擬似口パク: 1 文字あたりの長さ (秒) */
export const PSEUDO_CHAR_SEC = 0.105;
/** 擬似口パク: 句読点で置く間 (秒) */
export const PSEUDO_PAUSE_SEC = 0.22;
/** 擬似口パク: どれだけ長い返事でも、口パクはここで打ち切る (秒) */
export const PSEUDO_MAX_SEC = 12;

/** 擬似口パクで口を閉じる文字 (句読点・記号・空白) */
const SILENT_CHARS = /[\s　、。，．,.!?！？…「」『』（）()【】・:：;；~〜ー―\-]/;

// -------------------------------------------------------------
// ここから下の 3 つは、ブラウザの機能を使わない純粋な計算。
// GUI の無い環境でも数値で検証できるように、あえて切り出してある
// (npm run check がここを直接テストしている)。
// -------------------------------------------------------------

/**
 * 音量 (RMS 0〜1) を口の開き (0〜1) に変える。
 * @param {number} rms
 */
export function levelFromRms(rms) {
  const value = Number(rms);
  if (!Number.isFinite(value) || value <= MOUTH_GATE) return 0;
  // 0.8 乗しているのは、小さい音でも口が見えるようにするため (耳の感じ方に寄せる)
  return Math.min(1, Math.pow((value - MOUTH_GATE) * MOUTH_GAIN, 0.8));
}

/**
 * 今の口の開きを、目標へ少しだけ近づける。
 * 開くとき (target > current) は速く、閉じるときはゆっくり。
 * @param {number} current
 * @param {number} target
 * @param {number} delta 秒
 */
export function smoothMouth(current, target, delta) {
  const tau = target > current ? MOUTH_ATTACK_SEC : MOUTH_RELEASE_SEC;
  const k = 1 - Math.exp(-Math.max(0, delta) / Math.max(1e-4, tau));
  const next = current + (target - current) * k;
  return next < 0 ? 0 : next > 1 ? 1 : next;
}

/**
 * 返事のテキストから、擬似口パクの譜面を作る。
 *
 * 1 文字ずつに枠を割り当て、句読点のところは口を閉じて間を置く。
 * 開き具合は文字ごとに少しずつ変える (同じ形の繰り返しに見えないように)。
 * 同じ文章なら必ず同じ譜面になる (乱数を使わないので、テストで検証できる)。
 *
 * @param {string} text
 * @returns {{ slots: Array<{start:number, end:number, peak:number}>, duration: number }}
 */
export function buildPseudoScore(text) {
  const source = typeof text === "string" ? text : "";
  const slots = [];
  let time = 0;
  for (const char of source) {
    if (time >= PSEUDO_MAX_SEC) break;
    if (SILENT_CHARS.test(char)) {
      time += PSEUDO_PAUSE_SEC;
      continue;
    }
    // 文字コードから決まる 0.55〜1.0 の高さ (黄金比を使った散らし方)
    const jitter = (char.codePointAt(0) * 0.6180339887) % 1;
    const peak = 0.55 + 0.45 * jitter;
    slots.push({ start: time, end: time + PSEUDO_CHAR_SEC, peak });
    time += PSEUDO_CHAR_SEC;
  }
  return { slots, duration: Math.min(time, PSEUDO_MAX_SEC) };
}

/**
 * 譜面の時刻 t における口の開き (0〜1)。
 * @param {{slots: Array<{start:number,end:number,peak:number}>}} score
 * @param {number} t 秒
 */
export function pseudoLevelAt(score, t) {
  if (!score || !Array.isArray(score.slots)) return 0;
  for (const slot of score.slots) {
    if (t < slot.start) return 0; // まだ次の文字が来ていない (＝間)
    if (t <= slot.end) {
      const u = (t - slot.start) / Math.max(1e-6, slot.end - slot.start);
      // 山なりに開いて閉じる。完全には閉じきらせない (単語の途中で口が閉じないように)
      return slot.peak * (0.55 + 0.45 * Math.sin(Math.PI * u));
    }
  }
  return 0;
}

// -------------------------------------------------------------
// 本体
// -------------------------------------------------------------
export class LipSync {
  /** @param {(line: string) => void} [diag] 診断ログの送り先 */
  constructor(diag) {
    this.diag = typeof diag === "function" ? diag : () => {};
    /** いまの口の開き (0〜1)。Stage がこれを表情に入れる */
    this.value = 0;
    /**
     * いま何で口を動かしているか。診断ログに出す
     *   "voice"   … 実際の音声の音量 (AnalyserNode)
     *   "pseudo"  … テキストから作った擬似口パク
     *   "none"    … 動かしていない
     */
    this.driver = "none";

    /** @type {AudioContext|null} */
    this.ctx = null;
    /** @type {AnalyserNode|null} */
    this.analyser = null;
    /** @type {AudioBufferSourceNode|null} */
    this.source = null;
    /** @type {Uint8Array|null} 波形の読み取り先 (毎フレーム作り直さない) */
    this.samples = null;
    /** @type {HTMLAudioElement|null} WebAudio が使えなかったときの保険 */
    this.element = null;

    /** 擬似口パクの譜面と、始めた時刻 */
    this.score = null;
    this.pseudoAt = 0;

    /** WebAudio が使えないと分かったら、二度と試さない */
    this.audioBroken = false;
  }

  /** AudioContext を用意する (最初に音を鳴らすときだけ作る) */
  ensureContext() {
    if (this.ctx) return this.ctx;
    const Ctor = window.AudioContext ?? window.webkitAudioContext;
    if (!Ctor) return null;
    this.ctx = new Ctor();
    return this.ctx;
  }

  /**
   * 自動再生の制限で止まっている AudioContext を起こす。
   * 画面のどこかを触った時に呼ぶ (ブラウザは操作なしの再生を止めるため)。
   */
  resume() {
    if (this.ctx && this.ctx.state === "suspended") this.ctx.resume().catch(() => {});
  }

  /**
   * 返事をしゃべらせる。
   *
   * @param {Uint8Array|null} wav VOICEVOX の音声 (無ければ null)
   * @param {string} text 返事の本文 (声が無いときの擬似口パクに使う)
   * @returns {Promise<{driver: string, detail: string}>} 診断用
   */
  async speak(wav, text) {
    this.stop();

    if (wav && wav.length > 0 && !this.audioBroken) {
      try {
        await this.playWithAnalyser(wav);
        this.driver = "voice";
        return { driver: "voice", detail: `音声 ${wav.length} バイトを解析して口を動かします` };
      } catch (err) {
        // WebAudio が使えない環境だった。音だけは鳴らして、口は擬似で動かす
        this.audioBroken = true;
        this.diag(`口パク: WebAudio が使えませんでした (${err?.message ?? err})。擬似口パクに切り替えます`);
      }
    }

    if (wav && wav.length > 0) {
      // 保険: <audio> でとにかく音は出す。口はテキストから動かす
      this.playWithElement(wav);
      this.startPseudo(text);
      this.driver = "pseudo";
      return { driver: "pseudo", detail: "音声は再生しますが、口はテキストから動かします" };
    }

    // 声が無い環境 (VOICEVOX 未起動)。無言の棒立ちにはしない
    this.startPseudo(text);
    this.driver = "pseudo";
    return {
      driver: "pseudo",
      detail: `声が無いので、本文 ${[...String(text ?? "")].length} 文字から口を動かします`,
    };
  }

  /** WebAudio で鳴らしつつ、AnalyserNode で音量を測れるようにする */
  async playWithAnalyser(wav) {
    const ctx = this.ensureContext();
    if (!ctx) throw new Error("AudioContext がありません");
    if (ctx.state === "suspended") await ctx.resume();

    // decodeAudioData は渡した ArrayBuffer を空にするので、必ず複製を渡す
    const buffer = wav.buffer.slice(wav.byteOffset, wav.byteOffset + wav.byteLength);
    const decoded = await ctx.decodeAudioData(buffer);

    const analyser = ctx.createAnalyser();
    // 1024 点 ≒ 24kHz なら 43ms 分。口の動きを見るにはこれくらいが丁度いい
    analyser.fftSize = 1024;
    analyser.smoothingTimeConstant = 0; // ならしは自前でやるので、ここでは掛けない

    const source = ctx.createBufferSource();
    source.buffer = decoded;
    source.connect(analyser);
    analyser.connect(ctx.destination);

    source.onended = () => {
      if (this.source === source) {
        this.source = null;
        this.analyser = null;
        this.driver = "none";
      }
    };

    this.analyser = analyser;
    this.source = source;
    this.samples = new Uint8Array(analyser.fftSize);
    source.start();
  }

  /** WebAudio が使えないときの保険。音を出すだけで、解析はしない */
  playWithElement(wav) {
    try {
      const url = URL.createObjectURL(new Blob([wav], { type: "audio/wav" }));
      const audio = new Audio(url);
      this.element = audio;
      audio.addEventListener("ended", () => {
        URL.revokeObjectURL(url);
        if (this.element === audio) this.element = null;
      });
      audio.play().catch(() => URL.revokeObjectURL(url));
    } catch {
      /* 音が出せなくても、口パクだけは続ける */
    }
  }

  /** テキストから擬似口パクを始める */
  startPseudo(text) {
    this.score = buildPseudoScore(text);
    this.pseudoAt = 0;
  }

  /** 鳴っているものを止めて、口を閉じにいく */
  stop() {
    if (this.source) {
      try {
        this.source.onended = null;
        this.source.stop();
      } catch {
        /* もう終わっていた */
      }
      this.source = null;
    }
    this.analyser = null;
    if (this.element) {
      try {
        this.element.pause();
      } catch {
        /* 無視してよい */
      }
      this.element = null;
    }
    this.score = null;
    this.driver = "none";
  }

  /** いま鳴っている音の大きさ (RMS 0〜1) */
  readRms() {
    if (!this.analyser || !this.samples) return 0;
    this.analyser.getByteTimeDomainData(this.samples);
    let sum = 0;
    for (let i = 0; i < this.samples.length; i++) {
      const v = (this.samples[i] - 128) / 128;
      sum += v * v;
    }
    return Math.sqrt(sum / this.samples.length);
  }

  /**
   * 毎フレーム呼ぶ。口の開き (this.value) を更新する。
   * @param {number} delta 秒
   */
  update(delta) {
    let target = 0;

    if (this.analyser) {
      target = levelFromRms(this.readRms());
    } else if (this.score) {
      this.pseudoAt += delta;
      if (this.pseudoAt > this.score.duration) {
        this.score = null;
        this.driver = "none";
      } else {
        target = pseudoLevelAt(this.score, this.pseudoAt);
      }
    }

    this.value = smoothMouth(this.value, target, delta);
    return this.value;
  }

  /** 診断ログ用の 1 行 */
  describe() {
    const name = { voice: "実音声 (AnalyserNode)", pseudo: "擬似 (テキスト長)", none: "停止中" };
    return `口パク: 駆動源=${name[this.driver] ?? this.driver} 開き=${this.value.toFixed(3)}`;
  }
}
