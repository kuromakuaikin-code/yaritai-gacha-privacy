import React, { useCallback, useState } from "react";
import { Redirect, Stack, useFocusEffect, useRouter } from "expo-router";
import { Pressable, SectionList, StyleSheet, Text, View } from "react-native";
import { ItemCard } from "@/components/ItemCard";
import { AppButton, EmptyState, LoadingView } from "@/components/ui";
import { listItems } from "@/db/items";
import { getSetting } from "@/db/settings";
import { SECTION_LABELS } from "@/domain/labels";
import { dueSectionOf, groupItemsBySection } from "@/domain/schedule";
import type { DueSection, MaintenanceItem } from "@/domain/types";
import { getItemLimit } from "@/purchase/entitlement";
import { colors, fontSize, radius, spacing } from "@/theme";

export default function HomeScreen() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [needsOnboarding, setNeedsOnboarding] = useState(false);
  const [items, setItems] = useState<MaintenanceItem[]>([]);
  const [itemLimit, setItemLimit] = useState(5);

  useFocusEffect(
    useCallback(() => {
      let active = true;
      (async () => {
        const onboarded = await getSetting("onboardingCompleted");
        const loaded = await listItems();
        const limit = await getItemLimit();
        if (!active) return;
        setNeedsOnboarding(onboarded !== "1");
        setItems(loaded);
        setItemLimit(limit);
        setLoading(false);
      })();
      return () => {
        active = false;
      };
    }, []),
  );

  if (loading) return <LoadingView />;
  if (needsOnboarding) return <Redirect href="/onboarding" />;

  const count = (section: DueSection) =>
    items.filter((i) => dueSectionOf(i) === section).length;
  const overdueCount = count("overdue");
  const todayCount = count("today");
  const soonCount = count("within7");

  const sections = groupItemsBySection(items).map((group) => ({
    title: SECTION_LABELS[group.section],
    data: group.items,
  }));

  return (
    <View style={styles.container}>
      <Stack.Screen
        options={{
          headerRight: () => (
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="設定"
              onPress={() => router.push("/settings")}
              hitSlop={8}
            >
              <Text style={styles.settingsLinkText}>⚙ 設定</Text>
            </Pressable>
          ),
        }}
      />
      <View style={styles.summary}>
        <SummaryChip label="期限切れ" value={overdueCount} highlight />
        <SummaryChip label="今日" value={todayCount} />
        <SummaryChip label="7日以内" value={soonCount} />
      </View>

      {items.length === 0 ? (
        <EmptyState
          title="まだ項目がありません"
          description="エアコンフィルターや洗濯槽など、お手入れしたい項目を追加してみましょう。"
        />
      ) : (
        <SectionList
          sections={sections}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.list}
          stickySectionHeadersEnabled={false}
          renderSectionHeader={({ section }) => (
            <Text style={styles.sectionHeader}>{section.title}</Text>
          )}
          renderItem={({ item }) => (
            <ItemCard
              item={item}
              onPress={() => router.push(`/items/${item.id}`)}
              onComplete={() => router.push(`/items/${item.id}/complete`)}
            />
          )}
        />
      )}

      <View style={styles.footerArea}>
        {items.length >= itemLimit - 1 ? (
          <Pressable
            accessibilityRole="button"
            onPress={() => router.push("/paywall")}
            style={styles.limitRow}
          >
            <Text style={styles.limitText}>
              登録枠 {items.length}/{itemLimit}件
              {items.length >= itemLimit ? "・枠を追加する ›" : ""}
            </Text>
          </Pressable>
        ) : null}
        <View style={styles.footer}>
          <AppButton
            title="テンプレートから追加"
            variant="secondary"
            onPress={() => router.push("/templates")}
            style={styles.footerButton}
          />
          <AppButton
            title="自分で追加"
            onPress={() => router.push("/items/new")}
            style={styles.footerButton}
          />
        </View>
      </View>
    </View>
  );
}

function SummaryChip({
  label,
  value,
  highlight,
}: {
  label: string;
  value: number;
  highlight?: boolean;
}) {
  const active = highlight && value > 0;
  return (
    <View style={[styles.chip, active && styles.chipHighlight]}>
      <Text style={[styles.chipValue, active && styles.chipValueHighlight]}>
        {value}
      </Text>
      <Text style={styles.chipLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  summary: {
    flexDirection: "row",
    gap: spacing.sm,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
    paddingBottom: spacing.sm,
  },
  chip: {
    flex: 1,
    backgroundColor: colors.surface,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border,
    alignItems: "center",
    paddingVertical: spacing.md,
    gap: 2,
  },
  chipHighlight: {
    borderColor: colors.overdue,
    backgroundColor: colors.overdueSoft,
  },
  chipValue: {
    fontSize: fontSize.xl,
    fontWeight: "700",
    color: colors.text,
  },
  chipValueHighlight: { color: colors.overdue },
  chipLabel: {
    fontSize: fontSize.sm,
    color: colors.textSecondary,
  },
  list: {
    padding: spacing.lg,
    paddingBottom: spacing.xxl,
  },
  sectionHeader: {
    fontSize: fontSize.md,
    fontWeight: "700",
    color: colors.textSecondary,
    marginTop: spacing.md,
    marginBottom: spacing.sm,
  },
  footerArea: {
    backgroundColor: colors.surface,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  limitRow: {
    paddingTop: spacing.md,
    paddingHorizontal: spacing.lg,
    alignItems: "center",
  },
  limitText: {
    fontSize: fontSize.sm,
    color: colors.textSecondary,
  },
  footer: {
    flexDirection: "row",
    gap: spacing.md,
    padding: spacing.lg,
  },
  footerButton: { flex: 1 },
  settingsLinkText: {
    fontSize: fontSize.md,
    color: colors.textSecondary,
  },
});
