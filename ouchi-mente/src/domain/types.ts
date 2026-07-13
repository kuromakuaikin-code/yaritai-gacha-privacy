export type MaintenanceCategory =
  | "air_conditioning"
  | "kitchen"
  | "laundry"
  | "bathroom"
  | "toilet"
  | "living"
  | "safety"
  | "outdoor"
  | "other";

export type MaintenanceTaskType =
  | "cleaning"
  | "replacement"
  | "inspection"
  | "refill"
  | "other";

export type ScheduleType = "interval" | "fixedDate" | "none";

export type IntervalUnit = "day" | "week" | "month" | "year";

export type MaintenanceItem = {
  id: string;
  name: string;
  category: MaintenanceCategory;
  taskType: MaintenanceTaskType;
  location?: string;
  manufacturer?: string;
  modelNumber?: string;
  note?: string;
  imageUri?: string;
  scheduleType: ScheduleType;
  intervalValue?: number;
  intervalUnit?: IntervalUnit;
  /** 次回予定日 (YYYY-MM-DD) */
  nextDueDate?: string;
  notificationEnabled: boolean;
  /** 予定日の何日前に通知するか (0 = 当日) */
  notificationTimingDays?: number;
  notificationId?: string;
  createdAt: string;
  updatedAt: string;
  archivedAt?: string;
};

export type MaintenanceHistory = {
  id: string;
  maintenanceItemId: string;
  /** 実施日 (YYYY-MM-DD) */
  completedAt: string;
  note?: string;
  imageUri?: string;
  calculatedNextDueDate?: string;
  createdAt: string;
  updatedAt: string;
};

/** 項目の状態表示。色だけに依存せず必ず文字ラベルを併記する */
export type DueStatus = "overdue" | "today" | "soon" | "scheduled" | "none";

/** ホーム画面の表示区分 */
export type DueSection =
  | "overdue"
  | "today"
  | "within7"
  | "within30"
  | "later"
  | "none";

export type NewMaintenanceItem = Omit<
  MaintenanceItem,
  "id" | "createdAt" | "updatedAt" | "notificationId"
>;

export type NewMaintenanceHistory = Omit<
  MaintenanceHistory,
  "id" | "createdAt" | "updatedAt"
>;
