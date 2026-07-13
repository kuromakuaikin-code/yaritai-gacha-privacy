import React from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { StatusBadge } from "./StatusBadge";
import { TASK_TYPE_LABELS } from "@/domain/labels";
import { dueStatusOf, formatDateJa, remainingLabel } from "@/domain/schedule";
import type { MaintenanceItem } from "@/domain/types";
import { colors, fontSize, radius, spacing } from "@/theme";

export function ItemCard({
  item,
  onPress,
  onComplete,
}: {
  item: MaintenanceItem;
  onPress: () => void;
  onComplete: () => void;
}) {
  const status = dueStatusOf(item);
  const highlighted = status === "overdue" || status === "today";
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [
        styles.card,
        highlighted && styles.cardHighlighted,
        pressed && styles.cardPressed,
      ]}
    >
      <View style={styles.main}>
        <View style={styles.header}>
          <Text style={styles.name} numberOfLines={2}>
            {item.name}
          </Text>
          <StatusBadge status={status} />
        </View>
        <Text style={styles.meta} numberOfLines={1}>
          {[item.location, TASK_TYPE_LABELS[item.taskType]]
            .filter(Boolean)
            .join("・")}
        </Text>
        {item.nextDueDate ? (
          <Text style={styles.due}>
            次回目安：{formatDateJa(item.nextDueDate)}（
            {remainingLabel(item.nextDueDate)}）
          </Text>
        ) : (
          <Text style={styles.dueNone}>次回予定は設定されていません</Text>
        )}
      </View>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`${item.name}を完了として記録`}
        onPress={onComplete}
        style={({ pressed }) => [
          styles.completeButton,
          pressed && styles.cardPressed,
        ]}
      >
        <Text style={styles.completeButtonText}>完了</Text>
      </Pressable>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.lg,
    marginBottom: spacing.md,
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.md,
  },
  cardHighlighted: {
    borderColor: colors.overdue,
    borderWidth: 1.5,
  },
  cardPressed: { opacity: 0.7 },
  main: { flex: 1, gap: spacing.xs },
  header: {
    flexDirection: "row",
    alignItems: "flex-start",
    justifyContent: "space-between",
    gap: spacing.sm,
  },
  name: {
    flex: 1,
    fontSize: fontSize.lg,
    fontWeight: "600",
    color: colors.text,
  },
  meta: {
    fontSize: fontSize.sm,
    color: colors.textSecondary,
  },
  due: {
    fontSize: fontSize.md,
    color: colors.text,
  },
  dueNone: {
    fontSize: fontSize.md,
    color: colors.textMuted,
  },
  completeButton: {
    borderWidth: 1,
    borderColor: colors.primary,
    borderRadius: radius.md,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    backgroundColor: colors.primarySoft,
  },
  completeButtonText: {
    color: colors.primary,
    fontSize: fontSize.md,
    fontWeight: "700",
  },
});
