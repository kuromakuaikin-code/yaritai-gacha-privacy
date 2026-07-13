import React, { useCallback, useState } from "react";
import Constants from "expo-constants";
import * as Notifications from "expo-notifications";
import { useFocusEffect, useRouter } from "expo-router";
import {
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { ChipSelect, SwitchRow } from "@/components/form";
import { AppButton, Card, NoteText } from "@/components/ui";
import { deleteAllData } from "@/db/database";
import { getSetting, setSetting } from "@/db/settings";
import { NOTIFICATION_NOTE, NOTIFICATION_TIMING_OPTIONS } from "@/domain/labels";
import { deleteAllStoredImagesAsync } from "@/media/images";
import { colors, fontSize, spacing } from "@/theme";

export default function SettingsScreen() {
  const router = useRouter();
  const [defaultEnabled, setDefaultEnabled] = useState(true);
  const [defaultTiming, setDefaultTiming] = useState(0);

  useFocusEffect(
    useCallback(() => {
      let active = true;
      (async () => {
        const enabled = await getSetting("defaultNotificationEnabled");
        const timing = await getSetting("defaultNotificationTimingDays");
        if (!active) return;
        if (enabled !== null) setDefaultEnabled(enabled === "1");
        if (timing !== null) setDefaultTiming(Number(timing));
      })();
      return () => {
        active = false;
      };
    }, []),
  );

  const updateDefaultEnabled = async (value: boolean) => {
    setDefaultEnabled(value);
    await setSetting("defaultNotificationEnabled", value ? "1" : "0");
  };

  const updateDefaultTiming = async (value: number) => {
    setDefaultTiming(value);
    await setSetting("defaultNotificationTimingDays", String(value));
  };

  const confirmDeleteAll = () => {
    Alert.alert(
      "すべてのデータを削除しますか？",
      "登録した項目・履歴・写真・設定がすべて削除されます。この操作は取り消せません。",
      [
        { text: "キャンセル", style: "cancel" },
        {
          text: "削除する",
          style: "destructive",
          onPress: async () => {
            try {
              await Notifications.cancelAllScheduledNotificationsAsync();
              await deleteAllStoredImagesAsync();
              await deleteAllData();
              Alert.alert("削除しました", "すべてのデータを削除しました。");
              router.back();
            } catch {
              Alert.alert("削除エラー", "データを削除できませんでした。");
            }
          },
        },
      ],
    );
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.sectionTitle}>通知の初期設定</Text>
      <Card>
        <SwitchRow
          label="新しい項目の通知を最初からオンにする"
          value={defaultEnabled}
          onChange={updateDefaultEnabled}
        />
        {defaultEnabled ? (
          <ChipSelect
            label="通知するタイミング（初期値）"
            options={NOTIFICATION_TIMING_OPTIONS.map((o) => ({
              value: o.days,
              label: o.label,
            }))}
            value={defaultTiming}
            onChange={updateDefaultTiming}
          />
        ) : null}
        <NoteText text={NOTIFICATION_NOTE} />
      </Card>

      <Text style={styles.sectionTitle}>このアプリについて</Text>
      <Card style={styles.linkCard}>
        <LinkRow label="利用規約" onPress={() => router.push("/settings/terms")} />
        <LinkRow
          label="プライバシーポリシー"
          onPress={() => router.push("/settings/privacy")}
        />
        <LinkRow
          label="免責事項"
          onPress={() => router.push("/settings/disclaimer")}
        />
        <LinkRow
          label="アプリについて"
          onPress={() => router.push("/settings/about")}
        />
        <View style={styles.versionRow}>
          <Text style={styles.versionLabel}>バージョン</Text>
          <Text style={styles.versionValue}>
            {Constants.expoConfig?.version ?? "1.0.0"}
          </Text>
        </View>
      </Card>

      <Text style={styles.sectionTitle}>データ</Text>
      <Card>
        <AppButton
          title="すべてのデータを削除"
          variant="danger"
          onPress={confirmDeleteAll}
        />
        <Text style={styles.dataNote}>
          データはこの端末の中だけに保存されています。バックアップ・復元機能は今後のバージョンで対応予定です。
        </Text>
      </Card>
    </ScrollView>
  );
}

function LinkRow({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.linkRow, pressed && { opacity: 0.6 }]}
    >
      <Text style={styles.linkLabel}>{label}</Text>
      <Text style={styles.linkChevron}>›</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl, gap: spacing.md },
  sectionTitle: {
    fontSize: fontSize.md,
    fontWeight: "700",
    color: colors.textSecondary,
    marginTop: spacing.sm,
  },
  linkCard: { paddingVertical: spacing.sm },
  linkRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingVertical: spacing.md,
  },
  linkLabel: { fontSize: fontSize.md, color: colors.text },
  linkChevron: { fontSize: fontSize.lg, color: colors.textMuted },
  versionRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    paddingVertical: spacing.md,
  },
  versionLabel: { fontSize: fontSize.md, color: colors.text },
  versionValue: { fontSize: fontSize.md, color: colors.textSecondary },
  dataNote: {
    fontSize: fontSize.sm,
    color: colors.textMuted,
    marginTop: spacing.md,
    lineHeight: 19,
  },
});
