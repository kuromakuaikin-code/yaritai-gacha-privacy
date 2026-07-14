/**
 * 広告の仕込み（現在は無効）。
 *
 * v1.0 は「広告なし・データ収集なし」で公開する。
 * 有効化する場合の手順（v1.1以降）:
 *
 * 1. AdMobアカウントでアプリとバナー広告ユニットを作成
 * 2. `npx expo install react-native-google-mobile-ads` を実行し、
 *    app.json のプラグインに androidAppId / iosAppId を設定
 *    （app-expo/ の実装と同じ構成。Expo Goでは動かないため
 *    expo-iap と同様の実行環境判定スタブが必要）
 * 3. AdBanner.tsx の中身を実バナーに差し替え、下のフラグを true に
 * 4. プライバシーポリシー（app/settings/privacy.tsx）を改訂:
 *    「広告なし・データ収集なし」→ 広告SDKによる識別子収集を明記
 * 5. App Privacy / Data safety の申告を「収集あり」に変更、
 *    iOSはATT対応または非パーソナライズ配信を設定、app-ads.txt を設置
 * 6. ペイウォール文言を「購入で広告も非表示」に更新
 *
 * ここを true にしただけでは広告は出ない（SDK未導入のため）。
 * 誤ってフラグだけ変えても表示が壊れないよう、AdBanner側でも
 * SDKの有無を確認する。
 */
export const ADS_ENABLED = false;
