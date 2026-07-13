import React, { useCallback, useEffect, useState } from "react";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { StyleSheet, Text, View } from "react-native";
import { AppButton, LoadingView } from "@/components/ui";
import { migrateDatabase } from "@/db/database";
import { configureNotificationHandler } from "@/notifications/notifications";
import { colors, fontSize, spacing } from "@/theme";

export default function RootLayout() {
  const [ready, setReady] = useState(false);
  const [failed, setFailed] = useState(false);

  const boot = useCallback(() => {
    setFailed(false);
    migrateDatabase()
      .then(() => setReady(true))
      .catch(() => setFailed(true));
  }, []);

  useEffect(() => {
    configureNotificationHandler();
    boot();
  }, [boot]);

  if (failed) {
    return (
      <View style={styles.error}>
        <Text style={styles.errorTitle}>データを読み込めませんでした</Text>
        <Text style={styles.errorBody}>
          端末の空き容量を確認して、もう一度お試しください。
        </Text>
        <AppButton title="再試行" onPress={boot} />
      </View>
    );
  }

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
        <Stack.Screen
          name="paywall"
          options={{ title: "登録枠の追加", presentation: "modal" }}
        />
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

const styles = StyleSheet.create({
  error: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.background,
    padding: spacing.xxl,
    gap: spacing.md,
  },
  errorTitle: {
    fontSize: fontSize.xl,
    fontWeight: "700",
    color: colors.text,
    textAlign: "center",
  },
  errorBody: {
    fontSize: fontSize.md,
    color: colors.textSecondary,
    textAlign: "center",
    lineHeight: 22,
  },
});
