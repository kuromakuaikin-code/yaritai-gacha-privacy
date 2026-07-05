export const APP_VERSION = '1.0.0';

/** テスト期間中は true（購入ボタンで無料解放）。
 *  正式リリース時に false にし、react-native-iap か RevenueCat で
 *  以下のプロダクトIDの非消耗型IAPを実装する */
export const FREE_TRIAL = true;

export const FREE_PARTNER_LIMIT = 3;

/** 広告表示（広告なし/プレミアム購入者には出ない）。
 *  EAS Build ではAdMobの実バナーが自動で有効になり、
 *  Expo Go ではサンプル枠にフォールバックする。
 *  非パーソナライズ配信（NPA）固定のためATTダイアログは不要 */
export const ADS_ENABLED = true;

/** AdMobのバナーユニットID。空の間はGoogle公式のテスト広告を表示。
 *  リリース時に AdMob 管理画面で作成した本番IDに差し替える */
export const ADMOB_BANNER_UNIT_ID = '';

export const PREMIUM_PRICE = '¥160';

export const PREMIUM_PRODUCT_ID = 'com.kuromakuaikin.datememo.premium';

export const PRIVACY_URL = 'https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/date-memo/privacy.html';
export const TERMS_URL = 'https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/date-memo/terms.html';

export const colors = {
  bg: '#faf6f7',
  card: '#ffffff',
  text: '#2e2227',
  sub: '#6f5b64',
  line: '#eddde3',
  accent: '#e05a7a',
  accentSoft: '#fdeef2',
  accentDark: '#c74564',
  green: '#2f8a63',
  greenSoft: '#e7f5ee',
  blue: '#4a7fb5',
  blueSoft: '#eaf1f8',
  gray: '#8a7f85',
  graySoft: '#f1edef',
  gold: '#e8a33d',
  danger: '#d64545',
};
