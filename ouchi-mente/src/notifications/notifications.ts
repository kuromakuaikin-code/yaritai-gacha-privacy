import * as Notifications from "expo-notifications";
import { Platform } from "react-native";
import { parseDateString } from "@/domain/schedule";
import type { MaintenanceItem } from "@/domain/types";
import { updateItem } from "@/db/items";

/**
 * ローカル通知のみを使用する。外部サーバー・プッシュ通知は使わない。
 * 通知は「1項目につき最大1件」をルールとし、項目の作成・編集・完了・
 * 削除のたびに古い通知を破棄して登録し直す。
 */

const NOTIFY_HOUR = 9; // 通知は目安日の朝9時に表示する

export function configureNotificationHandler(): void {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowBanner: true,
      shouldShowList: true,
      shouldPlaySound: false,
      shouldSetBadge: false,
    }),
  });
}

async function ensureAndroidChannel(): Promise<void> {
  if (Platform.OS !== "android") return;
  try {
    await Notifications.setNotificationChannelAsync("default", {
      name: "メンテナンス目安のお知らせ",
      importance: Notifications.AndroidImportance.DEFAULT,
    });
  } catch {
    // Expo Go 等でチャンネルを作れなくても、許可の確認・取得は続行する
  }
}

export async function isPermissionGranted(): Promise<boolean> {
  const settings = await Notifications.getPermissionsAsync();
  return settings.granted || settings.status === "granted";
}

export async function requestPermission(): Promise<boolean> {
  await ensureAndroidChannel();
  const current = await Notifications.getPermissionsAsync();
  if (current.granted) return true;
  if (!current.canAskAgain) return false;
  const result = await Notifications.requestPermissionsAsync();
  return result.granted || result.status === "granted";
}

function notificationBody(item: MaintenanceItem, timingDays: number): string {
  const target = item.location ? `${item.location}の${item.name}` : item.name;
  if (timingDays <= 0) return `「${target}」のお手入れ目安日です。`;
  return `「${target}」のお手入れ目安日まであと${timingDays}日です。`;
}

/**
 * 項目の通知を登録し直し、新しい通知IDを返す。
 * 通知が不要（無効・予定なし・過去日）の場合は undefined。
 */
export async function rescheduleItemNotification(
  item: MaintenanceItem,
): Promise<string | undefined> {
  if (!item.notificationEnabled || !item.nextDueDate) return undefined;
  if (!(await isPermissionGranted())) {
    throw new Error("通知の許可が必要です");
  }

  const timingDays = item.notificationTimingDays ?? 0;
  const fireAt = parseDateString(item.nextDueDate);
  fireAt.setDate(fireAt.getDate() - timingDays);
  fireAt.setHours(NOTIFY_HOUR, 0, 0, 0);
  // 通知時刻をすでに過ぎている場合は登録しない。
  // 直後に発火させると「あと◯日です」という本文が実際の残り日数と食い違い、
  // 起動時照合（reconcile）の「過ぎた分は画面表示に任せる」方針とも矛盾する
  if (fireAt.getTime() <= Date.now()) return undefined;

  await ensureAndroidChannel();
  try {
    return await Notifications.scheduleNotificationAsync({
      content: {
        title: "家の手入れ記録",
        body: notificationBody(item, timingDays),
        data: { maintenanceItemId: item.id },
      },
      trigger: {
        type: Notifications.SchedulableTriggerInputTypes.DATE,
        date: fireAt,
        // Androidで作成済みのチャンネルを使う（未指定だと内部の
        // フォールバックチャンネル経由になり、名前・重要度の設定が効かない）
        channelId: "default",
      },
    });
  } catch {
    // 通知は補助機能。登録に失敗してもアプリの操作は継続できるようにする
    throw new Error("通知を登録できませんでした");
  }
}

export type NotificationSyncResult =
  | { status: "scheduled"; notificationId: string }
  | { status: "not-needed" }
  | { status: "permission-denied" }
  | { status: "failed" };

/**
 * 記録を先にSQLiteへ保存した後、通知を補助的に同期する。
 * ここで失敗しても、記録・履歴・写真を失敗扱いにしない。
 */
export async function syncItemNotification(
  item: MaintenanceItem,
  previousNotificationId?: string,
): Promise<NotificationSyncResult> {
  await cancelNotification(previousNotificationId);

  if (!item.notificationEnabled || !item.nextDueDate) {
    return { status: "not-needed" };
  }
  try {
    if (!(await isPermissionGranted())) {
      return { status: "permission-denied" };
    }
    const notificationId = await rescheduleItemNotification(item);
    if (!notificationId) return { status: "not-needed" };
    await updateItem({ ...item, notificationId });
    return { status: "scheduled", notificationId };
  } catch {
    return { status: "failed" };
  }
}

export async function cancelNotification(
  notificationId: string | undefined,
): Promise<void> {
  if (!notificationId) return;
  try {
    await Notifications.cancelScheduledNotificationAsync(notificationId);
  } catch {
    // すでに存在しない通知IDは無視する
  }
}
