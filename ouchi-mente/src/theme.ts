/**
 * デザイントークン。
 * コンセプト: 清潔感・安心感・優しさ。
 * 目安日を過ぎた場合も「危険」を連想させる強い赤は使わず、
 * 状態は色 + 文字ラベルの併用で伝える。
 */
export const colors = {
  primary: "#2E8B84",
  primarySoft: "#E4F2F1",
  background: "#F7F9F8",
  surface: "#FFFFFF",
  border: "#E3E8E6",
  text: "#26332F",
  textSecondary: "#5F6E69",
  textMuted: "#8A9691",

  overdue: "#C05621",
  overdueSoft: "#FBEDE3",
  today: "#2E8B84",
  todaySoft: "#E4F2F1",
  soon: "#B7791F",
  soonSoft: "#FAF3E0",
  scheduled: "#5F6E69",
  scheduledSoft: "#EEF1F0",
  none: "#8A9691",
  noneSoft: "#F1F3F2",

  danger: "#B4423E",
  dangerSoft: "#F9ECEB",
} as const;

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
} as const;

export const fontSize = {
  sm: 13,
  md: 15,
  lg: 17,
  xl: 20,
  title: 24,
} as const;

export const radius = {
  sm: 8,
  md: 12,
  lg: 16,
  pill: 999,
} as const;

import type { DueStatus } from "@/domain/types";

export function statusColors(status: DueStatus): {
  fg: string;
  bg: string;
} {
  switch (status) {
    case "overdue":
      return { fg: colors.overdue, bg: colors.overdueSoft };
    case "today":
      return { fg: colors.today, bg: colors.todaySoft };
    case "soon":
      return { fg: colors.soon, bg: colors.soonSoft };
    case "scheduled":
      return { fg: colors.scheduled, bg: colors.scheduledSoft };
    case "none":
      return { fg: colors.none, bg: colors.noneSoft };
  }
}
