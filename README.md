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

## ご祝儀・香典メモ

結婚式のご祝儀、お葬式の香典、出産・入学・新築祝いなどの「誰に・いくら・いつ」を記録し、相場の目安とお返し（香典返し・内祝い）の対応状況を管理するアプリ。

- iOS版（SwiftUI・App Store提出用）: `ios-shugimemo/`（セットアップ・リリース手順は `ios-shugimemo/README.md`）
- プライバシーポリシー: `shugi-memo/privacy.html`
- 利用規約: `shugi-memo/terms.html`
- 相場ガイドのデータ: `ios-shugimemo/ShugiMemo/Models.swift` の `MarketRateData`（一般的な目安。リリース前に最新情報で見直すこと）

### リリース手順（iOS / App Store）

1. `ios-shugimemo/ShugiMemo/Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - プレミアム（`com.kuromakuaikin.shugimemo.premium` / 例 ¥160）
   - 広告なし（`com.kuromakuaikin.shugimemo.adfree` / 例 ¥120）＋「購入の復元」
3. 広告：AdMob バナー（広告なし/プレミアム購入者には非表示）。ATT 対応または非パーソナライズ配信
4. App Store Connect：プライバシーポリシー URL に
   `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/shugi-memo/privacy.html` を設定
5. プライバシー「栄養表示」：データ収集なし（広告関連は AdMob の SDK 申告に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定

## 御朱印帳ログ

神社・お寺で受けた御朱印の参拝記録（参拝先・都道府県・参拝日・初穂料/拝観料・祈願内容・評価・メモ）を残せるアプリ。写真は保存せず、御朱印のデザイン等はメモに記述する方式。

- iOS版（SwiftUI・App Store提出用）: `ios-goshuinlog/`（セットアップ・リリース手順は `ios-goshuinlog/README.md`）
- プライバシーポリシー: `goshuin-log/privacy.html`
- 利用規約: `goshuin-log/terms.html`
- 集計タブの都道府県カバレッジは `ios-goshuinlog/GoshuinLog/Models.swift` の `PrefectureData.all`（47都道府県）が母数

### リリース手順（iOS / App Store）

1. `ios-goshuinlog/GoshuinLog/Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - プレミアム（`com.kuromakuaikin.goshuinlog.premium` / 例 ¥160）
   - 広告なし（`com.kuromakuaikin.goshuinlog.adfree` / 例 ¥120）＋「購入の復元」
3. 広告：AdMob バナー（広告なし/プレミアム購入者には非表示）。ATT 対応または非パーソナライズ配信
4. App Store Connect：プライバシーポリシー URL に
   `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/goshuin-log/privacy.html` を設定
5. プライバシー「栄養表示」：データ収集なし（広告関連は AdMob の SDK 申告に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定

## 冷蔵庫の賞味期限メモ

冷蔵庫・冷凍庫・常温保存の食品の賞味期限／消費期限を記録し、期限が近い食品をひと目で確認して食品ロスを減らすアプリ。

- iOS版（SwiftUI・App Store提出用）: `ios-shelflifememo/`（セットアップ・リリース手順は `ios-shelflifememo/README.md`）
- プライバシーポリシー: `shelf-life-memo/privacy.html`
- 利用規約: `shelf-life-memo/terms.html`

### リリース手順（iOS / App Store）

1. `ios-shelflifememo/ShelfLifeMemo/Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - プレミアム（`com.kuromakuaikin.shelflifememo.premium` / 例 ¥160）
   - 広告なし（`com.kuromakuaikin.shelflifememo.adfree` / 例 ¥120）＋「購入の復元」
3. 広告：AdMob バナー（広告なし/プレミアム購入者には非表示）。ATT 対応または非パーソナライズ配信
4. App Store Connect：プライバシーポリシー URL に
   `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/shelf-life-memo/privacy.html` を設定
5. プライバシー「栄養表示」：データ収集なし（広告関連は AdMob の SDK 申告に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定

## サブスク管理帳

動画配信・音楽配信・クラウドストレージ・ニュース・フィットネス・ゲームなど、家庭で契約している複数のサブスクリプションサービスの「サービス名・料金・支払いサイクル・次回更新日」をまとめて記録し、月あたりの合計コストを一目で把握できるアプリ。

- iOS版（SwiftUI・App Store提出用）: `ios-subscriptionledger/`（セットアップ・リリース手順は `ios-subscriptionledger/README.md`）
- プライバシーポリシー: `subscription-ledger/privacy.html`
- 利用規約: `subscription-ledger/terms.html`
- 次回更新日の計算ロジック: `ios-subscriptionledger/SubscriptionLedger/Models.swift` の `RenewalCalculator`（月末日のクランプ処理・年払いの繰り上げに対応）

### リリース手順（iOS / App Store）

1. `ios-subscriptionledger/SubscriptionLedger/Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - プレミアム（`com.kuromakuaikin.subscriptionledger.premium` / 例 ¥160）
   - 広告なし（`com.kuromakuaikin.subscriptionledger.adfree` / 例 ¥120）＋「購入の復元」
3. 広告：AdMob バナー（広告なし/プレミアム購入者には非表示）。ATT 対応または非パーソナライズ配信
4. App Store Connect：プライバシーポリシー URL に
   `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/subscription-ledger/privacy.html` を設定
5. プライバシー「栄養表示」：データ収集なし（広告関連は AdMob の SDK 申告に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定
