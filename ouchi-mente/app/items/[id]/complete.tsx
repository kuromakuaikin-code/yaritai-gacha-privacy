import React, { useCallback, useEffect, useState } from "react";
import { useFocusEffect, useLocalSearchParams, useRouter } from "expo-router";
import {
  Alert,
  Image,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { DateField, TextField } from "@/components/form";
import { AppButton, Card, EmptyState, LoadingView, NoteText } from "@/components/ui";
import { insertHistory } from "@/db/history";
import { getItem, updateItem } from "@/db/items";
import { GUIDANCE_NOTE, TASK_TYPE_LABELS } from "@/domain/labels";
import { calculateNextDueDate, todayString } from "@/domain/schedule";
import type { MaintenanceItem } from "@/domain/types";
import {
  deleteStoredImageAsync,
  pickAndStoreImageAsync,
} from "@/media/images";
import { rescheduleItemNotification } from "@/notifications/notifications";
import { colors, fontSize, radius, spacing } from "@/theme";

export default function CompleteScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const [item, setItem] = useState<MaintenanceItem | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const [completedAt, setCompletedAt] = useState(todayString());
  const [nextDueDate, setNextDueDate] = useState<string | undefined>();
  const [nextDueTouched, setNextDueTouched] = useState(false);
  const [note, setNote] = useState("");
  const [imageUri, setImageUri] = useState<string | undefined>();

  useFocusEffect(
    useCallback(() => {
      let active = true;
      getItem(id).then((loaded) => {
        if (!active) return;
        setItem(loaded);
        setLoading(false);
      });
      return () => {
        active = false;
      };
    }, [id]),
  );

  // 実施日を変えたら次回目安を計算し直す（手動変更後は上書きしない）
  useEffect(() => {
    if (!item || nextDueTouched) return;
    setNextDueDate(calculateNextDueDate(item, completedAt));
  }, [item, completedAt, nextDueTouched]);

  if (loading) return <LoadingView />;
  if (!item) {
    return (
      <EmptyState
        title="項目が見つかりません"
        description="すでに削除されている可能性があります。"
      />
    );
  }

  const save = async () => {
    setSaving(true);
    try {
      await insertHistory({
        maintenanceItemId: item.id,
        completedAt,
        note: note.trim() || undefined,
        imageUri,
        calculatedNextDueDate: nextDueDate,
      });
      const updated: MaintenanceItem = { ...item, nextDueDate };
      // 完了記録に合わせて通知を再設定する
      const notificationId = await rescheduleItemNotification(updated);
      await updateItem({ ...updated, notificationId });
      router.back();
    } catch {
      Alert.alert("保存エラー", "記録を保存できませんでした。もう一度お試しください。");
    } finally {
      setSaving(false);
    }
  };

  const pickImage = async () => {
    const uri = await pickAndStoreImageAsync();
    if (!uri) return;
    await deleteStoredImageAsync(imageUri);
    setImageUri(uri);
  };

  return (
    <KeyboardAvoidingView
      style={styles.flex}
      behavior={Platform.OS === "ios" ? "padding" : undefined}
    >
      <ScrollView
        style={styles.flex}
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
      >
        <Text style={styles.question}>
          {item.location ? `${item.location}の` : ""}
          {item.name}の{TASK_TYPE_LABELS[item.taskType]}を記録しますか？
        </Text>

        <Card style={styles.card}>
          <DateField
            label="実施日"
            required
            value={completedAt}
            onChange={(v) => v && setCompletedAt(v)}
          />
          <DateField
            label="次回目安"
            value={nextDueDate}
            onChange={(v) => {
              setNextDueTouched(true);
              setNextDueDate(v);
            }}
            placeholder="次回予定なし"
            clearable
          />
          <TextField
            label="メモ（任意）"
            value={note}
            onChangeText={setNote}
            placeholder="気づいたことがあれば"
            multiline
          />
          {imageUri ? (
            <View style={styles.imageBlock}>
              <Image source={{ uri: imageUri }} style={styles.image} />
              <AppButton
                title="写真を削除"
                variant="ghost"
                onPress={async () => {
                  await deleteStoredImageAsync(imageUri);
                  setImageUri(undefined);
                }}
              />
            </View>
          ) : (
            <AppButton
              title="写真を追加（任意）"
              variant="secondary"
              onPress={pickImage}
            />
          )}
        </Card>

        <NoteText text={GUIDANCE_NOTE} />
      </ScrollView>

      <View style={styles.footer}>
        <AppButton title="記録する" onPress={save} loading={saving} />
        <AppButton
          title="キャンセル"
          variant="ghost"
          onPress={() => router.back()}
        />
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl, gap: spacing.lg },
  question: {
    fontSize: fontSize.xl,
    fontWeight: "700",
    color: colors.text,
    lineHeight: 28,
  },
  card: { gap: spacing.xs },
  imageBlock: { gap: spacing.sm },
  image: {
    width: "100%",
    height: 160,
    borderRadius: radius.md,
    backgroundColor: colors.background,
  },
  footer: {
    padding: spacing.lg,
    gap: spacing.xs,
    backgroundColor: colors.surface,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
});
