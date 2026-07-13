import type {
  DueSection,
  DueStatus,
  IntervalUnit,
  MaintenanceItem,
} from "./types";

/**
 * 日付はすべて端末ローカルの暦日 (YYYY-MM-DD) で扱う。
 * 時刻・タイムゾーン起因のずれを避けるため、Date への変換は
 * 年月日成分だけを使って行う。
 */

export function toDateString(date: Date): string {
  const y = date.getFullYear();
  const m = `${date.getMonth() + 1}`.padStart(2, "0");
  const d = `${date.getDate()}`.padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export function parseDateString(value: string): Date {
  const [y, m, d] = value.split("-").map((v) => parseInt(v, 10));
  return new Date(y, (m ?? 1) - 1, d ?? 1);
}

export function isValidDateString(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = parseDateString(value);
  return toDateString(parsed) === value;
}

export function todayString(): string {
  return toDateString(new Date());
}

/** 月末を超えないように丸めながら月を加算する (1/31 + 1か月 → 2/28) */
function addMonthsClamped(date: Date, months: number): Date {
  const result = new Date(date.getFullYear(), date.getMonth() + months, 1);
  const daysInMonth = new Date(
    result.getFullYear(),
    result.getMonth() + 1,
    0,
  ).getDate();
  result.setDate(Math.min(date.getDate(), daysInMonth));
  return result;
}

export function addInterval(
  baseDate: string,
  value: number,
  unit: IntervalUnit,
): string {
  const base = parseDateString(baseDate);
  switch (unit) {
    case "day": {
      const d = new Date(base);
      d.setDate(d.getDate() + value);
      return toDateString(d);
    }
    case "week": {
      const d = new Date(base);
      d.setDate(d.getDate() + value * 7);
      return toDateString(d);
    }
    case "month":
      return toDateString(addMonthsClamped(base, value));
    case "year":
      return toDateString(addMonthsClamped(base, value * 12));
  }
}

/** 今日から見た残り日数。負の値は期限切れ日数 */
export function daysUntil(dateString: string, today = todayString()): number {
  const target = parseDateString(dateString).getTime();
  const base = parseDateString(today).getTime();
  return Math.round((target - base) / 86_400_000);
}

/**
 * 実施日と項目の周期設定から次回予定日を計算する。
 * interval 以外 (fixedDate / none) は自動計算しない。
 */
export function calculateNextDueDate(
  item: Pick<MaintenanceItem, "scheduleType" | "intervalValue" | "intervalUnit">,
  completedAt: string,
): string | undefined {
  if (
    item.scheduleType !== "interval" ||
    !item.intervalValue ||
    !item.intervalUnit
  ) {
    return undefined;
  }
  return addInterval(completedAt, item.intervalValue, item.intervalUnit);
}

export function dueStatusOf(
  item: Pick<MaintenanceItem, "nextDueDate">,
  today = todayString(),
): DueStatus {
  if (!item.nextDueDate) return "none";
  const days = daysUntil(item.nextDueDate, today);
  if (days < 0) return "overdue";
  if (days === 0) return "today";
  if (days <= 7) return "soon";
  return "scheduled";
}

export function dueSectionOf(
  item: Pick<MaintenanceItem, "nextDueDate">,
  today = todayString(),
): DueSection {
  if (!item.nextDueDate) return "none";
  const days = daysUntil(item.nextDueDate, today);
  if (days < 0) return "overdue";
  if (days === 0) return "today";
  if (days <= 7) return "within7";
  if (days <= 30) return "within30";
  return "later";
}

export const SECTION_ORDER: DueSection[] = [
  "overdue",
  "today",
  "within7",
  "within30",
  "later",
  "none",
];

/** ホーム画面用: 予定日の近い順に並べ、区分ごとにまとめる */
export function groupItemsBySection(
  items: MaintenanceItem[],
  today = todayString(),
): { section: DueSection; items: MaintenanceItem[] }[] {
  const sorted = [...items].sort((a, b) => {
    if (!a.nextDueDate && !b.nextDueDate) return a.name.localeCompare(b.name, "ja");
    if (!a.nextDueDate) return 1;
    if (!b.nextDueDate) return -1;
    return a.nextDueDate.localeCompare(b.nextDueDate);
  });
  const groups = new Map<DueSection, MaintenanceItem[]>();
  for (const item of sorted) {
    const section = dueSectionOf(item, today);
    const list = groups.get(section) ?? [];
    list.push(item);
    groups.set(section, list);
  }
  return SECTION_ORDER.filter((s) => groups.has(s)).map((section) => ({
    section,
    items: groups.get(section)!,
  }));
}

/** 「2026年8月10日」形式 */
export function formatDateJa(dateString: string): string {
  const d = parseDateString(dateString);
  return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`;
}

/** 残り日数の表示文言 */
export function remainingLabel(nextDueDate: string, today = todayString()): string {
  const days = daysUntil(nextDueDate, today);
  if (days < 0) return `${-days}日超過`;
  if (days === 0) return "今日";
  return `あと${days}日`;
}
