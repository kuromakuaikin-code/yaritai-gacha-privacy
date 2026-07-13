import { countItems } from "@/db/items";
import { getSetting, setSetting } from "@/db/settings";

/**
 * 課金プラン:
 * - 無料版: 登録上限5件
 * - 追加枠（買い切り ¥300・非消耗型）: +10件 → 合計15件
 * 履歴・通知・テンプレートなどの機能に差はつけない。
 */
export const FREE_ITEM_LIMIT = 5;
export const PLUS_ITEM_BONUS = 10;
export const PLUS_PRICE_LABEL = "¥300";
export const PLUS_PRODUCT_ID = "com.kuromakuaikin.ouchimente.plus10";

export async function isPlusUnlocked(): Promise<boolean> {
  return (await getSetting("plusUnlocked")) === "1";
}

export async function setPlusUnlocked(unlocked: boolean): Promise<void> {
  await setSetting("plusUnlocked", unlocked ? "1" : "0");
}

export async function getItemLimit(): Promise<number> {
  return (await isPlusUnlocked())
    ? FREE_ITEM_LIMIT + PLUS_ITEM_BONUS
    : FREE_ITEM_LIMIT;
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
  const limit = plusUnlocked ? FREE_ITEM_LIMIT + PLUS_ITEM_BONUS : FREE_ITEM_LIMIT;
  return { allowed: count < limit, count, limit, plusUnlocked };
}
