# 家の手入れ記録（Expo / React Native）

家電・住宅設備・交換品の「最後にいつ」と「次はいつ」を残す個人用の履歴台帳。
エアコン、換気設備、浄水器、火災警報器の電池などの実施日を記録すると、
次回の目安日を自動計算し、端末内の通知でお知らせします。

**本アプリは記録・通知の補助ツールです。** 家電や住宅設備の安全性・故障・寿命の
診断は行いません。表示される周期は一般的な目安であり、製品の取扱説明書や
メーカーの案内が優先です。

## 技術構成

- Expo SDK 54 / React Native 0.81 / TypeScript（strict）
- Expo Router（ファイルベースルーティング）
- expo-sqlite（メインデータ。アプリのローカル領域に保存）
- expo-notifications（ローカル通知のみ）
- expo-image-picker + expo-file-system（写真はアプリのローカル領域に保存）
- React Hook Form + Zod（登録・編集フォームのバリデーション）
- 広告・解析SDK・外部API・アカウントなし。OTA更新は明示的に無効

## 開発

```bash
cd ouchi-mente
npm install
npx expo start        # QRコードをExpo Goで読むと実機で動く
npm run typecheck     # 型チェック
```

依存パッケージを追加・更新したら、アプリ内のオープンソースライセンス一覧
（`src/legal/oss-licenses.json`）を再生成する:

```bash
npx license-checker --production --json --excludePrivatePackages \
  | node -e "const d=JSON.parse(require('fs').readFileSync(0));const es=Object.entries(d).map(([k,i])=>{const a=k.lastIndexOf('@');const e={n:k.slice(0,a),v:k.slice(a+1),l:String(i.licenses)};if(i.publisher)e.p=String(i.publisher);return e}).sort((x,y)=>x.n.localeCompare(y.n));require('fs').writeFileSync('src/legal/oss-licenses.json',JSON.stringify(es))"
```

## 実機ビルド（iOS）

前提: Apple Developer Program（年12,980円）加入、Expoアカウント。

```bash
npm install -g eas-cli
eas login
eas init                      # プロジェクトIDを作成しapp.jsonに書き込む（初回のみ）
eas device:create             # テストに使うiPhoneを登録（URLをiPhoneで開く・初回のみ）

npm run build:ios-dev         # Development Build（クラウドでビルド）
# 完了後に表示されるURLをiPhoneで開いてインストール
npx expo start                # PCで起動し、ビルド済みアプリから接続して動作確認
```

Development Build では expo-iap が本物のStoreKitに接続する。
IAPを試すには先に App Store Connect 側の準備が必要:

1. App Store Connect でアプリを作成（Bundle ID: `com.kuromakuaikin.ouchimente`）
2. 「App内課金」で非消耗型 `com.kuromakuaikin.ouchimente.unlimited`（¥300）を作成
3. 「ユーザとアクセス」→ Sandboxテスターを作成し、iPhoneの
   設定 → App Store → サンドボックスアカウント にサインイン
4. アプリ内で購入 → 削除 → 再インストール → 「購入の復元」を確認
   （未購入のサンドボックスアカウントで復元→「見つかりません」も確認）

開発用機能（設定の「購入状態をリセット」）は `__DEV__` ゲートのため、
開発サーバー接続中のみ表示され、TestFlight・本番ビルドには含まれない。

提出:

```bash
npm run build:ios-prod        # 本番ビルド（buildNumber自動インクリメント）
npm run submit:ios            # App Store Connect へアップロード
```

提出前チェックリストは `store-listing.md` を参照
（配信地域を日本のみにする、を忘れずに）。

### Expo Go でできること / できないこと

- ✅ 登録・一覧・詳細・編集・完了記録・履歴・写真・テンプレート・設定（SQLite・ローカル通知はExpo Goでも動作）
- ✅ 無料3件の上限 → ペイウォール → 解放 → 無制限登録の一連のフロー
  （Expo Goではストア決済が使えないため、購入ボタンは**開発用の疑似購入**として動作。
  画面に「この実行環境ではストア決済を利用できません」と表示される）
- ❌ 実際のApp Store / Google Play決済 — `eas build --profile development` の
  Development Build 実機でのみ確認可能（expo-iapはネイティブモジュールのため）

expo-iap は実行環境を判定して読み込むため、Expo Go でもクラッシュしない
（`src/purchase/PurchaseProvider.tsx` のスタブ切り替え）。

## フォルダ構成

```
app/                        # 画面（Expo Router）
  _layout.tsx               # マイグレーション実行・通知ハンドラ・Stack定義
  index.tsx                 # ホーム（期限順一覧・件数サマリー）
  onboarding.tsx            # 初回説明3ページ＋通知許可
  templates.tsx             # テンプレート選択
  items/new.tsx             # 項目登録（テンプレート反映）
  items/[id]/index.tsx      # 項目詳細
  items/[id]/edit.tsx       # 項目編集
  items/[id]/complete.tsx   # 完了記録（モーダル）
  items/[id]/history.tsx    # 実施履歴（編集・削除）
  settings/                 # 設定・利用規約・プライバシー・免責・アプリについて
src/
  domain/                   # 型・日付/周期計算・テンプレート・日本語ラベル
  db/                       # SQLite（items / history / settings）
  notifications/            # ローカル通知の登録・再設定・起動時照合・破棄
  media/                    # 写真の端末内保存・削除
  components/               # フォーム部品・カード・共通UI
  theme.ts                  # 配色・余白などのデザイントークン
```

## データ設計（SQLite）

- `maintenance_items` … メンテナンス項目。周期（interval/fixedDate/none）、
  次回予定日、通知設定、通知ID、メーカー・型番・写真URIなど
- `maintenance_history` … 実施履歴。`ON DELETE CASCADE` で項目削除時に一括削除
- `app_settings` … オンボーディング済みフラグ・通知の初期設定
- スキーマ版数は `PRAGMA user_version` で管理（現在: 1）

日付はすべて端末ローカルの暦日 `YYYY-MM-DD` で保存。月単位の周期は月末を
超えないよう丸める（1/31 の1か月後 → 2/28）。

## 通知の管理方針

- 1項目につき通知は最大1件。作成・編集・完了記録・削除のたびに
  古い通知IDをキャンセルして登録し直す
- 起動時にDBの通知IDとOS側の予約を照合し、未来の予約が欠落していれば再登録する
- 通知時刻は「目安日 −（通知タイミング日数）」の指定時刻（初期値は朝9時。
  設定画面で変更でき、変更時は登録済みの通知もすべて張り替える）。
  通知時刻をすでに過ぎている場合は登録しない（ホームの「目安日超過」表示に任せる）
- 許可がない場合・登録に失敗した場合も、データ操作は継続できる（通知は補助機能）

## 動作確認の手順

1. 初回起動 → 説明3ページ → 通知許可 → ホーム
2. 「テンプレートから追加」→ エアコンフィルター → 前回実施日を選んで登録
3. ホームに「30日以内」などの区分で表示され、残り日数が出る
4. 「完了」→ 実施日・次回目安を確認して記録 → 履歴に残り予定日が更新される
5. 編集で周期・次回予定日・通知タイミングを変更できる
6. 設定 → すべてのデータを削除 → 空の状態に戻る

## 課金（無制限版）

- 無料版: 登録上限 **3件**
- 無制限版: **¥300 買い切り（非消耗型）で登録上限なし**
  - 商品ID: `com.kuromakuaikin.ouchimente.unlimited`
  - 履歴・通知・テンプレートなどの機能差はなし。広告もなし
- 上限チェックは新規登録時のみ（編集・完了記録・履歴は制限なし）
- ホーム画面に残り枠を表示（上限−1件から）。上限到達で案内画面（`app/paywall.tsx`）へ
- 「すべてのデータを削除」しても購入済みフラグは維持される

### リリース時のIAP接続作業

- `expo-iap@3.4.13` を利用し、ストアの商品情報・購入・復元を扱う。
- 商品ID: `com.kuromakuaikin.ouchimente.unlimited`（iOS / Android とも同じID）
- Expo GoではIAPを試せない。IAPを含むDevelopment Buildまたはストア経由の実機で確認する。
- Development Buildは、Expo/EASへログイン後に `npx eas-cli@latest build --platform ios --profile development`
  または `--platform android` で作成する（クラウドビルド枠を使うため、ここでは実行しない）。
- App Store Connect / Google Play Consoleに、買い切りの非消耗型商品を作成し、
  実機で購入・復元まで確認してから公開する。
- 購入済み状態は端末内にキャッシュするが、起動時と「購入の復元」でストアと再照合する。
  ストア障害だけで購入済みの人を無料へ戻さない。
- 購入の復元は同一ストア内（Apple同士 / Google同士）のみ。アカウント・サーバーを持たないため、
  iPhoneとAndroidの間で購入を共有しない。

## MVPで実装していないもの（設計書どおり）

クラウド同期・アカウント・AI・外部API・バーコード検索・家族共有・
アプリ独自のバックアップ/復元。なお、端末設定によりOSバックアップや端末移行の
対象になる場合があります。
