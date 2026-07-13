import type {
  IntervalUnit,
  MaintenanceCategory,
  MaintenanceTaskType,
} from "./types";

/**
 * 初期テンプレート。
 * 周期はすべて「一般的な目安」であり、登録時にユーザーが自由に変更できる。
 * 安全性・故障・寿命を判定する表現は使わない。
 */
export type MaintenanceTemplate = {
  key: string;
  name: string;
  category: MaintenanceCategory;
  taskType: MaintenanceTaskType;
  /** 未設定のテンプレートはユーザー自身が製品指定の周期を入力する */
  interval?: { value: number; unit: IntervalUnit };
  caution?: string;
};

export type TemplateGroup = {
  title: string;
  templates: MaintenanceTemplate[];
};

export const TEMPLATE_GROUPS: TemplateGroup[] = [
  {
    title: "エアコン",
    templates: [
      {
        key: "ac_filter",
        name: "エアコンフィルター",
        category: "air_conditioning",
        taskType: "cleaning",
        interval: { value: 30, unit: "day" },
        caution: "使用環境や製品によって異なります。",
      },
      {
        key: "ac_inside",
        name: "エアコン内部",
        category: "air_conditioning",
        taskType: "inspection",
        interval: { value: 1, unit: "year" },
        caution: "分解作業は専門業者への相談をおすすめします。",
      },
    ],
  },
  {
    title: "キッチン",
    templates: [
      {
        key: "kitchen_fan_filter",
        name: "換気扇フィルター",
        category: "kitchen",
        taskType: "cleaning",
        interval: { value: 3, unit: "month" },
      },
      {
        key: "range_hood",
        name: "レンジフード",
        category: "kitchen",
        taskType: "cleaning",
        interval: { value: 6, unit: "month" },
      },
      {
        key: "water_filter",
        name: "浄水器カートリッジ",
        category: "kitchen",
        taskType: "replacement",
        caution: "交換時期は製品によって異なります。製品指定の周期を入力してください。",
      },
    ],
  },
  {
    title: "洗濯機",
    templates: [
      {
        key: "washer_tub",
        name: "洗濯槽",
        category: "laundry",
        taskType: "cleaning",
        interval: { value: 1, unit: "month" },
      },
    ],
  },
  {
    title: "浴室",
    templates: [
      {
        key: "bath_fan",
        name: "浴室換気扇",
        category: "bathroom",
        taskType: "cleaning",
        interval: { value: 3, unit: "month" },
      },
    ],
  },
  {
    title: "空調・加湿",
    templates: [
      {
        key: "air_purifier_filter",
        name: "空気清浄機フィルター",
        category: "air_conditioning",
        taskType: "cleaning",
        interval: { value: 30, unit: "day" },
      },
      {
        key: "ventilation_filter",
        name: "24時間換気フィルター",
        category: "air_conditioning",
        taskType: "cleaning",
        interval: { value: 3, unit: "month" },
        caution: "設置環境や製品によって異なります。",
      },
    ],
  },
  {
    title: "防災設備",
    templates: [
      {
        key: "smoke_alarm_test",
        name: "火災警報器の作動確認",
        category: "safety",
        taskType: "inspection",
        interval: { value: 6, unit: "month" },
        caution: "製品の説明書、自治体、消防機関の案内を優先してください。",
      },
      {
        key: "smoke_alarm_battery",
        name: "火災警報器の電池",
        category: "safety",
        taskType: "replacement",
        caution: "交換期限は製品によって異なります。製品指定の期限を入力してください。",
      },
    ],
  },
  {
    title: "その他",
    templates: [
      {
        key: "water_heater",
        name: "給湯器",
        category: "other",
        taskType: "inspection",
        caution:
          "異音・異臭・煙・動作異常がある場合は、アプリの予定日を待たずに使用を中止し、専門業者へ相談してください。",
      },
    ],
  },
];

export function findTemplate(key: string): MaintenanceTemplate | undefined {
  for (const group of TEMPLATE_GROUPS) {
    const found = group.templates.find((t) => t.key === key);
    if (found) return found;
  }
  return undefined;
}
