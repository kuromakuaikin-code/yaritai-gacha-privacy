import { setPlusUnlocked } from "./entitlement";

/**
 * 課金処理の窓口。
 *
 * リリース時の作業（app-expo と同じ構成）:
 * 1. App Store Connect / Google Play Console に非消耗型商品
 *    `com.kuromakuaikin.ouchimente.plus10`（¥300）を登録
 * 2. react-native-iap を追加し、purchasePlus / restorePurchases の
 *    中身をストア呼び出しに差し替え（Expo Go では動かないため EAS Build が必要）
 * 3. IAP_TEST_MODE を false にする
 *
 * テストモード中は購入ボタンでそのまま解放される（開発・審査前の動作確認用）。
 *
 * __DEV__ に連動させているため、リリースビルドでは自動的に無効になり、
 * IAP接続前に誤って公開しても「無償解放」にはならない（購入不可エラーになる）。
 */
export const IAP_TEST_MODE: boolean = __DEV__;

export type PurchaseResult =
  | { status: "success" }
  | { status: "cancelled" }
  | { status: "error"; message: string };

export async function purchasePlus(): Promise<PurchaseResult> {
  if (IAP_TEST_MODE) {
    await setPlusUnlocked(true);
    return { status: "success" };
  }
  return {
    status: "error",
    message: "現在このバージョンでは購入できません。アプリを最新版に更新してください。",
  };
}

export async function restorePurchases(): Promise<PurchaseResult> {
  if (IAP_TEST_MODE) {
    await setPlusUnlocked(true);
    return { status: "success" };
  }
  return {
    status: "error",
    message: "現在このバージョンでは復元できません。アプリを最新版に更新してください。",
  };
}
