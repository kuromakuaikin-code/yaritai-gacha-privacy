# 婚活デートメモ（Expo / React Native 版）

Web版（`../date-memo/`）と同じ機能・**同じデータ形式**のネイティブアプリ。
Expo なので **Macなしで App Store 提出まで可能**（EAS Build / EAS Submit）。

## 機能

- お相手管理（検索・ステータス絞り込み・並び替え4種・無料3人制限・カラーアバター）
- デート記録（★評価・次回予定日カウントダウン）
- 話題リスト（4カテゴリ30話題＋会話フロー120フレーズ、Web版と同一ID）
- MYメモ・デート前カンペ・話題ガチャ
- プレミアム／広告なし（テスト期間は無料解放。`src/config.ts` の `FREE_TRIAL`）
- パスコードロック（SHA-256）
- バックアップ書き出し/読み込み — **Web版のJSONがそのまま読み込める**

## 開発（VSCode / Windows OK）

```bash
cd app-expo
npm install
npx expo start          # QRコードをiPhoneの Expo Go アプリで読むと実機で動く
```

型チェック: `npm run typecheck`

## App Store 提出（Macなし）

```bash
npm install -g eas-cli
eas login               # Expoアカウント
eas build:configure
eas build --platform ios     # クラウドでビルド（Apple Developer Program 必須・年12,980円）
eas submit --platform ios    # App Store Connect へアップロード
```

## リリース前チェックリスト

**最新の手順は `RELEASE.md` を参照**（IAP・AdMob・復元は実装済み。フラグ差し替えのみ）

<details><summary>旧メモ</summary>

1. `src/config.ts` の `FREE_TRIAL` を `false` に
2. 課金: `react-native-iap` か RevenueCat を導入し、
   `com.kuromakuaikin.datememo.premium`（¥160）/ `.adfree`（¥120）の非消耗型IAPを実装
   （App Store Connect 側でも商品を作成）
3. 広告: `react-native-google-mobile-ads` を導入し `App.tsx` の `AdBar` を BannerAd に置き換え
   （ATT対応または非パーソナライズ配信。app.json にAdMobアプリIDを設定）
4. App Store Connect のプライバシーポリシーURL:
   `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/date-memo/privacy.html`
5. アイコン: `assets/icon.png` を1024pxに差し替え推奨（現在はWeb版の512px）

</details>
