import React, { useRef, useState } from "react";
import { useRouter } from "expo-router";
import {
  Dimensions,
  FlatList,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { AppButton } from "@/components/ui";
import { setSetting } from "@/db/settings";
import { NOTIFICATION_NOTE } from "@/domain/labels";
import { requestPermission } from "@/notifications/notifications";
import { colors, fontSize, spacing } from "@/theme";

const PAGES = [
  {
    icon: "🏠",
    title: "掃除・交換・点検の\n「そろそろ」を忘れない",
    body: "エアコンフィルター、洗濯槽、火災警報器の電池など、おうちのお手入れ予定をまとめて記録できます。",
  },
  {
    icon: "📝",
    title: "実施日を記録すると、\n次回の目安日を自動で計算",
    body: "「完了」を押すだけで履歴が残り、設定した周期から次の目安日が決まります。",
  },
  {
    icon: "📖",
    title: "表示される時期は目安です",
    body: "実際のお手入れ・交換・点検時期は、製品の取扱説明書やメーカーの案内を優先してください。このアプリは記録と通知のための補助ツールです。",
  },
] as const;

export default function OnboardingScreen() {
  const router = useRouter();
  const listRef = useRef<FlatList>(null);
  const [page, setPage] = useState(0);
  const width = Dimensions.get("window").width;

  const isLast = page === PAGES.length - 1;

  const next = () => {
    if (!isLast) {
      listRef.current?.scrollToIndex({ index: page + 1, animated: true });
      return;
    }
    finish();
  };

  const finish = async () => {
    // OSの許可ダイアログの前に、3ページ目までで目的を説明済み
    await requestPermission();
    await setSetting("onboardingCompleted", "1");
    router.replace("/");
  };

  return (
    <SafeAreaView style={styles.container}>
      <FlatList
        ref={listRef}
        data={PAGES}
        keyExtractor={(p) => p.title}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={(e) =>
          setPage(Math.round(e.nativeEvent.contentOffset.x / width))
        }
        renderItem={({ item }) => (
          <View style={[styles.page, { width }]}>
            <Text style={styles.icon}>{item.icon}</Text>
            <Text style={styles.title}>{item.title}</Text>
            <Text style={styles.body}>{item.body}</Text>
            {item === PAGES[PAGES.length - 1] ? (
              <Text style={styles.notificationNote}>
                このあと通知の許可をお願いします。{NOTIFICATION_NOTE}
              </Text>
            ) : null}
          </View>
        )}
      />
      <View style={styles.dots}>
        {PAGES.map((p, i) => (
          <View
            key={p.title}
            style={[styles.dot, i === page && styles.dotActive]}
          />
        ))}
      </View>
      <View style={styles.footer}>
        <AppButton title={isLast ? "通知を設定してはじめる" : "次へ"} onPress={next} />
        {isLast ? null : (
          <AppButton title="スキップ" variant="ghost" onPress={finish} />
        )}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  page: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    padding: spacing.xxl,
    gap: spacing.lg,
  },
  icon: { fontSize: 64 },
  title: {
    fontSize: fontSize.title,
    fontWeight: "700",
    color: colors.text,
    textAlign: "center",
    lineHeight: 34,
  },
  body: {
    fontSize: fontSize.md,
    color: colors.textSecondary,
    textAlign: "center",
    lineHeight: 24,
  },
  notificationNote: {
    fontSize: fontSize.sm,
    color: colors.textMuted,
    textAlign: "center",
    lineHeight: 19,
  },
  dots: {
    flexDirection: "row",
    justifyContent: "center",
    gap: spacing.sm,
    paddingVertical: spacing.md,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: colors.border,
  },
  dotActive: { backgroundColor: colors.primary },
  footer: {
    padding: spacing.lg,
    gap: spacing.xs,
  },
});
