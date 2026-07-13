import React, { useEffect, useState } from "react";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { Alert } from "react-native";
import { LoadingView } from "@/components/ui";
import { migrateDatabase } from "@/db/database";
import { configureNotificationHandler } from "@/notifications/notifications";
import { colors } from "@/theme";

export default function RootLayout() {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    configureNotificationHandler();
    migrateDatabase()
      .then(() => setReady(true))
      .catch(() => {
        Alert.alert(
          "起動エラー",
          "データの読み込みに失敗しました。アプリを再起動してください。",
        );
      });
  }, []);

  if (!ready) return <LoadingView />;

  return (
    <>
      <StatusBar style="dark" />
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: colors.surface },
          headerTintColor: colors.text,
          headerTitleStyle: { fontWeight: "600" },
          headerShadowVisible: false,
          contentStyle: { backgroundColor: colors.background },
        }}
      >
        <Stack.Screen name="index" options={{ title: "おうちメンテ目安メモ" }} />
        <Stack.Screen
          name="onboarding"
          options={{ headerShown: false, gestureEnabled: false }}
        />
        <Stack.Screen
          name="templates"
          options={{ title: "テンプレートから追加" }}
        />
        <Stack.Screen name="items/new" options={{ title: "項目を追加" }} />
        <Stack.Screen name="items/[id]/index" options={{ title: "詳細" }} />
        <Stack.Screen name="items/[id]/edit" options={{ title: "編集" }} />
        <Stack.Screen
          name="items/[id]/complete"
          options={{ title: "完了として記録", presentation: "modal" }}
        />
        <Stack.Screen name="items/[id]/history" options={{ title: "履歴" }} />
        <Stack.Screen name="settings/index" options={{ title: "設定" }} />
        <Stack.Screen
          name="settings/disclaimer"
          options={{ title: "免責事項" }}
        />
        <Stack.Screen
          name="settings/privacy"
          options={{ title: "プライバシーポリシー" }}
        />
        <Stack.Screen name="settings/terms" options={{ title: "利用規約" }} />
        <Stack.Screen
          name="settings/about"
          options={{ title: "アプリについて" }}
        />
      </Stack>
    </>
  );
}
