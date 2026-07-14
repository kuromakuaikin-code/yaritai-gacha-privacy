import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import Constants from "expo-constants";
import type { Product, Purchase } from "expo-iap";
import {
  PLUS_PRODUCT_ID,
  PLUS_PRODUCT_IDS,
  saveStorePurchaseEntitlement,
} from "./entitlement";

type IapModule = typeof import("expo-iap");

/**
 * expo-iap はネイティブモジュールのため、Expo Go では import した時点で
 * 例外になる。実行環境を確認してから読み込み、使えない環境（Expo Go）では
 * スタブの Provider に切り替える。型だけの import は実行時に消えるので安全。
 */
const isExpoGo = Constants.executionEnvironment === "storeClient";
const Iap: IapModule | null = (() => {
  if (isExpoGo) return null;
  try {
    return require("expo-iap") as IapModule;
  } catch {
    return null;
  }
})();

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

function NativePurchaseProvider({ children }: { children: React.ReactNode }) {
  const iap = Iap!;
  const completedPurchaseIds = useRef(new Set<string>());
  const inFlightPurchaseTasks = useRef(new Map<string, Promise<boolean>>());
  const [product, setProduct] = useState<Product>();
  const [loadingProduct, setLoadingProduct] = useState(true);
  const [productError, setProductError] = useState<string>();

  const applyPurchase = useCallback((purchase: Purchase): Promise<boolean> => {
    if (!isOurPurchase(purchase) || purchase.purchaseState !== "purchased") {
      return Promise.resolve(false);
    }

    // 同一トランザクションはセッション内で一度だけ処理する。
    // iOSでは購入イベントと requestPurchase の戻り値の両方から同じ購入が
    // 届く。処理中なら同じPromiseを返して保存完了を待ち、完了後はキーを
    // 保持して finish/acknowledge の二重実行を防ぐ。
    const purchaseKey = purchase.transactionId ?? purchase.id;
    if (completedPurchaseIds.current.has(purchaseKey)) {
      return Promise.resolve(true);
    }
    const existingTask = inFlightPurchaseTasks.current.get(purchaseKey);
    if (existingTask) return existingTask;

    const task = (async (): Promise<boolean> => {
      // 権利を先に保存する。finish/acknowledge に失敗しても購入者の権利は
      // 失われず、未完了のトランザクションは次回起動時の syncStore が再処理する。
      await saveStorePurchaseEntitlement({
        productId: purchase.productId,
        transactionId: purchase.transactionId,
        store: purchase.store,
      });

      // Androidで acknowledge 済みの購入を再度 acknowledge しない
      const alreadyAcknowledged =
        "isAcknowledgedAndroid" in purchase &&
        purchase.isAcknowledgedAndroid === true;
      if (!alreadyAcknowledged) {
        try {
          // Google Playでは acknowledge、App Storeでは transaction finish になる
          await iap.finishTransaction({ purchase, isConsumable: false });
        } catch {
          // 権利は保存済みのため、購入としては成功扱いにする。
          // 完了キーは残さず、次回配信時に finish/acknowledge だけ再試行する。
          return true;
        }
      }

      completedPurchaseIds.current.add(purchaseKey);
      return true;
    })();

    inFlightPurchaseTasks.current.set(purchaseKey, task);
    void task
      .finally(() => {
        if (inFlightPurchaseTasks.current.get(purchaseKey) === task) {
          inFlightPurchaseTasks.current.delete(purchaseKey);
        }
      })
      .catch(() => {
        // 呼び出し元が元のtaskを処理する。finallyが作るPromiseの未処理化だけ防ぐ。
      });
    return task;
  }, [iap]);

  const {
    connected,
    requestPurchase,
    reconnect,
  } = iap.useIAP({
    onPurchaseSuccess: (purchase) => {
      void applyPurchase(purchase).catch(() => {
        // 権利保存に失敗した購入は、ストアからの次回配信時に再処理する。
      });
    },
  });

  const syncStore = useCallback(async () => {
    if (!connected) return;
    setLoadingProduct(true);
    setProductError(undefined);
    try {
      const products = await iap.fetchProducts({
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
      const purchases = await iap.getAvailablePurchases({
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
  }, [applyPurchase, connected, iap]);

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
      await iap.restorePurchases();
      const purchases = await iap.getAvailablePurchases({
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
  }, [applyPurchase, connected, iap]);

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

const STUB_NOTE =
  "この実行環境（Expo Go）ではストア決済を利用できません。実際の購入・復元は Development Build の実機で確認してください。";

/**
 * Expo Go 用のスタブ。開発中（__DEV__）は疑似購入で無制限を解放でき、
 * ペイウォール→解放→無制限登録の一連のフローを Expo Go でも確認できる。
 * リリースビルドでネイティブモジュールが欠けていた場合はエラーを返すだけで、
 * 無償解放は起きない。
 */
function StubPurchaseProvider({ children }: { children: React.ReactNode }) {
  const value = useMemo<PurchaseContextValue>(() => {
    const stubProduct = __DEV__
      ? ({
          id: PLUS_PRODUCT_ID,
          displayPrice: "¥300",
        } as unknown as Product)
      : undefined;
    const purchase = async (): Promise<PurchaseResult> => {
      if (!__DEV__) return { status: "error", message: STUB_NOTE };
      await saveStorePurchaseEntitlement({
        productId: PLUS_PRODUCT_ID,
        transactionId: "expo-go-dev-stub",
        store: "dev-stub",
      });
      return { status: "success" };
    };
    return {
      connected: false,
      loadingProduct: false,
      product: stubProduct,
      productError: STUB_NOTE,
      purchaseUnlimited: purchase,
      restoreUnlimited: purchase,
      retryStoreConnection: async () => {},
    };
  }, []);
  return <PurchaseContext.Provider value={value}>{children}</PurchaseContext.Provider>;
}

export function PurchaseProvider({ children }: { children: React.ReactNode }) {
  if (!Iap) return <StubPurchaseProvider>{children}</StubPurchaseProvider>;
  return <NativePurchaseProvider>{children}</NativePurchaseProvider>;
}

export function usePurchase(): PurchaseContextValue {
  const context = useContext(PurchaseContext);
  if (!context) throw new Error("PurchaseProvider の外で usePurchase は使えません。");
  return context;
}
