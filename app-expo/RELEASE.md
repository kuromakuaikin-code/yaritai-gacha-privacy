# リリース手順（Macなし・Windowsのみで完結）

コード側の本実装（IAP・AdMob・復元・EAS設定・1024アイコン）は済んでいる。
残りは以下のアカウント作業と、フラグ2つの差し替えだけ。

## 0. 事前に必要なアカウント

| アカウント | 費用 | 用途 |
|---|---|---|
| Apple Developer Program | 年12,980円 | App Store配信 |
| Expo アカウント | 無料 | EAS Build（クラウドビルド） |
| AdMob アカウント | 無料 | 広告収益 |

## 1. App Store Connect の準備（ブラウザ作業）

1. https://appstoreconnect.apple.com → マイApp → 新規App
   - 名前: 婚活デートメモ ／ バンドルID: `com.kuromakuaikin.datememo`
2. App内課金 → 非消耗型を2つ作成
   - `com.kuromakuaikin.datememo.premium` … ¥160（価格Tier確認）
   - `com.kuromakuaikin.datememo.adfree` … ¥120
3. 掲載情報・スクショ・プライバシー回答は `store-listing.md` からコピペ

## 2. AdMob の準備

1. https://admob.google.com → アプリを追加（iOS）→ **AdMobアプリID** を取得
2. バナー広告ユニットを作成 → **ユニットID** を取得

## 3. コードの本番化（差し替えは2ファイルだけ）

1. `src/config.ts`
   - `FREE_TRIAL` → `false`
   - `ADMOB_BANNER_UNIT_ID` → AdMobのバナーユニットID
2. `app.json` の plugins にある `iosAppId` を、テストID（ca-app-pub-394025…）から
   自分のAdMobアプリIDへ差し替え

## 4. ビルドと提出（PowerShell）

```powershell
npm install -g eas-cli
eas login
cd app-expo
eas build --platform ios        # 初回はApple IDログイン・証明書自動作成の質問に答える
eas submit --platform ios       # App Store Connect へアップロード
```

## 5. TestFlight → 審査

1. App Store Connect → TestFlight で自分のiPhoneに配信し、実課金なしのサンドボックスで
   **購入・復元・広告表示** を確認（サンドボックスApple IDはASCで作成）
2. 問題なければ「審査へ提出」

## 補足

- Expo Go では引き続き開発テスト可能（IAP/AdMobは自動でスタブ/サンプル枠になる）
- 審査で聞かれたら `store-listing.md` の Review Notes を貼る
- 将来のアップデート: `version` と `ios.buildNumber` を上げて `eas build` → `eas submit`
