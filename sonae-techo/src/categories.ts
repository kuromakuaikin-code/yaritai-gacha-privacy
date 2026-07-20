import { CategoryId } from './types';
import { FREE_CATEGORY_IDS } from './config';

export interface CategoryDef {
  id: CategoryId;
  label: string;
  unit: string;
  icon: string;
  /** 1人1日あたりの目安量。0の場合は fixedRecommend を使う */
  perPersonPerDay: number;
  /** 家族人数・日数によらない固定の推奨数（電池など） */
  fixedRecommend?: number;
}

// 目安量は内閣府・農林水産省などが公表している一般的な家庭備蓄の目安を参考にした概算値。
// 実際の必要量は各家庭の事情に応じて調整してください。
export const CATEGORIES: CategoryDef[] = [
  { id: 'water', label: '飲料水', unit: 'L', icon: '💧', perPersonPerDay: 3 },
  { id: 'food', label: '主食・レトルト食品', unit: '食', icon: '🍚', perPersonPerDay: 3 },
  { id: 'gas', label: 'カセットボンベ', unit: '本', icon: '🔥', perPersonPerDay: 0.3 },
  { id: 'toilet', label: 'トイレットペーパー', unit: 'ロール', icon: '🧻', perPersonPerDay: 0.2 },
  { id: 'battery', label: '乾電池', unit: '本', icon: '🔋', perPersonPerDay: 0, fixedRecommend: 20 },
  { id: 'other', label: 'その他', unit: '個', icon: '📦', perPersonPerDay: 0, fixedRecommend: 0 },
];

export const categoryOf = (id: CategoryId): CategoryDef =>
  CATEGORIES.find(c => c.id === id) ?? CATEGORIES[0];

export const isFreeCategory = (id: CategoryId): boolean =>
  (FREE_CATEGORY_IDS as readonly string[]).includes(id);

export const unlockedCategories = (premium: boolean): CategoryDef[] =>
  CATEGORIES.filter(c => premium || isFreeCategory(c.id));

export const recommendedAmount = (cat: CategoryDef, householdSize: number, targetDays: number): number => {
  if (cat.fixedRecommend != null) return cat.fixedRecommend;
  return Math.ceil(cat.perPersonPerDay * householdSize * targetDays);
};
