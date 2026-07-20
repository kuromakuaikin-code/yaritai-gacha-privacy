export type CategoryId = 'water' | 'food' | 'gas' | 'toilet' | 'battery' | 'other';

export interface StockItem {
  id: string;
  name: string;
  category: CategoryId;
  quantity: number;
  unit: string;
  expiryDate?: string; // "yyyy-MM-dd"
  memo: string;
  createdAt: number;
  updatedAt: number;
}

export interface Db {
  items: StockItem[];
  householdSize: number;
  targetDays: number;
  premium?: boolean;
  adFree?: boolean;
  notifyEnabled?: boolean;
  firstRun?: number;
}

export const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 8);

export const todayISO = (offsetDays = 0) => {
  const t = new Date();
  t.setDate(t.getDate() + offsetDays);
  const m = String(t.getMonth() + 1).padStart(2, '0');
  const d = String(t.getDate()).padStart(2, '0');
  return `${t.getFullYear()}-${m}-${d}`;
};

export const fmtDate = (iso?: string) => {
  if (!iso) return '';
  const [y, m, d] = iso.split('-');
  return `${y}/${Number(m)}/${Number(d)}`;
};

/** 今日からの残り日数。負の値は期限切れ */
export const daysUntil = (iso: string): number => {
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  const target = new Date(iso + 'T00:00:00');
  return Math.round((target.getTime() - now.getTime()) / 86400000);
};

export const daysUntilLabel = (iso: string): string => {
  const n = daysUntil(iso);
  if (n < 0) return `期限切れ（${-n}日前）`;
  if (n === 0) return '今日が期限';
  return `あと${n}日`;
};

export const sampleItem = (): StockItem => ({
  id: uid(),
  name: 'サンプル：飲料水 2L×6本',
  category: 'water',
  quantity: 12,
  unit: 'L',
  expiryDate: todayISO(20),
  memo: '玄関収納の上段',
  createdAt: Date.now(),
  updatedAt: Date.now(),
});
