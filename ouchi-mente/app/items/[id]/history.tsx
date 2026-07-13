import React, { useCallback, useState } from "react";
import { useFocusEffect, useLocalSearchParams } from "expo-router";
import {
  Alert,
  FlatList,
  Image,
  Modal,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { DateField, TextField } from "@/components/form";
import { AppButton, Card, EmptyState, LoadingView } from "@/components/ui";
import {
  deleteHistory,
  listHistoryForItem,
  updateHistory,
} from "@/db/history";
import { formatDateJa } from "@/domain/schedule";
import type { MaintenanceHistory } from "@/domain/types";
import { deleteStoredImageAsync } from "@/media/images";
import { colors, fontSize, radius, spacing } from "@/theme";

export default function HistoryScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const [history, setHistory] = useState<MaintenanceHistory[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<MaintenanceHistory | null>(null);
  const [editDate, setEditDate] = useState("");
  const [editNote, setEditNote] = useState("");
  const [saving, setSaving] = useState(false);

  const reload = useCallback(async () => {
    setHistory(await listHistoryForItem(id));
    setLoading(false);
  }, [id]);

  useFocusEffect(
    useCallback(() => {
      reload();
    }, [reload]),
  );

  if (loading) return <LoadingView />;

  const openEdit = (entry: MaintenanceHistory) => {
    setEditing(entry);
    setEditDate(entry.completedAt);
    setEditNote(entry.note ?? "");
  };

  const saveEdit = async () => {
    if (!editing) return;
    setSaving(true);
    try {
      await updateHistory({
        ...editing,
        completedAt: editDate,
        note: editNote.trim() || undefined,
      });
      setEditing(null);
      await reload();
    } catch {
      Alert.alert("保存エラー", "履歴を保存できませんでした。");
    } finally {
      setSaving(false);
    }
  };

  const confirmDelete = (entry: MaintenanceHistory) => {
    Alert.alert(
      "履歴を削除しますか？",
      `${formatDateJa(entry.completedAt)}の記録を削除します。この操作は取り消せません。`,
      [
        { text: "キャンセル", style: "cancel" },
        {
          text: "削除する",
          style: "destructive",
          onPress: async () => {
            try {
              await deleteStoredImageAsync(entry.imageUri);
              await deleteHistory(entry.id);
              await reload();
            } catch {
              Alert.alert("削除エラー", "履歴を削除できませんでした。");
            }
          },
        },
      ],
    );
  };

  return (
    <View style={styles.container}>
      {history.length === 0 ? (
        <EmptyState
          title="まだ実施記録がありません"
          description="「完了として記録」を押すと、ここに履歴が残ります。"
        />
      ) : (
        <FlatList
          data={history}
          keyExtractor={(entry) => entry.id}
          contentContainerStyle={styles.list}
          renderItem={({ item: entry }) => (
            <Card style={styles.entry}>
              <Text style={styles.entryDate}>
                {formatDateJa(entry.completedAt)}
              </Text>
              {entry.note ? (
                <Text style={styles.entryNote}>{entry.note}</Text>
              ) : null}
              {entry.imageUri ? (
                <Image source={{ uri: entry.imageUri }} style={styles.image} />
              ) : null}
              {entry.calculatedNextDueDate ? (
                <Text style={styles.entryMeta}>
                  記録時の次回目安：{formatDateJa(entry.calculatedNextDueDate)}
                </Text>
              ) : null}
              <View style={styles.entryActions}>
                <AppButton
                  title="編集"
                  variant="ghost"
                  onPress={() => openEdit(entry)}
                />
                <AppButton
                  title="削除"
                  variant="ghost"
                  onPress={() => confirmDelete(entry)}
                />
              </View>
            </Card>
          )}
        />
      )}

      <Modal
        visible={editing !== null}
        transparent
        animationType="fade"
        onRequestClose={() => setEditing(null)}
      >
        <View style={styles.modalBackdrop}>
          <View style={styles.modalSheet}>
            <Text style={styles.modalTitle}>履歴を編集</Text>
            <DateField
              label="実施日"
              required
              value={editDate}
              onChange={(v) => v && setEditDate(v)}
            />
            <TextField
              label="メモ"
              value={editNote}
              onChangeText={setEditNote}
              multiline
            />
            <AppButton title="保存する" onPress={saveEdit} loading={saving} />
            <AppButton
              title="キャンセル"
              variant="ghost"
              onPress={() => setEditing(null)}
            />
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  list: { padding: spacing.lg, paddingBottom: spacing.xxl, gap: spacing.md },
  entry: { gap: spacing.sm },
  entryDate: { fontSize: fontSize.lg, fontWeight: "600", color: colors.text },
  entryNote: { fontSize: fontSize.md, color: colors.textSecondary },
  entryMeta: { fontSize: fontSize.sm, color: colors.textMuted },
  image: {
    width: "100%",
    height: 160,
    borderRadius: radius.md,
    backgroundColor: colors.background,
  },
  entryActions: {
    flexDirection: "row",
    justifyContent: "flex-end",
  },
  modalBackdrop: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.4)",
    justifyContent: "center",
    padding: spacing.xl,
  },
  modalSheet: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    padding: spacing.lg,
    gap: spacing.xs,
  },
  modalTitle: {
    fontSize: fontSize.lg,
    fontWeight: "700",
    color: colors.text,
    marginBottom: spacing.sm,
  },
});
