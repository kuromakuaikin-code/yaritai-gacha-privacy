import React, { useCallback, useState } from "react";
import { useFocusEffect, useRouter } from "expo-router";
import { Alert, ScrollView, StyleSheet, Text, View } from "react-native";
import { AppButton, Card, LoadingView, NoteText } from "@/components/ui";
import { STORE_NAME } from "@/domain/labels";
import {
  FREE_ITEM_LIMIT,
  checkCanAddItem,
  type AddItemCheck,
} from "@/purchase/entitlement";
import { usePurchase } from "@/purchase/PurchaseProvider";
import { colors, fontSize, radius, spacing } from "@/theme";

export default function PaywallScreen() {
  const router = useRouter();
  const [check, setCheck] = useState<AddItemCheck | null>(null);
  const [busy, setBusy] = useState(false);
  const {
    product,
    loadingProduct,
    productError,
    purchaseUnlimited,
    restoreUnlimited,
    retryStoreConnection,
  } = usePurchase();

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

  // 誤タップでストアの決済フローに入らないよう、先に一度確認する
  const confirmPurchase = () => {
    Alert.alert(
      "無制限版を購入しますか？",
      `${product?.displayPrice ?? "¥300"}の買い切りです。月額料金はありません。このあと${STORE_NAME}の購入手続きに進みます。`,
      [
        { text: "キャンセル", style: "cancel" },
        { text: "購入する", onPress: () => void handlePurchase() },
      ],
    );
  };

  const handlePurchase = async () => {
    setBusy(true);
    try {
      const result = await purchaseUnlimited();
      if (result.status === "success") {
        Alert.alert(
          "ありがとうございます！",
          "登録数の上限がなくなりました。これから追加する家電や設備も、ずっと記録できます。",
          [{ text: "OK", onPress: () => router.back() }],
        );
      } else if (result.status === "pending") {
        Alert.alert(
          "購入手続き中です",
          "支払いの承認が完了すると、無制限版が自動で有効になります。",
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
      const result = await restoreUnlimited();
      if (result.status === "success") {
        Alert.alert("復元しました", "無制限版が有効になりました。", [
          { text: "OK", onPress: () => router.back() },
        ]);
      } else if (result.status === "error") {
        Alert.alert("復元できませんでした", result.message);
      }
    } finally {
      setBusy(false);
    }
  };

  // 判定が終わるまでは何も出さない（購入済みユーザーに購入ボタンを見せないため）
  if (!check) return <LoadingView />;

  // 購入済みの場合は、購入の案内ではなく無制限版の説明を出す
  if (check.plusUnlocked) {
    return (
      <View style={styles.container}>
        <ScrollView
          contentInsetAdjustmentBehavior="automatic"
          contentContainerStyle={styles.content}
        >
          <Text style={styles.title}>無制限版を利用中です</Text>
          <Text style={styles.lead}>
            家電・設備・交換品を、件数を気にせず登録できます。現在は
            {check.count}件を記録しています。
          </Text>
        </ScrollView>
        <View style={styles.footer}>
          <AppButton title="閉じる" onPress={() => router.back()} />
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        contentContainerStyle={styles.content}
      >
        <Text style={styles.title}>家の記録を、3件より先へ</Text>
        <Text style={styles.lead}>
          無料版では{FREE_ITEM_LIMIT}件まで登録できます。現在 {check.count}/
          {check.limit} 件を使用中です。
        </Text>

        <Card style={styles.offer}>
          <Text style={styles.offerBadge}>買い切り・月額なし</Text>
          <Text style={styles.offerTitle}>登録数を無制限に</Text>
          <Text style={styles.offerPrice}>
            {product?.displayPrice ?? "ストアに接続中"}
          </Text>
          <Text style={styles.offerDetail}>
            一度購入すれば、今後追加する家電・設備・交換品も件数を気にせず記録できます。
          </Text>
        </Card>

        <View style={styles.featureList}>
          <Text style={styles.feature}>✓ エアコンや換気扇が複数台あっても安心</Text>
          <Text style={styles.feature}>✓ 月額料金なし・広告なし</Text>
          <Text style={styles.feature}>✓ 機種変更時はストアの「購入の復元」で引き継ぎ</Text>
        </View>

        {productError ? (
          <View style={styles.storeError}>
            <Text style={styles.storeErrorText}>{productError}</Text>
            <AppButton
              title="ストアに再接続"
              variant="secondary"
              onPress={() => void retryStoreConnection()}
              disabled={loadingProduct || busy}
            />
          </View>
        ) : null}

        <NoteText
          text={`アカウント登録は不要です。記録はアプリのローカル領域に保存され、開発者のサーバー、広告、解析サービスへ送信しません。購入は${STORE_NAME}で処理され、異なるOSの端末へは引き継げません。`}
        />
      </ScrollView>

      <View style={styles.footer}>
        <AppButton
          title={product ? `${product.displayPrice}で無制限にする` : "商品情報を読み込み中"}
          onPress={confirmPurchase}
          loading={busy}
          disabled={!product || loadingProduct}
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
  storeError: { gap: spacing.sm },
  storeErrorText: {
    fontSize: fontSize.sm,
    color: colors.danger,
    lineHeight: 19,
  },
  footer: {
    padding: spacing.lg,
    gap: spacing.xs,
    backgroundColor: colors.surface,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
});
