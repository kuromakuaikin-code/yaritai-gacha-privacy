import React, { useEffect, useState } from "react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { Alert } from "react-native";
import { ItemForm, type ItemFormResult } from "@/components/ItemForm";
import { LoadingView } from "@/components/ui";
import { insertItem, updateItem } from "@/db/items";
import { getSetting } from "@/db/settings";
import { findTemplate } from "@/domain/templates";
import { rescheduleItemNotification } from "@/notifications/notifications";
import { checkCanAddItem } from "@/purchase/entitlement";

export default function NewItemScreen() {
  const router = useRouter();
  const { template: templateKey } = useLocalSearchParams<{ template?: string }>();
  const template = templateKey ? findTemplate(templateKey) : undefined;

  const [defaults, setDefaults] = useState<{
    notificationEnabled: boolean;
    notificationTimingDays: number;
  } | null>(null);

  useEffect(() => {
    let active = true;
    (async () => {
      // 登録上限（無料5件・追加購入で15件）に達していたら案内画面へ
      const check = await checkCanAddItem();
      if (!active) return;
      if (!check.allowed) {
        router.replace("/paywall");
        return;
      }
      const enabled = await getSetting("defaultNotificationEnabled");
      const timing = await getSetting("defaultNotificationTimingDays");
      if (!active) return;
      setDefaults({
        notificationEnabled: enabled === null ? true : enabled === "1",
        notificationTimingDays: timing === null ? 0 : Number(timing),
      });
    })();
    return () => {
      active = false;
    };
  }, [router]);

  if (!defaults) return <LoadingView />;

  const handleSubmit = async (result: ItemFormResult) => {
    try {
      const item = await insertItem(result);
      const notificationId = await rescheduleItemNotification(item);
      if (notificationId) {
        await updateItem({ ...item, notificationId });
      }
      router.back();
    } catch {
      Alert.alert("保存エラー", "項目を保存できませんでした。もう一度お試しください。");
    }
  };

  return (
    <ItemForm
      mode="create"
      submitLabel="登録する"
      caution={template?.caution}
      initial={{
        notificationEnabled: defaults.notificationEnabled,
        notificationTimingDays: defaults.notificationTimingDays,
        ...(template
          ? {
              name: template.name,
              category: template.category,
              taskType: template.taskType,
              scheduleType: template.interval ? "interval" : "none",
              intervalValue: template.interval
                ? String(template.interval.value)
                : "",
              intervalUnit: template.interval?.unit ?? "month",
            }
          : {}),
      }}
      onSubmit={handleSubmit}
    />
  );
}
