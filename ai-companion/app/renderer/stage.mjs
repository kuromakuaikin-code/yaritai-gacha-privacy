// =============================================================
// キャラの舞台まわり (three.js + @pixiv/three-vrm)
//
//   - 背景が完全に透明な three.js シーンを作る
//   - VRM (0.x / 1.0 どちらも) を読み込んで立たせる
//   - 読み込み直後に自然な立ち姿 (基準姿勢) を当てる
//   - まばたきと呼吸のアイドルモーションを、基準姿勢の上に足す
//   - 表情 (感情) と口の開きを ExpressionMixer 経由でまとめて入れる
//   - 「今マウスがキャラの上にいるか」をレイキャストで判定する
//     ← クリック透過の切り替えに使う、このアプリの心臓部
//   - マテリアルの診断と、MToon → 標準マテリアルの代替表示
// =============================================================
import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { VRMLoaderPlugin, VRMUtils } from "@pixiv/three-vrm";
import { ExpressionMixer } from "./expression.mjs";

// キャラが画面の高さ・幅のどれくらいを占めるか。
// 余った分は主に上へ回して、吹き出しの居場所にする (LIFT_MAX が上限)。
const FILL_RATIO_Y = 0.74;
const FILL_RATIO_X = 0.92;
const LIFT_MAX = 0.16; // 身長に対する持ち上げ量の上限

// -------------------------------------------------------------
// 光の強さ (ここを間違えるとキャラが真っ白に飛ぶ)
//
// three r155 以降、ライトの intensity は物理単位になった。
// MToon のシェーダーは受け取った光を BRDF_Lambert (= 1/π 倍) してから
// テクスチャ色に掛けるので、
//
//     画面に出る明るさ ≒ (光の合計 intensity ÷ π) × テクスチャ色
//
// になる。つまり合計 intensity が π を超えると、その分だけ色が 1.0 を
// 超えて白飛びする。MToon はトーンマッピングを通らないため、超えた分は
// そのまま切り捨てられ、明るい肌や白い服は「真っ白な面」になってしまう。
// (輪郭線だけは outlineColorFactor を掛けた別の色なので残る。
//  「輪郭だけ見えて中身が白い」のはこれが原因だった)
//
// そこで、キーライトと環境光の合計が π を少しだけ下回るようにしてある。
const KEY_LIGHT = Math.PI * 0.7; // 正面やや上からの主光源
const AMBIENT_LIGHT = Math.PI * 0.32; // 影側が潰れないように足す環境光

// -------------------------------------------------------------
// 基準姿勢 (T ポーズのままにしないための、自然な立ち姿)
//
// VRM の正規化ボーンは 0.x / 1.0 のどちらでも同じ名前で引けるので、
// 版の違いはここでは意識しなくてよい。
// 向きの決まり: モデルは +Z を向き、+X がモデルから見て左。
// したがって左腕 (+X 方向に伸びている) を下ろすには z をマイナスに回す。
// -------------------------------------------------------------
const REST_POSE = {
  leftShoulder: { z: -0.06 },
  rightShoulder: { z: 0.06 },
  leftUpperArm: { z: -1.15 }, // 約 66 度。A ポーズよりしっかり下ろした角度
  rightUpperArm: { z: 1.15 },
  leftLowerArm: { y: -0.12 }, // 肘をわずかに曲げて棒立ちを避ける
  rightLowerArm: { y: 0.12 },
};

/** アイドルモーションで動かす骨。基準姿勢からの差分として足す */
const IDLE_BONES = ["upperChest", "chest", "spine", "leftShoulder", "rightShoulder"];

// 呼吸のゆっくりさ (秒/1呼吸) と深さ (ラジアン)
const BREATH_CYCLE = 4.5;
const BREATH_CHEST = 0.02;
const BREATH_SPINE = 0.011;
const BREATH_SHOULDER = 0.014;

// まばたき: 1 回にかける時間と、次のまばたきまでの間隔
const BLINK_DURATION = 0.22;
const BLINK_INTERVAL_MIN = 2.2;
const BLINK_INTERVAL_MAX = 6.5;

export class Stage {
  /** @param {HTMLCanvasElement} canvas */
  constructor(canvas) {
    this.canvas = canvas;

    this.renderer = new THREE.WebGLRenderer({
      canvas,
      alpha: true, // 背景を透明にする (これがないと窓が黒く塗られる)
      antialias: true,
      // three のマテリアルは既定で「色に不透明度を掛けない (ストレートアルファ)」で
      // 書き出す。ところが WebGL の既定は「掛けた後の値が入っている」扱いなので、
      // そのままだと半透明の画素 (輪郭のアンチエイリアス、髪や睫毛) を
      // ブラウザが合成するときに白く浮く。透過ウィンドウでは特に目立つ。
      // 書き出し方に合わせて false にする。不透明な画素の見え方は変わらない。
      premultipliedAlpha: false,
    });
    this.renderer.setClearColor(0x000000, 0);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    // テクスチャの色空間の扱い (既定のままだが、白飛びの調査で毎回見る場所なので明示する)
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.NoToneMapping; // MToon は自前で色を決めるので通さない

    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(28, 1, 0.1, 30);

    // 光。強さの決め方はファイル冒頭の KEY_LIGHT のコメントを参照
    const key = new THREE.DirectionalLight(0xffffff, KEY_LIGHT);
    key.position.set(0.6, 1.4, 1.0).normalize();
    this.scene.add(key);
    this.scene.add(new THREE.HemisphereLight(0xffffff, 0x556070, AMBIENT_LIGHT));

    /** @type {import("@pixiv/three-vrm").VRM | null} */
    this.vrm = null;
    /** @type {THREE.Object3D[]} レイキャストの対象にするメッシュ */
    this.meshes = [];
    this.clock = 0;

    /** 基準姿勢での骨の回転 (骨名 → Euler)。アイドルはここからの差分で動かす */
    this.rest = new Map();
    /** MToon をやめて標準マテリアルで描いているか (見え方の切り分け用) */
    this.fallback = false;
    /** 直近に読み込んだモデルの診断情報 */
    this.diagnostics = null;

    // まばたきの状態
    this.blinkWait = BLINK_INTERVAL_MIN;
    this.blinkLeft = 0;

    // 表情 (感情のクロスフェード + 口の開き + まばたき) をまぜる係。
    // setValue を呼ぶのはここ 1 か所だけにして、値の取り合いを防ぐ
    this.expressions = new ExpressionMixer();

    // 当たり判定用
    this.raycaster = new THREE.Raycaster();
    this.pointerNdc = new THREE.Vector2();
    /** キャラが画面上で占める大まかな矩形。レイキャスト前のふるい分けに使う */
    this.screenRect = null;
    /** カメラ位置の計算に使う、読み込み時の寸法 */
    this.frame = null;

    this.resize();
  }

  get ready() {
    return this.vrm !== null;
  }

  // -----------------------------------------------------------
  // 画面サイズへの追従
  // -----------------------------------------------------------
  resize() {
    const w = Math.max(1, window.innerWidth);
    const h = Math.max(1, window.innerHeight);
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.applyCamera();
  }

  // -----------------------------------------------------------
  // VRM の読み込み
  //
  // ファイルの中身 (Uint8Array) は main.js から受け取る。
  // GLTFLoader.parseAsync に渡すので、URL や fetch は使わない。
  // -----------------------------------------------------------
  /** @param {Uint8Array} bytes */
  async loadVrm(bytes) {
    const loader = new GLTFLoader();
    // これを登録すると gltf.userData.vrm に VRM が入ってくる。
    // VRM 0.x は内部で 1.0 相当に変換されるので、呼び出し側は違いを意識しない
    loader.register((parser) => new VRMLoaderPlugin(parser));

    // byteOffset がついている場合に備えて、必要な範囲だけ切り出す
    const buffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
    const gltf = await loader.parseAsync(buffer, "");
    const vrm = gltf.userData.vrm;
    if (!vrm) throw new Error("VRM ではないファイルのようです");

    this.clear();

    // 表示を軽くするための後始末 (対応していない版でも落ちないように包む)
    try {
      VRMUtils.removeUnnecessaryVertices(gltf.scene);
      VRMUtils.combineSkeletons(gltf.scene);
    } catch {
      /* 最適化に失敗しても表示自体はできるので無視する */
    }
    // VRM 0.x は向きの基準が 1.0 と違うので揃える
    VRMUtils.rotateVRM0(vrm);

    // 画面外と判定されて消えることがあるので、視錐台カリングを切る
    vrm.scene.traverse((obj) => {
      obj.frustumCulled = false;
    });

    this.scene.add(vrm.scene);
    this.vrm = vrm;

    // レイキャストの対象になるメッシュを先に集めておく (毎回 traverse しないため)
    this.meshes = [];
    vrm.scene.traverse((obj) => {
      if (obj.isMesh || obj.isSkinnedMesh) this.meshes.push(obj);
    });

    // T ポーズをやめて自然な立ち姿にする。
    // 寸法を測る前に当てないと、広げた腕のぶんカメラが引きすぎてしまう
    this.applyRestPose();
    vrm.update(0); // 正規化ボーンの回転を実際の骨に反映させる

    // このモデルで使える表情を調べる (無い感情はここで諦める)
    this.expressions.bind(vrm.expressionManager);

    // 前回まで代替マテリアルで見ていたなら、その状態を引き継ぐ
    if (this.fallback) this.applyMaterialMode();

    this.diagnostics = this.collectDiagnostics();

    this.measure();
    this.applyCamera();
    return vrm;
  }

  /** 今のモデルを片付ける (別のモデルに入れ替えるとき用) */
  clear() {
    if (!this.vrm) return;
    this.scene.remove(this.vrm.scene);
    // 代替マテリアルは three-vrm の後片付けの対象外なので、自分で捨てる。
    // 先に元のマテリアルへ戻しておかないと、deepDispose が代替のほうを
    // 片付けて、元の MToon が残ってしまう
    for (const mesh of this.meshes) {
      const kept = mesh.userData.companionMaterials;
      if (!kept) continue;
      mesh.material = kept.original;
      for (const material of [].concat(kept.fallback ?? [])) material?.dispose?.();
      delete mesh.userData.companionMaterials;
    }
    try {
      VRMUtils.deepDispose(this.vrm.scene);
    } catch {
      /* 片付けに失敗しても致命的ではない */
    }
    this.vrm = null;
    this.meshes = [];
    this.rest = new Map();
    this.expressions.bind(null);
    this.diagnostics = null;
    this.screenRect = null;
    this.frame = null;
  }

  // -----------------------------------------------------------
  // 基準姿勢
  //
  // 正規化ボーン (getNormalizedBoneNode) に回転を入れておくと、
  // vrm.update() のたびに実際の骨へ反映される。ここで入れた値は
  // 消されないので、これがアイドルモーションの土台になる。
  // -----------------------------------------------------------
  applyRestPose() {
    this.rest = new Map();
    const humanoid = this.vrm?.humanoid;
    if (!humanoid) return;

    for (const [bone, angles] of Object.entries(REST_POSE)) {
      const node = humanoid.getNormalizedBoneNode(bone);
      // 肩など、モデルによっては無い骨がある。無ければ飛ばす
      if (!node) continue;
      node.rotation.set(angles.x ?? 0, angles.y ?? 0, angles.z ?? 0);
    }

    // アイドルで動かす骨の「今の値」を基準として控える。
    // 呼吸はこの値からの差分で動かすので、基準姿勢と喧嘩しない
    for (const bone of IDLE_BONES) {
      const node = humanoid.getNormalizedBoneNode(bone);
      if (node) this.rest.set(bone, node.rotation.clone());
    }
  }

  /** アイドル用: 骨と、その基準回転をまとめて取る */
  idleBone(name) {
    const node = this.vrm?.humanoid?.getNormalizedBoneNode(name);
    if (!node) return null;
    return { node, base: this.rest.get(name) ?? { x: 0, y: 0, z: 0 } };
  }

  // -----------------------------------------------------------
  // 診断: 読み込んだモデルの中身を数える
  //
  // 表示がおかしいときに、原因の当たりをつけるための情報を集める。
  // 端末に出す文言は describeDiagnostics() で作る。
  // -----------------------------------------------------------
  collectDiagnostics() {
    const info = {
      metaVersion: this.vrm?.meta?.metaVersion ?? (this.vrm?.meta?.title ? "0.x" : "不明"),
      name: this.vrm?.meta?.name ?? this.vrm?.meta?.title ?? "(名前なし)",
      meshes: this.meshes.length,
      materials: [],
      mtoon: 0,
      outline: 0,
      standard: 0,
      withTexture: 0,
      transparent: 0,
      bones: 0,
      expressions: 0,
      fallback: this.fallback,
    };

    const humanoid = this.vrm?.humanoid;
    if (humanoid) {
      for (const bone of Object.keys(REST_POSE)) {
        if (humanoid.getNormalizedBoneNode(bone)) info.bones++;
      }
    }
    info.expressions = Object.keys(this.vrm?.expressionManager?.expressionMap ?? {}).length;

    const seen = new Set();
    for (const mesh of this.meshes) {
      for (const material of [].concat(mesh.material ?? [])) {
        if (!material || seen.has(material.uuid)) continue;
        seen.add(material.uuid);
        const isMToon = !!material.isMToonMaterial;
        const isOutline = !!material.isOutline;
        if (isMToon) info.mtoon++;
        else if (material.isMeshStandardMaterial) info.standard++;
        if (isOutline) info.outline++;
        if (material.map) info.withTexture++;
        if (material.transparent) info.transparent++;
        info.materials.push({
          name: material.name || "(無名)",
          type: material.type,
          mtoon: isMToon,
          outline: isOutline,
          texture: material.map ? material.map.colorSpace : "なし",
          transparent: material.transparent,
          alphaTest: material.alphaTest,
          side: ["前面", "背面", "両面"][material.side] ?? String(material.side),
          visible: material.visible,
        });
      }
    }
    return info;
  }

  /** 診断情報を、端末にそのまま貼れる文字列にする */
  describeDiagnostics(versions) {
    const d = this.diagnostics;
    if (!d) return "モデルが読み込まれていません";
    const lines = [
      `VRM 読み込み: ${d.name} (VRM ${d.metaVersion})`,
      `  ライブラリ: three ${versions?.three ?? "?"} / @pixiv/three-vrm ${versions?.threeVrm ?? "?"}`,
      `  メッシュ ${d.meshes} 個 / マテリアル ${d.materials.length} 個 ` +
        `(MToon ${d.mtoon} / 標準 ${d.standard} / うち輪郭線 ${d.outline})`,
      `  テクスチャあり ${d.withTexture} 個 / 半透明 ${d.transparent} 個 / ` +
        `表情 ${d.expressions} 種 / 姿勢に使う骨 ${d.bones}/${Object.keys(REST_POSE).length}`,
      `  描画モード: ${d.fallback ? "代替 (MeshStandardMaterial)" : "通常 (MToon)"}`,
      // 表情まわり (Phase 3/4)。どの感情が出せるモデルかはここで分かる
      ...this.expressions
        .describe()
        .split("\n")
        .map((line) => `  ${line}`),
    ];
    for (const m of d.materials) {
      lines.push(
        `    - ${m.name} [${m.type}${m.mtoon ? "/MToon" : ""}${m.outline ? "/輪郭" : ""}] ` +
          `テクスチャ=${m.texture} 半透明=${m.transparent} alphaTest=${m.alphaTest} ` +
          `面=${m.side} 表示=${m.visible}`
      );
    }
    if (d.mtoon === 0 && d.standard === 0) {
      lines.push("  ※ マテリアルを 1 つも認識できていません。VRM の変換に失敗した可能性があります");
    }
    if (d.materials.length > 0 && d.withTexture === 0) {
      lines.push(
        "  ※ テクスチャが 1 枚も読めていません。キャラは色だけ (真っ白) で描かれます。",
        "     index.html の Content-Security-Policy から connect-src の blob: が" +
          "抜けていないか確認してください"
      );
    }
    return lines.join("\n");
  }

  // -----------------------------------------------------------
  // 代替マテリアル (MToon → MeshStandardMaterial)
  //
  // MToon 側で描けない事情があったときの逃げ道。
  // トゥーンの陰影と輪郭線は失われるが、まず「映る」ことを優先する。
  // 元のマテリアルは捨てずに持っておくので、いつでも戻せる。
  // -----------------------------------------------------------
  /** @param {boolean} on */
  setFallback(on) {
    this.fallback = !!on;
    this.applyMaterialMode();
    if (this.diagnostics) this.diagnostics.fallback = this.fallback;
    return this.fallback;
  }

  applyMaterialMode() {
    for (const mesh of this.meshes) {
      let kept = mesh.userData.companionMaterials;
      if (!kept) {
        kept = { original: mesh.material, fallback: null };
        mesh.userData.companionMaterials = kept;
      }
      if (this.fallback) {
        if (!kept.fallback) {
          kept.fallback = Array.isArray(kept.original)
            ? kept.original.map((m) => toStandardMaterial(m))
            : toStandardMaterial(kept.original);
        }
        mesh.material = kept.fallback;
      } else {
        mesh.material = kept.original;
      }
    }
  }

  // -----------------------------------------------------------
  // モデルの寸法と「どちらが正面か」を測る
  //
  // 正面の向きは、左右の上腕の位置から求める。
  // VRM の版やモデルの作りに関係なく、必ず顔がこちらを向く。
  //   正面 = 上方向 × (左腕 → 右腕)
  // -----------------------------------------------------------
  measure() {
    const vrm = this.vrm;
    vrm.scene.updateMatrixWorld(true);

    const box = new THREE.Box3().setFromObject(vrm.scene);
    const size = box.getSize(new THREE.Vector3());
    const center = box.getCenter(new THREE.Vector3());

    let forward = new THREE.Vector3(0, 0, 1);
    const humanoid = vrm.humanoid;
    // 実際にモデルに入っている骨 (raw) の位置で測る
    const leftArm = humanoid?.getRawBoneNode("leftUpperArm");
    const rightArm = humanoid?.getRawBoneNode("rightUpperArm");
    if (leftArm && rightArm) {
      const left = leftArm.getWorldPosition(new THREE.Vector3());
      const right = rightArm.getWorldPosition(new THREE.Vector3());
      const side = right.sub(left);
      side.y = 0;
      if (side.lengthSq() > 1e-8) {
        forward = new THREE.Vector3(0, 1, 0).cross(side.normalize()).normalize();
      }
    }

    this.frame = { box, size, center, forward };
  }

  /** 測った寸法をもとにカメラを置く。ウィンドウサイズが変わるたびに呼ぶ */
  applyCamera() {
    if (!this.frame) return;
    const { size, center, forward } = this.frame;
    const fov = THREE.MathUtils.degToRad(this.camera.fov);

    // 縦がちょうど収まる高さを出し、横がはみ出すならさらに引く
    let visibleH = size.y / FILL_RATIO_Y;
    const neededW = size.x / FILL_RATIO_X;
    if (visibleH * this.camera.aspect < neededW) {
      visibleH = neededW / this.camera.aspect;
    }
    const dist = visibleH / 2 / Math.tan(fov / 2);

    // 余白は上に寄せる (吹き出しの居場所を空ける)。寄せすぎないよう上限をつける
    const lift = Math.min((visibleH - size.y) / 2, size.y * LIFT_MAX);
    const target = new THREE.Vector3(center.x, center.y + lift, center.z);

    this.camera.position.copy(target).addScaledVector(forward, dist);
    this.camera.lookAt(target);
    this.camera.updateMatrixWorld(true);

    this.updateScreenRect();
  }

  // -----------------------------------------------------------
  // キャラが画面上で占める矩形を求めておく。
  // マウスがここの外にいるなら、重いレイキャストをせずに「外」と決められる。
  // -----------------------------------------------------------
  updateScreenRect() {
    if (!this.frame) {
      this.screenRect = null;
      return;
    }
    const { box } = this.frame;
    const w = window.innerWidth;
    const h = window.innerHeight;
    const v = new THREE.Vector3();
    let minX = Infinity;
    let minY = Infinity;
    let maxX = -Infinity;
    let maxY = -Infinity;

    for (let i = 0; i < 8; i++) {
      v.set(
        i & 1 ? box.max.x : box.min.x,
        i & 2 ? box.max.y : box.min.y,
        i & 4 ? box.max.z : box.min.z
      );
      v.project(this.camera);
      const x = ((v.x + 1) / 2) * w;
      const y = ((1 - v.y) / 2) * h;
      minX = Math.min(minX, x);
      maxX = Math.max(maxX, x);
      minY = Math.min(minY, y);
      maxY = Math.max(maxY, y);
    }
    const margin = 8; // 輪郭ぎりぎりで判定が揺れないよう、少しだけ広げる
    this.screenRect = {
      minX: minX - margin,
      minY: minY - margin,
      maxX: maxX + margin,
      maxY: maxY + margin,
    };
  }

  // -----------------------------------------------------------
  // マウスがキャラの上にいるか (クリック透過の切り替えに使う)
  //
  //   1. まず矩形でふるい分け (ほとんどの場合ここで終わる = 軽い)
  //   2. 矩形の中ならレイキャストして、実際のメッシュに当たるか見る
  //      → 髪の隙間や脇の下など、キャラの形どおりに透過できる
  // -----------------------------------------------------------
  hitTest(clientX, clientY) {
    if (!this.vrm || !this.screenRect) return false;
    const r = this.screenRect;
    if (clientX < r.minX || clientX > r.maxX || clientY < r.minY || clientY > r.maxY) {
      return false;
    }

    const w = window.innerWidth;
    const h = window.innerHeight;
    this.pointerNdc.set((clientX / w) * 2 - 1, -(clientY / h) * 2 + 1);
    this.raycaster.setFromCamera(this.pointerNdc, this.camera);

    const hits = this.raycaster.intersectObjects(this.meshes, false);
    for (const hit of hits) {
      if (isVisible(hit.object)) return true;
    }
    return false;
  }

  // -----------------------------------------------------------
  // 毎フレームの更新
  // -----------------------------------------------------------
  update(delta) {
    this.clock += delta;
    if (this.vrm) {
      this.updateBlink(delta);
      this.updateBreath();
      // 感情・口・まばたきをまとめて表情に入れる (順番の取り合いを避けるため最後)
      this.expressions.update(delta);
      // ボーンをいじったあとに呼ぶ (ここで表情・揺れものが反映される)
      this.vrm.update(delta);
    }
    this.renderer.render(this.scene, this.camera);
  }

  // -----------------------------------------------------------
  // 表情 (Phase 3) と口の開き (Phase 4) の入口。
  // 実際の重みの計算とクロスフェードは expression.mjs にある
  // -----------------------------------------------------------
  /**
   * 感情を切り替える (0.25 秒かけて変わる)。
   * @param {string} emotion happy / angry / sad / relaxed / surprised / neutral
   * @returns {string} 実際に採用された感情 (モデルに無ければ neutral)
   */
  setEmotion(emotion) {
    return this.expressions.setEmotion(emotion);
  }

  /** @param {number} level 口の開き 0〜1 (LipSync が毎フレーム入れる) */
  setMouth(level) {
    this.expressions.setMouth(level);
  }

  /** 自動まばたき。閉じて開くまでを三角波で作る */
  updateBlink(delta) {
    if (this.blinkLeft > 0) {
      this.blinkLeft -= delta;
    } else {
      this.blinkWait -= delta;
      if (this.blinkWait <= 0) {
        this.blinkLeft = BLINK_DURATION;
        this.blinkWait =
          BLINK_INTERVAL_MIN + Math.random() * (BLINK_INTERVAL_MAX - BLINK_INTERVAL_MIN);
      }
    }

    let weight = 0;
    if (this.blinkLeft > 0) {
      const t = this.blinkLeft / BLINK_DURATION; // 1 → 0
      weight = 1 - Math.abs(t * 2 - 1); // 0 → 1 → 0
    }
    // 感情とは無関係に重ねる (笑っていても瞬きはする)
    this.expressions.setBlink(weight);
  }

  /**
   * ゆっくりした呼吸。胸をわずかに反らし、肩を少し上下させる。
   *
   * 値を直接入れるのではなく、必ず基準姿勢 (this.rest) からの差分にする。
   * こうしないと、腕を下ろした基準姿勢が毎フレーム上書きされて T ポーズに戻る。
   */
  updateBreath() {
    if (!this.vrm?.humanoid) return;
    const wave = Math.sin((this.clock * Math.PI * 2) / BREATH_CYCLE);

    const chest = this.idleBone("upperChest") ?? this.idleBone("chest");
    if (chest) chest.node.rotation.x = chest.base.x + wave * BREATH_CHEST;

    // 胸を反らした分だけ背骨で戻す (前かがみに見えないように)
    const spine = this.idleBone("spine");
    if (spine) spine.node.rotation.x = spine.base.x - wave * BREATH_SPINE;

    // 肩は左右対称に。正規化された骨は回転しか効かないので位置は動かさない
    const leftShoulder = this.idleBone("leftShoulder");
    const rightShoulder = this.idleBone("rightShoulder");
    if (leftShoulder) leftShoulder.node.rotation.z = leftShoulder.base.z - wave * BREATH_SHOULDER;
    if (rightShoulder) rightShoulder.node.rotation.z = rightShoulder.base.z + wave * BREATH_SHOULDER;
  }
}

/**
 * MToon マテリアルを、three 標準の MeshStandardMaterial に置き換える。
 *
 * 輪郭線用のマテリアルは、標準マテリアルにすると裏返った塊が
 * キャラを覆ってしまうので、描かないマテリアルに差し替える。
 *
 * @param {THREE.Material} source
 * @returns {THREE.Material}
 */
function toStandardMaterial(source) {
  if (!source) return source;

  if (source.isOutline) {
    const hidden = new THREE.MeshBasicMaterial({ name: `${source.name} (輪郭・非表示)` });
    hidden.visible = false;
    return hidden;
  }
  if (!source.isMToonMaterial) return source; // 元から標準系ならそのまま使う

  const standard = new THREE.MeshStandardMaterial({
    name: `${source.name} (代替)`,
    map: source.map ?? null,
    color: source.color ? source.color.clone() : new THREE.Color(0xffffff),
    emissive: source.emissive ? source.emissive.clone() : new THREE.Color(0x000000),
    emissiveMap: source.emissiveMap ?? null,
    emissiveIntensity: source.emissiveIntensity ?? 1,
    normalMap: source.normalMap ?? null,
    // トゥーン系のテクスチャは陰影が描き込まれているので、つや消しにする
    roughness: 1,
    metalness: 0,
    transparent: source.transparent,
    opacity: source.opacity,
    alphaTest: source.alphaTest,
    depthWrite: source.depthWrite,
    side: source.side,
  });
  return standard;
}

/** 親をたどって、本当に表示されているメッシュかどうかを確かめる */
function isVisible(object) {
  let node = object;
  while (node) {
    if (node.visible === false) return false;
    node = node.parent;
  }
  return true;
}
