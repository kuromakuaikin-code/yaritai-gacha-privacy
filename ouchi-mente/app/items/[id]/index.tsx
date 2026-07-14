import React, { useCallback, useState } from "react";
import { useFocusEffect, useLocalSearchParams, useRouter } from "expo-router";
import {
  Alert,
  Image,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { StatusBadge } from "@/components/StatusBadge";
import { AppButton, Card, EmptyState, LoadingView, NoteText } from "@/components/ui";
import { listHistoryForItem } from "@/db/history";
import { deleteItem, getItem } from "@/db/items";
import {
  CATEGORY_LABELS,
  GUIDANCE_NOTE,
  SCHEDULE_TYPE_LABELS,
  TASK_TYPE_LABELS,
  intervalLabel,
  notificationTimingLabel,
} from "@/domain/labels";
import { dueStatusOf, formatDateJa, remainingLabel } from "@/domain/schedule";
import type { MaintenanceHistory, MaintenanceItem } from "@/domain/types";
import { deleteStoredImageAsync, resolveImageUri } from "@/media/images";
import {
  cancelNotification,
  sendTestNotificationForItem,
} from "@/notifications/notifications";
import { colors, fontSize, radius, spacing } from "@/theme";

export default function ItemDetailScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const [item, setItem] = useState<MaintenanceItem | null>(null);
  const [history, setHistory] = useState<MaintenanceHistory[]>([]);
  const [loading, setLoading] = useState(true);

  useFocusEffect(
    useCallback(() => {
      let active = true;
      (async () => {
        const loaded = await getItem(id);
        const loadedHistory = await listHistoryForItem(id);
        if (!active) return;
        setItem(loaded);
        setHistory(loadedHistory);
        setLoading(false);
      })();
      return () => {
        active = false;
      };
    }, [id]),
  );

  if (loading) return <LoadingView />;
  if (!item) {
    return (
      <EmptyState
        title="項目が見つかりません"
        description="すでに削除されている可能性があります。"
      />
    );
  }

  const confirmDelete = () => {
    Alert.alert(
      "項目を削除しますか？",
      `「${item.name}」と、その実施履歴もすべて削除されます。この操作は取り消せません。`,
      [
        { text: "キャンセル", style: "cancel" },
        {
          text: "削除する",
          style: "destructive",
          onPress: async () => {
            try {
              await deleteItem(item.id);
              await deleteStoredImageAsync(item.imageUri);
              for (const h of history) {
                await deleteStoredImageAsync(h.imageUri);
              }
              await cancelNotification(item.notificationId);
              router.back();
            } catch {
              Alert.alert("削除エラー", "削除できませんでした。もう一度お試しください。");
            }
          },
        },
      ],
    );
  };

  const lastCompleted = history[0]?.completedAt;

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <Card style={styles.headerCard}>
          <View style={styles.headerRow}>
            <Text style={styles.name}>{item.name}</Text>
            <StatusBadge status={dueStatusOf(item)} />
          </View>
          <Text style={styles.meta}>
            {[
              item.location,
              TASK_TYPE_LABELS[item.taskType],
              CATEGORY_LABELS[item.category],
            ]
              .filter(Boolean)
              .join("・")}
          </Text>
          {item.nextDueDate ? (
            <Text style={styles.due}>
              次回予定日：{formatDateJa(item.nextDueDate)}（
              {remainingLabel(item.nextDueDate)}）
            </Text>
          ) : (
            <Text style={styles.dueNone}>次回予定は設定されていません</Text>
          )}
        </Card>

        <Card>
          <DetailRow
            label="前回実施日"
            value={lastCompleted ? formatDateJa(lastCompleted) : "記録なし"}
          />
          <DetailRow
            label="次回目安の設定"
            value={
              item.scheduleType === "interval" &&
              item.intervalValue &&
              item.intervalUnit
                ? intervalLabel(item.intervalValue, item.intervalUnit)
                : SCHEDULE_TYPE_LABELS[item.scheduleType]
            }
          />
          <DetailRow
            label="通知"
            value={
              item.notificationEnabled
                ? notificationTimingLabel(item.notificationTimingDays ?? 0)
                : "通知しない"
            }
          />
          {item.manufacturer ? (
            <DetailRow label="メーカー名" value={item.manufacturer} />
          ) : null}
          {item.modelNumber ? (
            <DetailRow label="型番" value={item.modelNumber} />
          ) : null}
          {item.note ? <DetailRow label="メモ" value={item.note} /> : null}
        </Card>

        {item.imageUri ? (
          <Image
            source={{ uri: resolveImageUri(item.imageUri) }}
            style={styles.image}
          />
        ) : null}

        <NoteText text={GUIDANCE_NOTE} />

        <View style={styles.historyHeader}>
          <Text style={styles.historyTitle}>実施履歴</Text>
          {history.length > 0 ? (
            <Text
              style={styles.historyLink}
              onPress={() => router.push(`/items/${item.id}/history`)}
            >
              すべて見る（{history.length}件）›
            </Text>
          ) : null}
        </View>
        {history.length === 0 ? (
          <Text style={styles.historyEmpty}>まだ実施記録がありません。</Text>
        ) : (
          history.slice(0, 3).map((h) => (
            <Card key={h.id} style={styles.historyCard}>
              <Text style={styles.historyDate}>{formatDateJa(h.completedAt)}</Text>
              {h.note ? <Text style={styles.historyNote}>{h.note}</Text> : null}
            </Card>
          ))
        )}

        <View style={styles.actions}>
          <AppButton
            title="編集"
            variant="secondary"
            onPress={() => router.push(`/items/${item.id}/edit`)}
          />
          <AppButton title="削除" variant="danger" onPress={confirmDelete} />
        </View>

        {__DEV__ ? (
          <AppButton
            title="この項目の通知を今すぐ試す（開発用）"
            variant="ghost"
            onPress={async () => {
              const sent = await sendTestNotificationForItem(item);
              Alert.alert(
                sent ? "5秒後に届きます" : "通知が許可されていません",
                sent
                  ? "本番と同じ文面です。ホーム画面に戻って確認してください。"
                  : "端末の設定で通知を許可してください。",
              );
            }}
          />
        ) : null}
      </ScrollView>

      <View style={styles.footer}>
        <AppButton
          title="完了として記録"
          onPress={() => router.push(`/items/${item.id}/complete`)}
        />
      </View>
    </View>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.detailRow}>
      <Text style={styles.detailLabel}>{label}</Text>
      <Text style={styles.detailValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl, gap: spacing.md },
  headerCard: { gap: spacing.sm },
  headerRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    gap: spacing.sm,
  },
  name: {
    flex: 1,
    fontSize: fontSize.title,
    fontWeight: "700",
    color: colors.text,
  },
  meta: { fontSize: fontSize.sm, color: colors.textSecondary },
  due: { fontSize: fontSize.lg, color: colors.text, fontWeight: "600" },
  dueNone: { fontSize: fontSize.md, color: colors.textMuted },
  detailRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    paddingVertical: spacing.sm,
    gap: spacing.md,
  },
  detailLabel: { fontSize: fontSize.md, color: colors.textSecondary },
  detailValue: {
    fontSize: fontSize.md,
    color: colors.text,
    flex: 1,
    textAlign: "right",
  },
  image: {
    width: "100%",
    height: 200,
    borderRadius: radius.lg,
    backgroundColor: colors.surface,
  },
  historyHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginTop: spacing.sm,
  },
  historyTitle: {
    fontSize: fontSize.lg,
    fontWeight: "700",
    color: colors.text,
  },
  historyLink: { fontSize: fontSize.md, color: colors.primary },
  historyEmpty: { fontSize: fontSize.md, color: colors.textMuted },
  historyCard: { gap: spacing.xs },
  historyDate: { fontSize: fontSize.md, fontWeight: "600", color: colors.text },
  historyNote: { fontSize: fontSize.sm, color: colors.textSecondary },
  actions: {
    flexDirection: "row",
    gap: spacing.md,
    marginTop: spacing.sm,
    justifyContent: "center",
  },
  footer: {
    padding: spacing.lg,
    backgroundColor: colors.surface,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
});
