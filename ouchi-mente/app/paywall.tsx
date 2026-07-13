import React, { useCallback, useState } from "react";
import { useFocusEffect, useRouter } from "expo-router";
import { Alert, ScrollView, StyleSheet, Text, View } from "react-native";
import { AppButton, Card, NoteText } from "@/components/ui";
import {
  FREE_ITEM_LIMIT,
  PLUS_ITEM_BONUS,
  PLUS_PRICE_LABEL,
  checkCanAddItem,
  type AddItemCheck,
} from "@/purchase/entitlement";
import { purchasePlus, restorePurchases } from "@/purchase/store";
import { colors, fontSize, radius, spacing } from "@/theme";

export default function PaywallScreen() {
  const router = useRouter();
  const [check, setCheck] = useState<AddItemCheck | null>(null);
  const [busy, setBusy] = useState(false);

  useFocusEffect(
    useCallback(() => {
      let active = true;
      checkCanAddItem().then((result) => {
        if (active) setCheck(result);
      });
      return () => {
        active = false;
      };
    }, []),
  );

  const handlePurchase = async () => {
    setBusy(true);
    try {
      const result = await purchasePlus();
      if (result.status === "success") {
        Alert.alert(
          "ありがとうございます！",
          `登録枠が${PLUS_ITEM_BONUS}件増えました。合計${FREE_ITEM_LIMIT + PLUS_ITEM_BONUS}件まで登録できます。`,
          [{ text: "OK", onPress: () => router.back() }],
        );
      } else if (result.status === "error") {
        Alert.alert("購入できませんでした", result.message);
      }
    } finally {
      setBusy(false);
    }
  };

  const handleRestore = async () => {
    setBusy(true);
    try {
      const result = await restorePurchases();
      if (result.status === "success") {
        Alert.alert("復元しました", "追加の登録枠が有効になりました。", [
          { text: "OK", onPress: () => router.back() },
        ]);
      } else if (result.status === "error") {
        Alert.alert("復元できませんでした", result.message);
      }
    } finally {
      setBusy(false);
    }
  };

  // 購入済みで上限（15件）に達している場合は、購入の案内ではなく上限の説明を出す
  if (check?.plusUnlocked) {
    return (
      <View style={styles.container}>
        <ScrollView contentContainerStyle={styles.content}>
          <Text style={styles.title}>登録の上限に達しています</Text>
          <Text style={styles.lead}>
            追加購入済みのため、最大{FREE_ITEM_LIMIT + PLUS_ITEM_BONUS}
            件まで登録できます（現在 {check.count}/{check.limit} 件）。
          </Text>
          <NoteText text="使わなくなった項目を削除すると、新しい項目を登録できます。項目を削除しても、購入した登録枠はなくなりません。" />
        </ScrollView>
        <View style={styles.footer}>
          <AppButton title="閉じる" onPress={() => router.back()} />
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.title}>登録枠を追加しませんか？</Text>
        <Text style={styles.lead}>
          無料版では{FREE_ITEM_LIMIT}件まで登録できます。
          {check ? `現在 ${check.count}/${check.limit} 件を使用中です。` : ""}
        </Text>

        <Card style={styles.offer}>
          <Text style={styles.offerBadge}>買い切り・月額なし</Text>
          <Text style={styles.offerTitle}>登録枠 +{PLUS_ITEM_BONUS}件</Text>
          <Text style={styles.offerPrice}>{PLUS_PRICE_LABEL}</Text>
          <Text style={styles.offerDetail}>
            合計{FREE_ITEM_LIMIT + PLUS_ITEM_BONUS}
            件まで登録できるようになります。一度の購入でずっと使えます。
          </Text>
        </Card>

        <View style={styles.featureList}>
          <Text style={styles.feature}>✓ エアコン・換気扇など複数台の管理に</Text>
          <Text style={styles.feature}>✓ 履歴・通知・テンプレートは無料版と同じ</Text>
          <Text style={styles.feature}>✓ 機種変更時はストアの「購入の復元」で引き継ぎ</Text>
        </View>

        <NoteText text="広告は表示されません。アカウント登録も不要で、データはこれまでどおり端末内にのみ保存されます。" />
      </ScrollView>

      <View style={styles.footer}>
        <AppButton
          title={`${PLUS_PRICE_LABEL}で登録枠を追加`}
          onPress={handlePurchase}
          loading={busy}
        />
        <AppButton
          title="購入の復元"
          variant="ghost"
          onPress={handleRestore}
          disabled={busy}
        />
        <AppButton
          title="今はやめておく"
          variant="ghost"
          onPress={() => router.back()}
          disabled={busy}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl, gap: spacing.lg },
  title: {
    fontSize: fontSize.title,
    fontWeight: "700",
    color: colors.text,
    lineHeight: 32,
  },
  lead: {
    fontSize: fontSize.md,
    color: colors.textSecondary,
    lineHeight: 22,
  },
  offer: {
    alignItems: "center",
    gap: spacing.sm,
    borderColor: colors.primary,
    borderWidth: 1.5,
  },
  offerBadge: {
    fontSize: fontSize.sm,
    color: colors.primary,
    fontWeight: "700",
    backgroundColor: colors.primarySoft,
    borderRadius: radius.pill,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
  },
  offerTitle: {
    fontSize: fontSize.xl,
    fontWeight: "700",
    color: colors.text,
  },
  offerPrice: {
    fontSize: 34,
    fontWeight: "800",
    color: colors.primary,
  },
  offerDetail: {
    fontSize: fontSize.sm,
    color: colors.textSecondary,
    textAlign: "center",
    lineHeight: 20,
  },
  featureList: { gap: spacing.sm },
  feature: {
    fontSize: fontSize.md,
    color: colors.text,
    lineHeight: 22,
  },
  footer: {
    padding: spacing.lg,
    gap: spacing.xs,
    backgroundColor: colors.surface,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
});
