import * as Notifications from "expo-notifications";
import { listItems, updateItem } from "@/db/items";
import { parseDateString } from "@/domain/schedule";
import type { MaintenanceItem } from "@/domain/types";
import {
  cancelNotification,
  getNotifyHour,
  isPermissionGranted,
  rescheduleItemNotification,
} from "./notifications";

function plannedFireAt(item: MaintenanceItem, notifyHour: number): Date | undefined {
  if (!item.notificationEnabled || !item.nextDueDate) return undefined;
  const fireAt = parseDateString(item.nextDueDate);
  fireAt.setDate(fireAt.getDate() - (item.notificationTimingDays ?? 0));
  fireAt.setHours(notifyHour, 0, 0, 0);
  return fireAt;
}

/**
 * DBに保存した通知IDとOS側の予約を起動時に照合する。
 *
 * OS更新や復元後に予約だけ失われた場合は、まだ通知時刻を迎えていない
 * 項目に限って再登録する。すでに通知時刻を過ぎた項目は、起動のたびに
 * 通知が繰り返されないようホームの「目安日超過」表示に任せる。
 */
export async function reconcileScheduledNotifications(): Promise<void> {
  if (!(await isPermissionGranted())) return;

  try {
    const [items, requests, notifyHour] = await Promise.all([
      listItems(),
      Notifications.getAllScheduledNotificationsAsync(),
      getNotifyHour(),
    ]);
    const itemsById = new Map(items.map((item) => [item.id, item]));
    const requestsById = new Map(
      requests.map((request) => [request.identifier, request]),
    );

    // 削除済みの項目や、DBが参照していない古い予約を片付ける。
    for (const request of requests) {
      const itemId = request.content.data?.maintenanceItemId;
      if (typeof itemId !== "string") continue;
      const item = itemsById.get(itemId);
      if (!item || item.notificationId !== request.identifier) {
        await cancelNotification(request.identifier);
        requestsById.delete(request.identifier);
      }
    }

    for (const item of items) {
      const fireAt = plannedFireAt(item, notifyHour);
      const hasPendingRequest =
        !!item.notificationId && requestsById.has(item.notificationId);

      if (!fireAt) {
        if (item.notificationId) {
          await cancelNotification(item.notificationId);
          await updateItem({ ...item, notificationId: undefined });
        }
        continue;
      }

      if (hasPendingRequest) continue;

      if (fireAt.getTime() <= Date.now()) {
        if (item.notificationId) {
          await updateItem({ ...item, notificationId: undefined });
        }
        continue;
      }

      try {
        const notificationId = await rescheduleItemNotification({
          ...item,
          notificationId: undefined,
        });
        if (notificationId) {
          await updateItem({ ...item, notificationId });
        }
      } catch {
        // 通知は補助機能。起動を妨げず、次回起動時にもう一度照合する。
      }
    }
  } catch {
    // OS側の通知一覧を取得できない場合も、通常のアプリ操作は継続する。
  }
}
