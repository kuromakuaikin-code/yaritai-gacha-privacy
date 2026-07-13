import type {
  DueSection,
  DueStatus,
  IntervalUnit,
  MaintenanceCategory,
  MaintenanceTaskType,
  ScheduleType,
} from "./types";

export const CATEGORY_LABELS: Record<MaintenanceCategory, string> = {
  air_conditioning: "空調・加湿",
  kitchen: "キッチン",
  laundry: "洗濯",
  bathroom: "浴室",
  toilet: "トイレ",
  living: "リビング",
  safety: "防災設備",
  outdoor: "屋外",
  other: "その他",
};

export const TASK_TYPE_LABELS: Record<MaintenanceTaskType, string> = {
  cleaning: "掃除",
  replacement: "交換",
  inspection: "点検",
  refill: "補充",
  other: "その他",
};

export const SCHEDULE_TYPE_LABELS: Record<ScheduleType, string> = {
  interval: "周期で設定",
  fixedDate: "日付を直接指定",
  none: "次回予定なし",
};

export const INTERVAL_UNIT_LABELS: Record<IntervalUnit, string> = {
  day: "日",
  week: "週間",
  month: "か月",
  year: "年",
};

export const STATUS_LABELS: Record<DueStatus, string> = {
  overdue: "目安日超過",
  today: "今日",
  soon: "もうすぐ",
  scheduled: "予定あり",
  none: "予定なし",
};

export const SECTION_LABELS: Record<DueSection, string> = {
  overdue: "目安日を過ぎています",
  today: "今日",
  within7: "7日以内",
  within30: "30日以内",
  later: "それ以降",
  none: "次回予定なし",
};

export const LOCATION_SUGGESTIONS = [
  "リビング",
  "寝室",
  "キッチン",
  "浴室",
  "洗面所",
  "トイレ",
  "玄関",
  "ベランダ",
  "屋外",
  "その他",
];

export const NOTIFICATION_TIMING_OPTIONS: { days: number; label: string }[] = [
  { days: 0, label: "当日" },
  { days: 1, label: "1日前" },
  { days: 3, label: "3日前" },
  { days: 7, label: "7日前" },
  { days: 30, label: "30日前" },
];

export function notificationTimingLabel(days: number): string {
  const option = NOTIFICATION_TIMING_OPTIONS.find((o) => o.days === days);
  return option ? option.label : `${days}日前`;
}

export function intervalLabel(value: number, unit: IntervalUnit): string {
  return `${value}${INTERVAL_UNIT_LABELS[unit]}ごと`;
}

/** 目安に関する短い注意文。周期・予定日を表示する画面で必ず添える */
export const GUIDANCE_NOTE =
  "表示される周期は一般的な目安です。実際のお手入れ・交換・点検時期は、製品の取扱説明書やメーカーの案内を優先してください。";

/** 通知に関する注意文 */
export const NOTIFICATION_NOTE =
  "通知は、端末やOSの設定、集中モード、電池節約設定などにより表示されない場合があります。通知は補助機能としてご利用ください。";
