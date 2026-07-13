import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  fetchProducts,
  finishTransaction,
  getAvailablePurchases,
  restorePurchases as restoreStorePurchases,
  useIAP,
  type Product,
  type Purchase,
} from "expo-iap";
import {
  PLUS_PRODUCT_ID,
  PLUS_PRODUCT_IDS,
  saveStorePurchaseEntitlement,
} from "./entitlement";

type PurchaseResult =
  | { status: "success" }
  | { status: "cancelled" }
  | { status: "pending" }
  | { status: "error"; message: string };

type PurchaseContextValue = {
  connected: boolean;
  loadingProduct: boolean;
  product?: Product;
  productError?: string;
  purchaseUnlimited: () => Promise<PurchaseResult>;
  restoreUnlimited: () => Promise<PurchaseResult>;
  retryStoreConnection: () => Promise<void>;
};

const PurchaseContext = createContext<PurchaseContextValue | undefined>(
  undefined,
);

function isOurPurchase(purchase: Purchase): boolean {
  return (
    purchase.productId === PLUS_PRODUCT_IDS.ios ||
    purchase.productId === PLUS_PRODUCT_IDS.android
  );
}

function userMessage(error: unknown): string {
  const code =
    error && typeof error === "object" && "code" in error
      ? String((error as { code?: unknown }).code)
      : "";
  if (code === "user-cancelled") return "購入はキャンセルされました。";
  const text = error instanceof Error ? error.message : String(error);
  if (/cancel/i.test(text)) return "購入はキャンセルされました。";
  if (/not.?available|unavailable|not.?found/i.test(text)) {
    return "ストアに商品が見つかりません。公開設定を確認してから、もう一度お試しください。";
  }
  return "ストアに接続できませんでした。通信環境を確認して、もう一度お試しください。";
}

export function PurchaseProvider({ children }: { children: React.ReactNode }) {
  const processedPurchaseIds = useRef(new Set<string>());
  const [product, setProduct] = useState<Product>();
  const [loadingProduct, setLoadingProduct] = useState(true);
  const [productError, setProductError] = useState<string>();

  const applyPurchase = useCallback(async (purchase: Purchase): Promise<boolean> => {
    if (!isOurPurchase(purchase) || purchase.purchaseState !== "purchased") {
      return false;
    }

    // 同一トランザクションはセッション内で一度だけ処理する。
    // iOSでは購入イベントと requestPurchase の戻り値の両方から同じ購入が
    // 届くため、成功後もキーを保持して finish/acknowledge の二重実行を防ぐ。
    const purchaseKey = purchase.transactionId ?? purchase.id;
    if (processedPurchaseIds.current.has(purchaseKey)) return true;
    processedPurchaseIds.current.add(purchaseKey);

    try {
      // 権利を先に保存する。finish/acknowledge に失敗しても購入者の権利は
      // 失われず、未完了のトランザクションは次回起動時の syncStore が再処理する。
      await saveStorePurchaseEntitlement({
        productId: purchase.productId,
        transactionId: purchase.transactionId,
        store: purchase.store,
      });
    } catch (error) {
      // 権利を保存できなかった場合だけ、次の配信で再処理できるようキーを外す
      processedPurchaseIds.current.delete(purchaseKey);
      throw error;
    }

    // Androidで acknowledge 済みの購入を再度 acknowledge しない
    const alreadyAcknowledged =
      "isAcknowledgedAndroid" in purchase &&
      purchase.isAcknowledgedAndroid === true;
    if (!alreadyAcknowledged) {
      try {
        // Google Playでは acknowledge、App Storeでは transaction finish になる
        await finishTransaction({ purchase, isConsumable: false });
      } catch {
        // 権利は保存済みのため、購入としては成功扱いにする。
        // acknowledge が本当に未完了なら次回起動時の syncStore が再試行する
        processedPurchaseIds.current.delete(purchaseKey);
      }
    }
    return true;
  }, []);

  const {
    connected,
    requestPurchase,
    reconnect,
  } = useIAP({
    onPurchaseSuccess: (purchase) => {
      void applyPurchase(purchase);
    },
  });

  const syncStore = useCallback(async () => {
    if (!connected) return;
    setLoadingProduct(true);
    setProductError(undefined);
    try {
      const products = await fetchProducts({
        skus: [PLUS_PRODUCT_ID],
        type: "in-app",
      });
      const found = products?.find((item) => item.id === PLUS_PRODUCT_ID) as
        | Product
        | undefined;
      if (!found) {
        setProduct(undefined);
        setProductError("商品情報を取得できませんでした。ストアの公開設定を確認してください。");
      } else {
        setProduct(found);
      }

      // 購入済みの人を、通信エラーや一時的な空配列だけで無料へ戻さない。
      const purchases = await getAvailablePurchases({
        onlyIncludeActiveItemsIOS: true,
      });
      const owned = purchases.find(
        (purchase) => isOurPurchase(purchase) && purchase.purchaseState === "purchased",
      );
      if (owned) await applyPurchase(owned);
    } catch {
      setProductError("ストアに接続できませんでした。時間をおいて再読み込みしてください。");
    } finally {
      setLoadingProduct(false);
    }
  }, [applyPurchase, connected]);

  useEffect(() => {
    void syncStore();
  }, [syncStore]);

  const purchaseUnlimited = useCallback(async (): Promise<PurchaseResult> => {
    if (!connected) {
      return { status: "error", message: "ストアに接続中です。少し待ってからお試しください。" };
    }
    if (!product) {
      return { status: "error", message: productError ?? "商品情報を取得できませんでした。" };
    }

    try {
      const result = await requestPurchase({
        request: {
          apple: { sku: PLUS_PRODUCT_IDS.ios },
          google: { skus: [PLUS_PRODUCT_IDS.android] },
        },
        type: "in-app",
      });
      const purchases = Array.isArray(result) ? result : result ? [result] : [];
      if (purchases.some((purchase) => purchase.purchaseState === "pending")) {
        return { status: "pending" };
      }
      if (await Promise.all(purchases.map(applyPurchase)).then((values) => values.some(Boolean))) {
        return { status: "success" };
      }
      return { status: "cancelled" };
    } catch (error) {
      const message = userMessage(error);
      return /キャンセル/.test(message)
        ? { status: "cancelled" }
        : { status: "error", message };
    }
  }, [applyPurchase, connected, product, productError, requestPurchase]);

  const restoreUnlimited = useCallback(async (): Promise<PurchaseResult> => {
    if (!connected) {
      return { status: "error", message: "ストアに接続中です。少し待ってからお試しください。" };
    }
    try {
      await restoreStorePurchases();
      const purchases = await getAvailablePurchases({
        onlyIncludeActiveItemsIOS: true,
      });
      const owned = purchases.find(
        (purchase) => isOurPurchase(purchase) && purchase.purchaseState === "purchased",
      );
      if (!owned) {
        return {
          status: "error",
          message: "現在のストアアカウントでは購入履歴が見つかりませんでした。",
        };
      }
      await applyPurchase(owned);
      return { status: "success" };
    } catch (error) {
      return { status: "error", message: userMessage(error) };
    }
  }, [applyPurchase, connected]);

  const retryStoreConnection = useCallback(async () => {
    if (!connected) await reconnect();
    await syncStore();
  }, [connected, reconnect, syncStore]);

  const value = useMemo<PurchaseContextValue>(
    () => ({
      connected,
      loadingProduct,
      product,
      productError,
      purchaseUnlimited,
      restoreUnlimited,
      retryStoreConnection,
    }),
    [
      connected,
      loadingProduct,
      product,
      productError,
      purchaseUnlimited,
      restoreUnlimited,
      retryStoreConnection,
    ],
  );

  return <PurchaseContext.Provider value={value}>{children}</PurchaseContext.Provider>;
}

export function usePurchase(): PurchaseContextValue {
  const context = useContext(PurchaseContext);
  if (!context) throw new Error("PurchaseProvider の外で usePurchase は使えません。");
  return context;
}
