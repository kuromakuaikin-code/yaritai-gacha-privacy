// App内課金（react-native-iap）。
// - Expo Go にはネイティブモジュールが無いため、require は try/catch で守り、
//   失敗時は「利用不可」として扱う（FREE_TRIAL 中は呼ばれない）
// - EAS Build した本番アプリでのみ実際に動作する
// - サンドボックステスト時に API 差異があれば、このファイルだけ直せばよい

import { PREMIUM_PRODUCT_ID } from './config';

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

/** 購入。成功したら true */
export async function buyProduct(productId: string): Promise<boolean> {
  const m = lib();
  if (!m) return false;
  try {
    await ensureConnection(m);
    if (typeof m.getProducts === 'function') {
      await m.getProducts({ skus: [PREMIUM_PRODUCT_ID] });
    }
    const result = await m.requestPurchase({
      sku: productId,
      andDangerouslyFinishTransactionAutomaticallyIOS: false,
    });
    const purchase = Array.isArray(result) ? result[0] : result;
    if (!purchase) return false;
    try {
      await m.finishTransaction({ purchase, isConsumable: false });
    } catch {
      // finish 失敗は購入自体の成立を妨げない
    }
    return true;
  } catch {
    return false; // キャンセル含む
  }
}

/** 購入の復元。復元されたプロダクトIDの配列を返す */
export async function restorePurchases(): Promise<string[]> {
  const m = lib();
  if (!m) return [];
  try {
    await ensureConnection(m);
    const purchases: any[] = (await m.getAvailablePurchases()) ?? [];
    return purchases
      .map(p => p?.productId ?? p?.id)
      .filter((id): id is string => typeof id === 'string');
  } catch {
    return [];
  }
}
