# yaritai-gacha-privacy
Privacy policy for やりたいガチャ

## 盆踊りナビ愛知

愛知県内の町内会・学区・神社・公園レベルのローカルな盆踊りを探せるサイト。
目的：「今週末、愛知の近所で開催される小さな盆踊りを見つけること」

- 公開URL: https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/bon-odori/
- 一覧: 今日開催／今週末／市町村／現在地に近い順。各イベントに情報元・最終確認日・投稿者区分（運営確認済み／主催者投稿／住民投稿・未確認）・中止/延期/雨天情報を表示
- 個別ページ: イベントごとに `bon-odori/e/*.html`（タイトルにイベント名・市町村・開催日を含む、schema.org Event 構造化データ付き）
- **データ更新**: `bon-odori/events.json` を編集 → `cd bon-odori && python3 build.py` → コミット
- 運用手順・掲載ルール（転載禁止等）・要確認リスト: `bon-odori/ADMIN.md`
- 掲載データ: 自治体公式サイトで確認した実データ（名古屋市・半田市ほか、順次拡充）
- 応援ページ: `bon-odori/support.html`（寄付ボタン・チラシ作成サービス。URLの設定方法は ADMIN.md）

## 今日の許可（today_permission）

自分に許可を出す習慣アプリ（Flutter / Firebase Auth + Cloud Firestore）。

- プライバシーポリシー: `today-permission/privacy.html`
  - 公開URL: https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/today-permission/privacy.html
- 利用規約: `today-permission/terms.html`
  - 公開URL: https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/today-permission/terms.html
- 内容の前提: データは Firebase（Cloud Firestore）に保存・広告なし・独自解析なし・プレミアム（ストア課金）対応。認証方式（匿名/メール）が確定したら文面を断定形に要更新

## 婚活デートメモ

- アプリ本体（スマホ向けWebアプリ / テスト用）: `date-memo/index.html`
- iOS版（SwiftUI・App Store提出用）: `ios/`（セットアップは `ios/README.md`）
- プライバシーポリシー: `date-memo/privacy.md`
- 利用規約: `date-memo/terms.md`

### リリース手順（iOS / App Store）

1. SwiftUI へ移植（画面構成・データ構造は Web 版に準拠、保存は SwiftData/CoreData）
2. 課金：`freeTrial` 相当のデモ解放を削除し、StoreKit 2 の非消耗型 IAP を実装
   - プレミアム（例 ¥160）／広告なし（例 ¥120）の2商品＋「購入の復元」
3. 広告：AdMob バナー（広告なし/プレミアム購入者には非表示）。ATT 対応または非パーソナライズ配信
4. App Store Connect：プライバシーポリシー URL に
   `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/date-memo/privacy.html` を設定
5. プライバシー「栄養表示」：データ収集なし（広告関連は AdMob の SDK 申告に従う）

### リリース手順（Web 版を正式公開する場合）

`date-memo/index.html` 冒頭の設定を変更：

1. `PURCHASE.freeTrial` を `false` に
2. `PURCHASE.url` / `adFreeUrl` に Stripe Payment Link を設定（購入完了メールで解除コードを案内）
3. `UNLOCK.premium` / `adfree` に解除コードの SHA-256 を登録
   （生成: `printf '%s' 'コード' | shasum -a 256`）
4. `ADS.adsenseClient` / `adsenseSlot` に AdSense の ID を設定
5. Stripe 販売を行う場合は特定商取引法に基づく表記ページを用意
