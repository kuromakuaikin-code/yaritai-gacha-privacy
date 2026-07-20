# そなえ手帳（Expo / React Native）

家庭の防災備蓄（水・食料・カセットボンベ・トイレットペーパー・電池など）を登録しておくと、
家族人数×目標日数から算出した「推奨量」との過不足がひと目で分かり、期限が近いものを教えてくれるアプリ。

「婚活デートメモ」（`../app-expo/`）と同じ構成（Expo + AsyncStorage 端末内保存 + 買い切りIAP + AdMob）で作られている。

## 機能

- 備蓄品の登録（カテゴリ・数量・期限・メモ）
- ホーム画面でカテゴリ別「現在量 / 推奨量」を自動計算・進捗バー表示
- 期限が近い順の一覧・期限切れ/期限間近の色分け警告
- 無料：飲料水・主食の2カテゴリのみ登録可
- プレミアム（買い切り）：カセットボンベ・トイレットペーパー・電池・その他カテゴリを解放＋期限が近づいたらローカル通知
- バックアップ書き出し/読み込み（JSONファイル）
- 広告（AdMob）はプレミアム購入で非表示

## 開発（VSCode / Windows OK）

```bash
cd sonae-techo
npm install
npx expo start          # QRコードをiPhoneの Expo Go アプリで読むと実機で動く
```

型チェック: `npm run typecheck`

Expo Go では IAP・AdMob・ローカル通知のネイティブモジュールが無いため、
それぞれ「テスト期間中の無料解放」「サンプル広告枠」「通知トグルが無効」にフォールバックする。
実機での動作確認には EAS Build（開発ビルド）が必要。

## App Store 提出（Macなし）

初回のみ、Expo/EASのプロジェクト紐付けが必要（本リポジトリにはアカウント固有のIDを含めていない）。

```bash
npm install -g eas-cli
eas login                    # Expoアカウント
eas build:configure          # このとき app.json に extra.eas.projectId が追記される
eas build --platform ios     # クラウドでビルド（Apple Developer Program 必須・年12,980円）
eas submit --platform ios    # App Store Connect へアップロード
```

## リリース前チェックリスト

**最新の手順は `RELEASE.md` を参照。**

<details><summary>要点</summary>

1. `src/config.ts` の `FREE_TRIAL` を `false` に
2. `react-native-iap` で `com.kuromakuaikin.sonaetecho.premium`（¥200）の非消耗型IAPを実装
   （App Store Connect 側でも商品を作成）
3. 広告: `app.json` の `react-native-google-mobile-ads` プラグインの `iosAppId` をテストIDから
   自分のAdMobアプリIDに差し替え、`src/config.ts` の `ADMOB_BANNER_UNIT_ID` にバナーユニットIDを設定
4. App Store Connect のプライバシーポリシーURL:
   `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/sonae-techo/privacy.html`
5. アイコン: `assets/icon.png` はプレースホルダー（警告三角形の単色アイコン）。差し替え推奨

</details>
