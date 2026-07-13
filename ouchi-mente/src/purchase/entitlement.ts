import { countItems } from "@/db/items";
import { getSetting, setSetting } from "@/db/settings";

/**
 * 課金プラン:
 * - 無料版: 登録上限3件
 * - 無制限版（買い切り ¥300・非消耗型）: 登録上限なし
 * 履歴・通知・テンプレートなどの機能に差はつけない。
 */
export const UNLIMITED_ITEM_LIMIT = Number.MAX_SAFE_INTEGER;
export const FREE_ITEM_LIMIT = 3;
export const PLUS_PRODUCT_IDS = {
  ios: "com.kuromakuaikin.ouchimente.unlimited",
  android: "com.kuromakuaikin.ouchimente.unlimited",
} as const;
export const PLUS_PRODUCT_ID = PLUS_PRODUCT_IDS.ios;

type StorePurchaseRecord = {
  productId: string;
  transactionId?: string | null;
  store: string;
};

export async function isPlusUnlocked(): Promise<boolean> {
  const [state, legacyFlag] = await Promise.all([
    getSetting("plusEntitlementState"),
    getSetting("plusUnlocked"),
  ]);
  return state === "premium" || legacyFlag === "1";
}

/**
 * ストアから確認できた購入だけを権利として保存する。
 * これはオフライン利用のためのキャッシュであり、起動時・復元時にストアで再照合する。
 */
export async function saveStorePurchaseEntitlement(
  purchase: StorePurchaseRecord,
): Promise<void> {
  const syncedAt = new Date().toISOString();
  await Promise.all([
    setSetting("plusUnlocked", "1"),
    setSetting("plusEntitlementState", "premium"),
    setSetting("plusProductId", purchase.productId),
    setSetting("plusTransactionId", purchase.transactionId ?? ""),
    setSetting("plusStore", purchase.store),
    setSetting("plusStoreSyncedAt", syncedAt),
  ]);
}

export async function getItemLimit(): Promise<number> {
  return (await isPlusUnlocked()) ? UNLIMITED_ITEM_LIMIT : FREE_ITEM_LIMIT;
}

export type AddItemCheck = {
  allowed: boolean;
  count: number;
  limit: number;
  plusUnlocked: boolean;
};

/** 新規登録できるか。編集・完了記録・履歴には制限をかけない */
export async function checkCanAddItem(): Promise<AddItemCheck> {
  const [count, plusUnlocked] = await Promise.all([
    countItems(),
    isPlusUnlocked(),
  ]);
  const limit = plusUnlocked ? UNLIMITED_ITEM_LIMIT : FREE_ITEM_LIMIT;
  return { allowed: count < limit, count, limit, plusUnlocked };
}
