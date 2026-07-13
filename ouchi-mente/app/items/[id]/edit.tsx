import React, { useCallback, useState } from "react";
import { useFocusEffect, useLocalSearchParams, useRouter } from "expo-router";
import { Alert } from "react-native";
import { ItemForm, type ItemFormResult } from "@/components/ItemForm";
import { EmptyState, LoadingView } from "@/components/ui";
import { getItem, updateItem } from "@/db/items";
import type { MaintenanceItem } from "@/domain/types";
import { deleteStoredImageAsync } from "@/media/images";
import {
  cancelNotification,
  rescheduleItemNotification,
} from "@/notifications/notifications";

export default function EditItemScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const [item, setItem] = useState<MaintenanceItem | null>(null);
  const [loading, setLoading] = useState(true);

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

  if (loading) return <LoadingView />;
  if (!item) {
    return (
      <EmptyState
        title="項目が見つかりません"
        description="すでに削除されている可能性があります。"
      />
    );
  }

  const handleSubmit = async (result: ItemFormResult) => {
    try {
      const updated: MaintenanceItem = {
        ...item,
        ...result,
      };
      // 編集時は古い通知を破棄して登録し直す。
      // DB更新に失敗したら、登録したばかりの通知を破棄する（通知の迷子防止）
      const notificationId = await rescheduleItemNotification(updated);
      try {
        await updateItem({ ...updated, notificationId });
      } catch (error) {
        await cancelNotification(notificationId);
        throw error;
      }
      // 保存が成功してから、差し替え・削除された元の写真ファイルを片付ける
      if (item.imageUri && item.imageUri !== result.imageUri) {
        await deleteStoredImageAsync(item.imageUri);
      }
      router.back();
    } catch {
      Alert.alert("保存エラー", "変更を保存できませんでした。もう一度お試しください。");
    }
  };

  return (
    <ItemForm
      mode="edit"
      submitLabel="保存する"
      initial={{
        name: item.name,
        category: item.category,
        taskType: item.taskType,
        location: item.location ?? "",
        scheduleType: item.scheduleType,
        intervalValue: item.intervalValue ? String(item.intervalValue) : "",
        intervalUnit: item.intervalUnit ?? "month",
        fixedDate: item.scheduleType === "fixedDate" ? item.nextDueDate : undefined,
        nextDueDateOverride: item.nextDueDate,
        notificationEnabled: item.notificationEnabled,
        notificationTimingDays: item.notificationTimingDays ?? 0,
        manufacturer: item.manufacturer ?? "",
        modelNumber: item.modelNumber ?? "",
        note: item.note ?? "",
        imageUri: item.imageUri,
      }}
      onSubmit={handleSubmit}
    />
  );
}
