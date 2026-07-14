import React, { useCallback, useRef, useState } from "react";
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
import {
  DEFAULT_NOTIFY_HOUR,
  getNotifyHour,
  setNotifyHourAndReschedule,
} from "@/notifications/notifications";
import {
  FREE_ITEM_LIMIT,
  isPlusUnlocked,
} from "@/purchase/entitlement";
import { usePurchase } from "@/purchase/PurchaseProvider";
import { colors, fontSize, spacing } from "@/theme";

const NOTIFY_HOUR_OPTIONS = [7, 8, 9, 12, 18, 20, 21].map((hour) => ({
  value: hour,
  label: `${hour}時`,
}));

export default function SettingsScreen() {
  const router = useRouter();
  const [defaultEnabled, setDefaultEnabled] = useState(true);
  const [defaultTiming, setDefaultTiming] = useState(0);
  const [notifyHour, setNotifyHour] = useState(DEFAULT_NOTIFY_HOUR);
  const [plusUnlocked, setPlusUnlocked] = useState(false);
  const notifyHourChangeId = useRef(0);
  const { restoreUnlimited } = usePurchase();

  useFocusEffect(
    useCallback(() => {
      let active = true;
      (async () => {
        const enabled = await getSetting("defaultNotificationEnabled");
        const timing = await getSetting("defaultNotificationTimingDays");
        const hour = await getNotifyHour();
        const unlocked = await isPlusUnlocked();
        if (!active) return;
        if (enabled !== null) setDefaultEnabled(enabled === "1");
        if (timing !== null) setDefaultTiming(Number(timing));
        setNotifyHour(hour);
        setPlusUnlocked(unlocked);
      })();
      return () => {
        active = false;
      };
    }, []),
  );

  const handleRestore = async () => {
    const result = await restoreUnlimited();
    if (result.status === "success") {
      setPlusUnlocked(true);
      Alert.alert("復元しました", "無制限版が有効になりました。");
    } else if (result.status === "error") {
      Alert.alert("復元できませんでした", result.message);
    }
  };

  const updateDefaultEnabled = async (value: boolean) => {
    setDefaultEnabled(value);
    await setSetting("defaultNotificationEnabled", value ? "1" : "0");
  };

  const updateDefaultTiming = async (value: number) => {
    setDefaultTiming(value);
    await setSetting("defaultNotificationTimingDays", String(value));
  };

  const updateNotifyHour = async (hour: number) => {
    const changeId = ++notifyHourChangeId.current;
    setNotifyHour(hour);
    try {
      // 保存と全通知の張り替えを順番待ちにし、連打時の二重登録を防ぐ。
      await setNotifyHourAndReschedule(hour);
    } catch {
      // 後から選ばれた時刻の表示を、先に失敗した処理で巻き戻さない。
      if (notifyHourChangeId.current !== changeId) return;
      // 保存自体に失敗した場合は、DBに残っている時刻へ表示を戻す。
      setNotifyHour(await getNotifyHour());
      Alert.alert(
        "通知時刻を変更できませんでした",
        "もう一度お試しください。",
      );
    }
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
              // 無制限版の購入状態はデータ削除後も維持する
              const purchased = await isPlusUnlocked();
              await deleteAllData();
              await deleteAllStoredImagesAsync();
              await Notifications.cancelAllScheduledNotificationsAsync();
              if (purchased) {
                await setSetting("plusUnlocked", "1");
              }
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
        <ChipSelect
          label="通知する時刻（すべての項目に反映）"
          options={NOTIFY_HOUR_OPTIONS}
          value={notifyHour}
          onChange={updateNotifyHour}
        />
        <NoteText text={NOTIFICATION_NOTE} />
      </Card>

      <Text style={styles.sectionTitle}>登録数</Text>
      <Card>
        <View style={styles.versionRow}>
          <Text style={styles.versionLabel}>現在のプラン</Text>
          <Text style={styles.versionValue}>
            {plusUnlocked
              ? "無制限版（買い切り）"
              : `無料版（${FREE_ITEM_LIMIT}件まで）`}
          </Text>
        </View>
        {plusUnlocked ? null : (
          <LinkRow
            label="登録数を無制限にする"
            onPress={() => router.push("/paywall")}
          />
        )}
        <LinkRow label="購入の復元" onPress={handleRestore} />
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
        <LinkRow
          label="オープンソースライセンス"
          onPress={() => router.push("/settings/licenses")}
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
          記録はアプリのローカル領域に保存されます。端末の設定により、OSバックアップや端末移行の対象になる場合があります。
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
