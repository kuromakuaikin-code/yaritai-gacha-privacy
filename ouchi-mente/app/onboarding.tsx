import React, { useEffect, useRef, useState } from "react";
import { useRouter } from "expo-router";
import {
  FlatList,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
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
    title: "最後にいつ、次はいつ。\n家の手入れをひとまとめに",
    body: "エアコン、換気設備、浄水器など、数か月後には忘れそうな掃除・交換・点検を記録できます。",
  },
  {
    icon: "📝",
    title: "完了を記録したら、\n次回目安も自動で更新",
    body: "前回日、メーカー、型番、場所、写真を一緒に残せます。次に必要になったとき、探し直す手間を減らします。",
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
  const [finishing, setFinishing] = useState(false);
  const { width } = useWindowDimensions();

  // ---- 開発用診断（__DEV__のみ表示・リリースには出ない）----
  // heartbeat: JSスレッドが生きていれば毎秒カウントが進む
  // step: finish() がどこまで進んだか
  const [heartbeat, setHeartbeat] = useState(0);
  const [step, setStep] = useState("待機中");
  useEffect(() => {
    if (!__DEV__) return;
    const timer = setInterval(() => setHeartbeat((n) => n + 1), 1000);
    return () => clearInterval(timer);
  }, []);

  const isLast = page === PAGES.length - 1;

  const next = () => {
    if (!isLast) {
      // Androidではプログラムによるスクロールで onMomentumScrollEnd が
      // 発火しないため、ページ状態はここで直接更新する
      const target = page + 1;
      listRef.current?.scrollToIndex({ index: target, animated: true });
      setPage(target);
      return;
    }
    finish();
  };

  const finish = async () => {
    setStep("finish開始");
    if (finishing) return;
    setFinishing(true);
    setStep("通知許可を要求中");
    // OSの許可ダイアログの前に、3ページ目までで目的を説明済み。
    // 許可の取得に失敗・応答なし（Expo Go等）でもアプリは必ず開始できる。
    // ダイアログ表示中はユーザー応答を待つが、応答なしで固まる環境に備えて
    // 8秒で見切りをつける（通知は補助機能）
    try {
      await Promise.race([
        requestPermission(),
        new Promise((resolve) => setTimeout(resolve, 8000)),
      ]);
    } catch {
      // 何もしない
    }
    setStep("設定を保存中");
    try {
      await setSetting("onboardingCompleted", "1");
    } catch {
      // 保存に失敗しても先へ進む（ホーム側で再度オンボーディングに戻る）
    }
    setStep("ホームへ移動");
    router.replace("/");
  };

  return (
    <SafeAreaView style={styles.container}>
      <FlatList
        contentInsetAdjustmentBehavior="automatic"
        ref={listRef}
        data={PAGES}
        keyExtractor={(p) => p.title}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        getItemLayout={(_, index) => ({
          length: width,
          offset: width * index,
          index,
        })}
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
        {__DEV__ ? (
          <Text style={styles.debugStrip}>
            {`診断: 鼓動=${heartbeat} / 段階=${step} / ページ=${page}`}
          </Text>
        ) : null}
        <AppButton
          title={isLast ? "通知を設定してはじめる" : "次へ"}
          onPressIn={() => setStep("メイン押下検知")}
          onPress={() => {
            setStep(`onPress発火 isLast=${isLast}`);
            next();
          }}
          loading={finishing}
        />
        {isLast ? null : (
          <AppButton
            title="スキップ"
            variant="ghost"
            onPressIn={() => setStep("スキップ押下検知")}
            onPress={() => {
              setStep("スキップonPress発火");
              void finish();
            }}
            disabled={finishing}
          />
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
  debugStrip: {
    fontSize: fontSize.sm,
    color: colors.textMuted,
    textAlign: "center",
    paddingBottom: spacing.xs,
  },
});
