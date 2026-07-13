import React from "react";
import { StyleSheet, Text, View } from "react-native";
import { STATUS_LABELS } from "@/domain/labels";
import type { DueStatus } from "@/domain/types";
import { fontSize, radius, spacing, statusColors } from "@/theme";

const STATUS_ICONS: Record<DueStatus, string> = {
  overdue: "⏰",
  today: "📌",
  soon: "🔔",
  scheduled: "📅",
  none: "—",
};

/** 状態は色だけで区別せず、アイコン＋文字ラベルを必ず併記する */
export function StatusBadge({ status }: { status: DueStatus }) {
  const { fg, bg } = statusColors(status);
  return (
    <View style={[styles.badge, { backgroundColor: bg }]}>
      <Text style={[styles.text, { color: fg }]}>
        {STATUS_ICONS[status]} {STATUS_LABELS[status]}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    borderRadius: radius.pill,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    alignSelf: "flex-start",
  },
  text: {
    fontSize: fontSize.sm,
    fontWeight: "600",
  },
});
