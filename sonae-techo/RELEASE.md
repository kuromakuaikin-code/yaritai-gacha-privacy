# リリース手順（Macなし・Windowsのみで完結）

コード側の実装（IAP・AdMob・通知・EAS設定の下地）は済んでいる。
残りは以下のアカウント作業と、プレースホルダー値の差し替えだけ。

## 0. 事前に必要なアカウント

| アカウント | 費用 | 用途 |
|---|---|---|
| Apple Developer Program | 年12,980円 | App Store配信 |
| Expo アカウント | 無料 | EAS Build（クラウドビルド） |
| AdMob アカウント | 無料 | 広告収益 |

## 1. Expo プロジェクトの紐付け（初回のみ）

```powershell
npm install -g eas-cli
eas login
cd sonae-techo
eas build:configure     # app.json に extra.eas.projectId が自動追記される
```

## 2. App Store Connect の準備（ブラウザ作業）

1. https://appstoreconnect.apple.com → マイApp → 新規App
   - 名前: そなえ手帳 ／ バンドルID: `com.kuromakuaikin.sonaetecho`
2. App内課金 → 非消耗型を1つ作成
   - `com.kuromakuaikin.sonaetecho.premium` … ¥200
   - 全カテゴリ解放・期限通知・広告非表示をまとめて含む単一プラン
3. 掲載情報・スクショ・プライバシー回答は `store-listing.md` からコピペ

## 3. AdMob の準備

1. https://admob.google.com → アプリを追加（iOS）→ **AdMobアプリID** を取得
2. バナー広告ユニットを作成 → **ユニットID** を取得

## 4. コードの本番化（差し替えは2ファイルだけ）

1. `src/config.ts`
   - `FREE_TRIAL` → `false`
   - `ADMOB_BANNER_UNIT_ID` → AdMobのバナーユニットID
2. `app.json` の plugins にある `react-native-google-mobile-ads` の `iosAppId` を、
   テストID（`ca-app-pub-3940256099942544~1458002511`）から自分のAdMobアプリIDへ差し替え

## 5. ビルドと提出（PowerShell）

```powershell
eas build --platform ios        # 初回はApple IDログイン・証明書自動作成の質問に答える
eas submit --platform ios       # App Store Connect へアップロード
```

## 6. TestFlight → 審査

1. App Store Connect → TestFlight で自分のiPhoneに配信し、実課金なしのサンドボックスで
   **購入・期限通知・広告表示** を確認（サンドボックスApple IDはASCで作成）
2. 問題なければ「審査へ提出」

## 補足

- Expo Go では引き続き開発テスト可能（IAP/AdMob/通知は自動でスタブ/サンプル枠になる）
- 審査で聞かれたら `store-listing.md` の Review Notes を貼る
- 将来のアップデート: `version` と `ios.buildNumber` を上げて `eas build` → `eas submit`
