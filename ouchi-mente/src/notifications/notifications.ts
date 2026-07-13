import * as Notifications from "expo-notifications";
import { Platform } from "react-native";
import { parseDateString } from "@/domain/schedule";
import type { MaintenanceItem } from "@/domain/types";

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
  await Notifications.setNotificationChannelAsync("default", {
    name: "メンテナンス目安のお知らせ",
    importance: Notifications.AndroidImportance.DEFAULT,
  });
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
 * 通知が不要（無効・予定なし・過去日・権限なし）の場合は undefined。
 * 古い通知IDの破棄も行う。
 */
export async function rescheduleItemNotification(
  item: MaintenanceItem,
): Promise<string | undefined> {
  await cancelNotification(item.notificationId);

  if (!item.notificationEnabled || !item.nextDueDate) return undefined;
  if (!(await isPermissionGranted())) return undefined;

  const timingDays = item.notificationTimingDays ?? 0;
  const fireAt = parseDateString(item.nextDueDate);
  fireAt.setDate(fireAt.getDate() - timingDays);
  fireAt.setHours(NOTIFY_HOUR, 0, 0, 0);
  if (fireAt.getTime() <= Date.now()) return undefined;

  await ensureAndroidChannel();
  try {
    return await Notifications.scheduleNotificationAsync({
      content: {
        title: "おうちメンテ目安メモ",
        body: notificationBody(item, timingDays),
        data: { maintenanceItemId: item.id },
      },
      trigger: {
        type: Notifications.SchedulableTriggerInputTypes.DATE,
        date: fireAt,
      },
    });
  } catch {
    // 通知は補助機能。登録に失敗してもアプリの操作は継続できるようにする
    return undefined;
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
