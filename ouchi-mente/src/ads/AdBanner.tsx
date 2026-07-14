import React, { useCallback, useState } from "react";
import { useFocusEffect } from "expo-router";
import { ADS_ENABLED } from "./config";
import { isPlusUnlocked } from "@/purchase/entitlement";

/**
 * バナー広告の設置ポイント。
 * - 広告が無効（ADS_ENABLED = false）の間は何も描画しない
 * - 無制限版の購入者には有効化後も表示しない
 * 有効化手順は ./config.ts のコメントを参照。
 */
export function AdBanner() {
  const [hideForPurchaser, setHideForPurchaser] = useState(true);

  useFocusEffect(
    useCallback(() => {
      if (!ADS_ENABLED) return;
      let active = true;
      isPlusUnlocked().then((unlocked) => {
        if (active) setHideForPurchaser(unlocked);
      });
      return () => {
        active = false;
      };
    }, []),
  );

  if (!ADS_ENABLED || hideForPurchaser) return null;

  // 有効化時にここを react-native-google-mobile-ads の BannerAd に差し替える。
  // SDK未導入のままフラグだけ変わった場合に備え、現状は何も描画しない
  return null;
}
