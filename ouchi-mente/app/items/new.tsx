import React, { useEffect, useState } from "react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { Alert } from "react-native";
import { ItemForm, type ItemFormResult } from "@/components/ItemForm";
import { LoadingView } from "@/components/ui";
import { insertItem } from "@/db/items";
import { getSetting } from "@/db/settings";
import { findTemplate } from "@/domain/templates";
import { syncItemNotification } from "@/notifications/notifications";
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
      // 無料版の登録上限に達していたら、無制限版の案内画面へ
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

  // 保存に至らなかった場合は throw する（ItemForm が写真の後始末を行うため）
  const handleSubmit = async (result: ItemFormResult) => {
    // 画面表示中に別の画面で登録された場合に備え、保存直前にも上限を確認する
    const check = await checkCanAddItem();
    if (!check.allowed) {
      Alert.alert(
        "登録の上限に達しています",
        `登録できるのは${check.limit}件までです。`,
        [{ text: "OK", onPress: () => router.replace("/paywall") }],
      );
      throw new Error("item limit reached");
    }
    try {
      const item = await insertItem(result);
      const notification = await syncItemNotification(item);
      if (notification.status === "permission-denied") {
        Alert.alert(
          "登録しました",
          "通知が許可されていないため、リマインダーは設定されていません。",
          [{ text: "OK", onPress: () => router.back() }],
        );
        return;
      }
      if (notification.status === "failed") {
        Alert.alert(
          "登録しました",
          "通知は設定できませんでしたが、記録は保存されています。",
          [{ text: "OK", onPress: () => router.back() }],
        );
        return;
      }
      router.back();
    } catch (error) {
      Alert.alert("保存エラー", "項目を保存できませんでした。もう一度お試しください。");
      throw error;
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
