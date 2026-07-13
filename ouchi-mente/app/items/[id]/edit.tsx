import React, { useCallback, useState } from "react";
import { useFocusEffect, useLocalSearchParams, useRouter } from "expo-router";
import { Alert } from "react-native";
import { ItemForm, type ItemFormResult } from "@/components/ItemForm";
import { EmptyState, LoadingView } from "@/components/ui";
import { getItem, updateItem } from "@/db/items";
import type { MaintenanceItem } from "@/domain/types";
import { deleteStoredImageAsync } from "@/media/images";
import { syncItemNotification } from "@/notifications/notifications";

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

  // 保存に至らなかった場合は throw する（ItemForm が写真の後始末を行うため）
  const handleSubmit = async (result: ItemFormResult) => {
    try {
      const updated: MaintenanceItem = {
        ...item,
        ...result,
      };
      // 項目を先に確定する。通知が失敗しても編集内容は失わない。
      const saved = await updateItem({ ...updated, notificationId: undefined });
      const notification = await syncItemNotification(saved, item.notificationId);
      // 保存が成功してから、差し替え・削除された元の写真ファイルを片付ける
      if (item.imageUri && item.imageUri !== result.imageUri) {
        await deleteStoredImageAsync(item.imageUri);
      }
      if (notification.status === "permission-denied") {
        Alert.alert(
          "保存しました",
          "通知が許可されていないため、リマインダーは設定されていません。",
          [{ text: "OK", onPress: () => router.back() }],
        );
      } else if (notification.status === "failed") {
        Alert.alert(
          "保存しました",
          "通知は設定できませんでしたが、変更は保存されています。",
          [{ text: "OK", onPress: () => router.back() }],
        );
      } else {
        router.back();
      }
    } catch (error) {
      Alert.alert("保存エラー", "変更を保存できませんでした。もう一度お試しください。");
      throw error;
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
