import * as Notifications from "expo-notifications";
import { Platform } from "react-native";
import { TASK_TYPE_LABELS } from "@/domain/labels";
import { parseDateString } from "@/domain/schedule";
import type { MaintenanceItem } from "@/domain/types";
import { listItems, updateItemNotificationId } from "@/db/items";
import { getSetting, setSetting } from "@/db/settings";

/**
 * ローカル通知のみを使用する。外部サーバー・プッシュ通知は使わない。
 * 通知は「1項目につき最大1件」をルールとし、項目の作成・編集・完了・
 * 削除のたびに古い通知を破棄して登録し直す。
 */

export const DEFAULT_NOTIFY_HOUR = 9;

let allNotificationUpdateQueue: Promise<void> = Promise.resolve();

/** 通知を表示する時刻（0〜23時）。設定画面で変更できる */
export async function getNotifyHour(): Promise<number> {
  const stored = await getSetting("notificationHour");
  const hour = stored === null ? NaN : Number(stored);
  return Number.isInteger(hour) && hour >= 0 && hour <= 23
    ? hour
    : DEFAULT_NOTIFY_HOUR;
}

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
  // 作業種別を入れて「何をする日か」が通知だけで分かるようにする。
  // 「その他」は文になじまないため汎用の「お手入れ」で表す
  const task =
    item.taskType === "other" ? "お手入れ" : TASK_TYPE_LABELS[item.taskType];
  if (timingDays <= 0) return `「${target}」の${task}の目安日です。`;
  return `「${target}」の${task}の目安日まであと${timingDays}日です。`;
}

/**
 * 項目の通知を登録し直し、新しい通知IDを返す。
 * 通知が不要（無効・予定なし・過去日）の場合は undefined。
 */
export async function rescheduleItemNotification(
  item: MaintenanceItem,
  notifyHour?: number,
): Promise<string | undefined> {
  if (!item.notificationEnabled || !item.nextDueDate) return undefined;
  if (!(await isPermissionGranted())) {
    throw new Error("通知の許可が必要です");
  }

  const timingDays = item.notificationTimingDays ?? 0;
  const fireAt = parseDateString(item.nextDueDate);
  fireAt.setDate(fireAt.getDate() - timingDays);
  fireAt.setHours(notifyHour ?? await getNotifyHour(), 0, 0, 0);
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
        // 起動時照合で、現在の通知時刻設定と一致する予約か確認する。
        data: {
          maintenanceItemId: item.id,
          scheduledFor: fireAt.toISOString(),
        },
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
  options?: {
    notifyHour?: number;
    preservePreviousOnFailure?: boolean;
  },
): Promise<NotificationSyncResult> {
  if (!item.notificationEnabled || !item.nextDueDate) {
    await cancelNotification(previousNotificationId);
    if (item.notificationId) {
      await updateItemNotificationId(item.id, undefined);
    }
    return { status: "not-needed" };
  }

  if (!options?.preservePreviousOnFailure) {
    await cancelNotification(previousNotificationId);
  }

  try {
    if (!(await isPermissionGranted())) {
      return { status: "permission-denied" };
    }
    const notificationId = await rescheduleItemNotification(
      item,
      options?.notifyHour,
    );
    if (!notificationId) {
      await cancelNotification(previousNotificationId);
      if (item.notificationId) {
        await updateItemNotificationId(item.id, undefined);
      }
      return { status: "not-needed" };
    }
    try {
      await updateItemNotificationId(item.id, notificationId);
    } catch {
      // DBが新しいIDを保持できなければ、参照不能な通知をOS側に残さない。
      await cancelNotification(notificationId);
      throw new Error("通知IDを保存できませんでした");
    }
    if (options?.preservePreviousOnFailure) {
      await cancelNotification(previousNotificationId);
    }
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

/**
 * 全項目の通知を現在の設定（通知時刻など）で登録し直す。
 * 通知時刻を変更したときに呼ぶ。失敗した項目があっても続行する。
 */
async function rescheduleAllNotificationsAtHour(notifyHour: number): Promise<void> {
  const items = await listItems();
  for (const item of items) {
    await syncItemNotification(item, item.notificationId, {
      notifyHour,
      // 時刻変更の張り替えに失敗した場合は、通知自体を失うより古い予約を残す。
      preservePreviousOnFailure: true,
    });
  }
}

function enqueueAllNotificationUpdate(operation: () => Promise<void>): Promise<void> {
  const task = allNotificationUpdateQueue.then(operation, operation);
  allNotificationUpdateQueue = task.catch(() => {
    // 1回の失敗で、後から並んだ時刻変更まで止めない。
  });
  return task;
}

export function rescheduleAllNotifications(): Promise<void> {
  return enqueueAllNotificationUpdate(async () => {
    await rescheduleAllNotificationsAtHour(await getNotifyHour());
  });
}

/** 通知時刻の保存と全通知の張り替えを、他の時刻変更と重ならないよう実行する。 */
export function setNotifyHourAndReschedule(notifyHour: number): Promise<void> {
  if (!Number.isInteger(notifyHour) || notifyHour < 0 || notifyHour > 23) {
    return Promise.reject(new Error("通知時刻が不正です"));
  }
  return enqueueAllNotificationUpdate(async () => {
    await setSetting("notificationHour", String(notifyHour));
    await rescheduleAllNotificationsAtHour(notifyHour);
  });
}

/**
 * 開発用: この項目の通知を「本番と同じ文面」で5秒後に配信する。
 * OSの予約やDBの通知IDには触れない。リリースビルドのUIからは呼ばれない。
 */
export async function sendTestNotificationForItem(
  item: MaintenanceItem,
): Promise<boolean> {
  if (!(await requestPermission())) return false;
  await Notifications.scheduleNotificationAsync({
    content: {
      title: "家の手入れ記録",
      body: notificationBody(item, item.notificationTimingDays ?? 0),
    },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL,
      seconds: 5,
      channelId: "default",
    },
  });
  return true;
}
