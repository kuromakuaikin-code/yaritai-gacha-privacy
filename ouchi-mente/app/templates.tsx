import React from "react";
import { useRouter } from "expo-router";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { NoteText } from "@/components/ui";
import { GUIDANCE_NOTE, TASK_TYPE_LABELS, intervalLabel } from "@/domain/labels";
import { TEMPLATE_GROUPS } from "@/domain/templates";
import { colors, fontSize, radius, spacing } from "@/theme";

export default function TemplatesScreen() {
  const router = useRouter();

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
    >
      <NoteText text={GUIDANCE_NOTE} />
      {TEMPLATE_GROUPS.map((group) => (
        <View key={group.title} style={styles.group}>
          <Text style={styles.groupTitle}>{group.title}</Text>
          {group.templates.map((template) => (
            <Pressable
              key={template.key}
              accessibilityRole="button"
              onPress={() =>
                router.push({
                  pathname: "/items/new",
                  params: { template: template.key },
                })
              }
              style={({ pressed }) => [styles.row, pressed && styles.rowPressed]}
            >
              <View style={styles.rowMain}>
                <Text style={styles.rowName}>{template.name}</Text>
                <Text style={styles.rowMeta}>
                  {TASK_TYPE_LABELS[template.taskType]}
                  {template.interval
                    ? `・目安 ${intervalLabel(
                        template.interval.value,
                        template.interval.unit,
                      )}`
                    : "・周期はご自身で設定"}
                </Text>
                {template.caution ? (
                  <Text style={styles.rowCaution}>{template.caution}</Text>
                ) : null}
              </View>
              <Text style={styles.rowChevron}>›</Text>
            </Pressable>
          ))}
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl, gap: spacing.md },
  group: { gap: spacing.sm },
  groupTitle: {
    fontSize: fontSize.md,
    fontWeight: "700",
    color: colors.textSecondary,
    marginTop: spacing.sm,
  },
  row: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.lg,
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.md,
  },
  rowPressed: { opacity: 0.7 },
  rowMain: { flex: 1, gap: spacing.xs },
  rowName: { fontSize: fontSize.lg, fontWeight: "600", color: colors.text },
  rowMeta: { fontSize: fontSize.sm, color: colors.textSecondary },
  rowCaution: { fontSize: fontSize.sm, color: colors.soon, lineHeight: 18 },
  rowChevron: { fontSize: fontSize.xl, color: colors.textMuted },
});
