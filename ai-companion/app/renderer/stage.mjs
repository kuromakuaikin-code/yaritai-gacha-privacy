// =============================================================
// キャラの舞台まわり (three.js + @pixiv/three-vrm)
//
//   - 背景が完全に透明な three.js シーンを作る
//   - VRM (0.x / 1.0 どちらも) を読み込んで立たせる
//   - まばたきと呼吸のアイドルモーションを回す
//   - 「今マウスがキャラの上にいるか」をレイキャストで判定する
//     ← クリック透過の切り替えに使う、このアプリの心臓部
// =============================================================
import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { VRMLoaderPlugin, VRMUtils } from "@pixiv/three-vrm";

// キャラが画面の高さ・幅のどれくらいを占めるか。
// 余った分は主に上へ回して、吹き出しの居場所にする (LIFT_MAX が上限)。
const FILL_RATIO_Y = 0.74;
const FILL_RATIO_X = 0.92;
const LIFT_MAX = 0.16; // 身長に対する持ち上げ量の上限

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
    });
    this.renderer.setClearColor(0x000000, 0);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(28, 1, 0.1, 30);

    // 光。three r155 以降は物理単位なので Math.PI 倍が基準になる
    const key = new THREE.DirectionalLight(0xffffff, Math.PI);
    key.position.set(0.6, 1.4, 1.0).normalize();
    this.scene.add(key);
    this.scene.add(new THREE.HemisphereLight(0xffffff, 0x556070, Math.PI * 0.45));

    /** @type {import("@pixiv/three-vrm").VRM | null} */
    this.vrm = null;
    /** @type {THREE.Object3D[]} レイキャストの対象にするメッシュ */
    this.meshes = [];
    this.clock = 0;

    // まばたきの状態
    this.blinkWait = BLINK_INTERVAL_MIN;
    this.blinkLeft = 0;

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

    this.measure();
    this.applyCamera();
    return vrm;
  }

  /** 今のモデルを片付ける (別のモデルに入れ替えるとき用) */
  clear() {
    if (!this.vrm) return;
    this.scene.remove(this.vrm.scene);
    try {
      VRMUtils.deepDispose(this.vrm.scene);
    } catch {
      /* 片付けに失敗しても致命的ではない */
    }
    this.vrm = null;
    this.meshes = [];
    this.screenRect = null;
    this.frame = null;
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
      // ボーンをいじったあとに呼ぶ (ここで表情・揺れものが反映される)
      this.vrm.update(delta);
    }
    this.renderer.render(this.scene, this.camera);
  }

  /** 自動まばたき。閉じて開くまでを三角波で作る */
  updateBlink(delta) {
    const expressions = this.vrm.expressionManager;
    if (!expressions) return;

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
    expressions.setValue("blink", weight);
  }

  /** ゆっくりした呼吸。胸をわずかに反らし、肩を少し上下させる */
  updateBreath() {
    const humanoid = this.vrm.humanoid;
    if (!humanoid) return;
    const wave = Math.sin((this.clock * Math.PI * 2) / BREATH_CYCLE);

    const chest =
      humanoid.getNormalizedBoneNode("upperChest") ?? humanoid.getNormalizedBoneNode("chest");
    if (chest) chest.rotation.x = wave * BREATH_CHEST;

    // 胸を反らした分だけ背骨で戻す (前かがみに見えないように)
    const spine = humanoid.getNormalizedBoneNode("spine");
    if (spine) spine.rotation.x = -wave * BREATH_SPINE;

    // 肩は左右対称に。正規化された骨は回転しか効かないので位置は動かさない
    const leftShoulder = humanoid.getNormalizedBoneNode("leftShoulder");
    const rightShoulder = humanoid.getNormalizedBoneNode("rightShoulder");
    if (leftShoulder) leftShoulder.rotation.z = -wave * BREATH_SHOULDER;
    if (rightShoulder) rightShoulder.rotation.z = wave * BREATH_SHOULDER;
  }
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
