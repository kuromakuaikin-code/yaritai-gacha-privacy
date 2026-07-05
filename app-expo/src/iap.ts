// App内課金（react-native-iap v15 / NitroIap）。
// - v15 は「イベント駆動」: requestPurchase の戻り値ではなく
//   purchaseUpdatedListener / purchaseErrorListener で結果を受け取る
// - Expo Go にはネイティブモジュールが無いため、require は try/catch で守り、
//   失敗時は「利用不可」として扱う（FREE_TRIAL 中は呼ばれない）
// - EAS Build した本番アプリでのみ実際に動作する

let mod: any | null | undefined;

function lib(): any | null {
  if (mod !== undefined) return mod;
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    mod = require('react-native-iap');
  } catch {
    mod = null;
  }
  return mod;
}

export function iapAvailable(): boolean {
  return lib() !== null;
}

async function ensureConnection(m: any): Promise<void> {
  try {
    await m.initConnection();
  } catch {
    // 既に接続済みの場合などは無視
  }
}

export interface BuyResult {
  success: boolean;
  /** ユーザーが自分でキャンセルした場合 true（エラー表示は不要） */
  cancelled?: boolean;
  /** 失敗理由（デバッグ表示用） */
  message?: string;
}

function isCancel(e: any): boolean {
  const code = String(e?.code ?? '').toLowerCase();
  return code.includes('cancel');
}

/** 購入。結果はイベントで受け取り BuyResult にまとめて返す */
export async function buyProduct(productId: string): Promise<BuyResult> {
  const m = lib();
  if (!m) return { success: false, message: 'この環境では課金を利用できません' };
  await ensureConnection(m);
  try {
    // 事前に商品情報を取得（ストアにSKUを認識させる）
    const products = await m.fetchProducts({ skus: [productId], type: 'in-app' });
    if (Array.isArray(products) && products.length === 0) {
      return {
        success: false,
        message: '商品情報を取得できませんでした。App Store Connectの契約(有料App)と商品の状態を確認してください',
      };
    }
  } catch {
    // 取得失敗でも購入は試みる
  }
  return new Promise<BuyResult>(resolve => {
    let settled = false;
    let subOk: any = null;
    let subErr: any = null;
    const finish = (r: BuyResult) => {
      if (settled) return;
      settled = true;
      try { subOk?.remove(); } catch {}
      try { subErr?.remove(); } catch {}
      resolve(r);
    };
    try {
      subOk = m.purchaseUpdatedListener(async (purchase: any) => {
        const pid = purchase?.productId ?? purchase?.id;
        if (pid && pid !== productId) return;
        try {
          await m.finishTransaction({ purchase, isConsumable: false });
        } catch {
          // finish 失敗は購入自体の成立を妨げない
        }
        finish({ success: true });
      });
      subErr = m.purchaseErrorListener((e: any) => {
        if (isCancel(e)) finish({ success: false, cancelled: true });
        else finish({ success: false, message: e?.message ?? String(e?.code ?? '不明なエラー') });
      });
      m.requestPurchase({
        request: { apple: { sku: productId } },
        type: 'in-app',
      }).catch((e: any) => {
        if (isCancel(e)) finish({ success: false, cancelled: true });
        else finish({ success: false, message: e?.message ?? String(e?.code ?? '不明なエラー') });
      });
    } catch (e: any) {
      finish({ success: false, message: e?.message ?? '購入を開始できませんでした' });
    }
  });
}

/** 購入の復元。復元されたプロダクトIDの配列を返す */
export async function restorePurchases(): Promise<string[]> {
  const m = lib();
  if (!m) return [];
  try {
    await ensureConnection(m);
    try {
      // iOSのトランザクション同期（存在すれば呼ぶ）
      if (typeof m.restorePurchases === 'function') await m.restorePurchases();
    } catch {}
    const purchases: any[] = (await m.getAvailablePurchases()) ?? [];
    return purchases
      .map(p => p?.productId ?? p?.id)
      .filter((id): id is string => typeof id === 'string');
  } catch {
    return [];
  }
}
