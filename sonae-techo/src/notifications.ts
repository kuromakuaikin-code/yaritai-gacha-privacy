// 期限が近いアイテムのローカル通知（プレミアム限定機能）。
// react-native-iap と同様、require を try/catch で守る。
// Expo Go にはネイティブモジュールが無い場合があるため、その場合は何もしない。
import { StockItem, daysUntil, fmtDate } from './types';

let mod: any | null | undefined;

function lib(): any | null {
  if (mod !== undefined) return mod;
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    mod = require('expo-notifications');
  } catch {
    mod = null;
  }
  return mod;
}

export function notificationsAvailable(): boolean {
  return lib() !== null;
}

export async function requestNotificationPermission(): Promise<boolean> {
  const m = lib();
  if (!m) return false;
  try {
    const existing = await m.getPermissionsAsync();
    if (existing?.status === 'granted') return true;
    const asked = await m.requestPermissionsAsync();
    return asked?.status === 'granted';
  } catch {
    return false;
  }
}

const IDENTIFIER_PREFIX = 'sonae-expiry-';
const REMIND_DAYS_BEFORE = 7;

/**
 * 現在の登録内容に合わせて通知を作り直す（差分管理はせず、毎回すべて破棄してから再登録する単純な方式）。
 * 通知時刻は「期限の7日前・朝9時」。すでにその時刻を過ぎている場合はその項目の通知は作らない。
 */
export async function syncExpiryNotifications(items: StockItem[], enabled: boolean): Promise<void> {
  const m = lib();
  if (!m) return;
  try {
    await m.cancelAllScheduledNotificationsAsync();
  } catch {
    // 端末側の制約などで失敗しても致命的ではない
  }
  if (!enabled) return;

  for (const item of items) {
    if (!item.expiryDate || daysUntil(item.expiryDate) < 0) continue;
    const fireAt = new Date(item.expiryDate + 'T09:00:00');
    fireAt.setDate(fireAt.getDate() - REMIND_DAYS_BEFORE);
    if (fireAt.getTime() <= Date.now()) continue;

    try {
      const trigger = m.SchedulableTriggerInputTypes
        ? { type: m.SchedulableTriggerInputTypes.DATE, date: fireAt }
        : fireAt;
      await m.scheduleNotificationAsync({
        identifier: IDENTIFIER_PREFIX + item.id,
        content: {
          title: 'そなえ手帳',
          body: `「${item.name}」の期限が近づいています（${fmtDate(item.expiryDate)}）`,
        },
        trigger,
      });
    } catch {
      // 1件失敗しても他のスケジュールは続行する
    }
  }
}
