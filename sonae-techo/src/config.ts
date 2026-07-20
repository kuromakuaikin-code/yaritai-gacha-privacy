export const APP_VERSION = '1.0.0';

/** テスト期間中は true（購入ボタンで無料解放）。
 *  正式リリース時に false にし、react-native-iap で
 *  以下のプロダクトIDの非消耗型IAPを実装する */
export const FREE_TRIAL = true;

/** 無料カテゴリ（このカテゴリだけは購入前でも登録できる） */
export const FREE_CATEGORY_IDS = ['water', 'food'] as const;

/** 広告表示（広告なし/プレミアム購入者には出ない）。
 *  EAS Build ではAdMobの実バナーが自動で有効になり、
 *  Expo Go ではサンプル枠にフォールバックする。
 *  非パーソナライズ配信（NPA）固定のためATTダイアログは不要 */
export const ADS_ENABLED = true;

/** AdMobのバナーユニットID。空の間はGoogle公式のテスト広告を表示。
 *  リリース時に AdMob 管理画面で作成した本番IDに差し替える */
export const ADMOB_BANNER_UNIT_ID = '';

export const PREMIUM_PRICE = '¥200';

export const PREMIUM_PRODUCT_ID = 'com.kuromakuaikin.sonaetecho.premium';

export const PRIVACY_URL = 'https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/sonae-techo/privacy.html';
export const TERMS_URL = 'https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/sonae-techo/terms.html';

export const colors = {
  bg: '#faf6f2',
  card: '#ffffff',
  text: '#2a1c14',
  sub: '#6f5b4a',
  line: '#ecdccb',
  accent: '#d95b2b',
  accentSoft: '#fdeee2',
  accentDark: '#b8461e',
  green: '#2f8a63',
  greenSoft: '#e7f5ee',
  blue: '#4a7fb5',
  blueSoft: '#eaf1f8',
  gray: '#8a7f74',
  graySoft: '#f1ede8',
  gold: '#e8a33d',
  danger: '#d64545',
};
