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

## お薬手帳メモ

ご家族一人ひとりのお薬（名前・用量・服用タイミング・処方病院・服用期間）を登録し、「今日、誰が・いつ・どのお薬を飲んだか」をチェックして記録するアプリ。

- iOS版（SwiftUI・App Store提出用）: `ios-okusurimemo/`（セットアップ・リリース手順は `ios-okusurimemo/README.md`）
- プライバシーポリシー: `okusuri-memo/privacy.html`
- 利用規約: `okusuri-memo/terms.html`

### リリース手順（iOS / App Store）

1. `ios-okusurimemo/OkusuriMemo/Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - プレミアム（`com.kuromakuaikin.okusurimemo.premium` / 例 ¥160）
   - 広告なし（`com.kuromakuaikin.okusurimemo.adfree` / 例 ¥120）＋「購入の復元」
3. 広告：AdMob バナー（広告なし/プレミアム購入者には非表示）。ATT 対応または非パーソナライズ配信
4. App Store Connect：プライバシーポリシー URL に
   `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/okusuri-memo/privacy.html` を設定
5. プライバシー「栄養表示」：データ収集なし（広告関連は AdMob の SDK 申告に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定
7. 「本アプリは医学的な助言を目的としたものではない」旨の注意書き（設定タブ）は削除・改変せず維持すること

## 年賀状・贈り物管理

年賀状、お中元・お歳暮などの季節の贈り物について「誰に・いつ・送ったか／もらったか」を記録し、送り忘れや重複を防ぐアプリ。

- iOS版（SwiftUI・App Store提出用）: `ios-nengamemo/`（セットアップ・リリース手順は `ios-nengamemo/README.md`）
- プライバシーポリシー: `nenga-memo/privacy.html`
- 利用規約: `nenga-memo/terms.html`

### リリース手順（iOS / App Store）

1. `ios-nengamemo/NengaMemo/Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - プレミアム（`com.kuromakuaikin.nengamemo.premium` / 例 ¥160）
   - 広告なし（`com.kuromakuaikin.nengamemo.adfree` / 例 ¥120）＋「購入の復元」
3. 広告：AdMob バナー（広告なし/プレミアム購入者には非表示）。ATT 対応または非パーソナライズ配信
4. App Store Connect：プライバシーポリシー URL に
   `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/nenga-memo/privacy.html` を設定
5. プライバシー「栄養表示」：ユーザーデータ収集なし（広告関連は AdMob の SDK 申告に従う）。宛先（第三者）の氏名・住所は端末内保存のみで外部送信なし
6. アプリアイコン（1024×1024）を用意して Assets に設定

## ゴミ出しカレンダー

家庭ごとに異なるゴミ・資源の収集ルール（曜日・頻度）を登録しておき、今日・明日・今後1週間で何を出せばよいかをひと目で確認できるアプリ。

- iOS版（SwiftUI・App Store提出用）: `ios-gomicalendar/`（セットアップ・リリース手順は `ios-gomicalendar/README.md`）
- プライバシーポリシー: `gomi-calendar/privacy.html`
- 利用規約: `gomi-calendar/terms.html`
- 収集ルールの判定ロジック: `ios-gomicalendar/GomiCalendar/Models.swift` の `GarbageRule.applies(on:)`（隔週・第1&3・第2&4は `Calendar` の週番号による簡易判定。地域の起算日とずれる場合はあくまで目安として利用すること）

### リリース手順（iOS / App Store）

1. `ios-gomicalendar/GomiCalendar/Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - プレミアム（`com.kuromakuaikin.gomicalendar.premium` / 例 ¥160）
   - 広告なし（`com.kuromakuaikin.gomicalendar.adfree` / 例 ¥120）＋「購入の復元」
3. 広告：AdMob バナー（広告なし/プレミアム購入者には非表示）。ATT 対応または非パーソナライズ配信
4. リマインダー通知（プレミアム限定）：`SettingsViews.swift` の `NotificationService` がローカル通知を登録。初回有効化時に通知許可ダイアログが表示される（簡易実装、内容はアプリ起動・設定変更のたびに当日分へ更新）
5. App Store Connect：プライバシーポリシー URL に
   `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/gomi-calendar/privacy.html` を設定
6. プライバシー「栄養表示」：データ収集なし（広告関連は AdMob の SDK 申告に従う）
7. アプリアイコン（1024×1024）を用意して Assets に設定

## お守り返納リマインダー

神社・お寺でいただいたお守り・御札・破魔矢を記録し、返納の目安時期（授与から約1年後）を忘れないためのリマインダーアプリ。

- iOS版（SwiftUI・App Store提出用）: `ios-omamorireminder/`（セットアップ・リリース手順は `ios-omamorireminder/README.md`）
- プライバシーポリシー: `omamori-reminder/privacy.html`
- 利用規約: `omamori-reminder/terms.html`
- お守りの作法ガイドのデータ: `ios-omamorireminder/OmamoriReminder/Models.swift` の `GuideData`（一般的な目安。リリース前に最新情報で見直すこと）

### リリース手順（iOS / App Store）

1. `ios-omamorireminder/OmamoriReminder/Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - プレミアム（`com.kuromakuaikin.omamorireminder.premium` / 例 ¥160）
   - 広告なし（`com.kuromakuaikin.omamorireminder.adfree` / 例 ¥120）＋「購入の復元」
3. 広告：AdMob バナー（広告なし/プレミアム購入者には非表示）。ATT 対応または非パーソナライズ配信
4. App Store Connect：プライバシーポリシー URL に
   `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/omamori-reminder/privacy.html` を設定
5. プライバシー「栄養表示」：データ収集なし（広告関連は AdMob の SDK 申告に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定

## ペット健康手帳

犬・猫などペットのワクチン接種、通院・健診、体重測定、トリミングなどの記録を管理し、次回の予定日や体重の推移を確認できるアプリ。

- iOS版（SwiftUI・App Store提出用）: `ios-pethealthmemo/`（セットアップ・リリース手順は `ios-pethealthmemo/README.md`）
- プライバシーポリシー: `pet-health-memo/privacy.html`
- 利用規約: `pet-health-memo/terms.html`

### リリース手順（iOS / App Store）

1. `ios-pethealthmemo/PetHealthMemo/Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - プレミアム（`com.kuromakuaikin.pethealthmemo.premium` / 例 ¥160）
   - 広告なし（`com.kuromakuaikin.pethealthmemo.adfree` / 例 ¥120）＋「購入の復元」
3. 広告：AdMob バナー（広告なし/プレミアム購入者には非表示）。ATT 対応または非パーソナライズ配信
4. App Store Connect：プライバシーポリシー URL に
   `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/pet-health-memo/privacy.html` を設定
5. プライバシー「栄養表示」：データ収集なし（広告関連は AdMob の SDK 申告に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定

## 防災グッズチェックリスト

家庭の防災グッズ（非常食・飲料水・衛生用品・情報収集グッズ・貴重品・子供や高齢者・ペット用品など）の準備状況をチェックリストで管理し、家族の緊急連絡先・避難時の集合場所をカード形式で記録するアプリ。

- iOS版（SwiftUI・App Store提出用）: `ios-bousaicheck/`（セットアップ・リリース手順は `ios-bousaicheck/README.md`）
- プライバシーポリシー: `bousai-check/privacy.html`
- 利用規約: `bousai-check/terms.html`
- 標準チェックリストのデータ: `ios-bousaicheck/BousaiCheck/Models.swift` の `PresetChecklistData`（一般的な目安。世帯構成・地域のハザードにより過不足があるため、リリース前に見直すこと）

### リリース手順（iOS / App Store）

1. `ios-bousaicheck/BousaiCheck/Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - プレミアム（`com.kuromakuaikin.bousaicheck.premium` / 例 ¥160）
   - 広告なし（`com.kuromakuaikin.bousaicheck.adfree` / 例 ¥120）＋「購入の復元」
3. 広告：AdMob バナー（広告なし/プレミアム購入者には非表示）。ATT 対応または非パーソナライズ配信
4. App Store Connect：プライバシーポリシー URL に
   `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/bousai-check/privacy.html` を設定
5. プライバシー「栄養表示」：データ収集なし（広告関連は AdMob の SDK 申告に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定

## 子どもの成長記録

赤ちゃん・子どもの身長体重を記録し、グラフで成長を振り返れるアプリ。母子手帳の成長曲線ページをデジタル化したもの。

- iOS版（SwiftUI・App Store提出用）: `ios-kodomogrowth/`（セットアップ・リリース手順は `ios-kodomogrowth/README.md`）
- プライバシーポリシー: `kodomo-growth/privacy.html`
- 利用規約: `kodomo-growth/terms.html`

### リリース手順（iOS / App Store）

1. `ios-kodomogrowth/KodomoGrowth/Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - プレミアム（`com.kuromakuaikin.kodomogrowth.premium` / 例 ¥160）
   - 広告なし（`com.kuromakuaikin.kodomogrowth.adfree` / 例 ¥120）＋「購入の復元」
3. 広告：AdMob バナー（広告なし/プレミアム購入者には非表示）。ATT 対応または非パーソナライズ配信
4. App Store Connect：プライバシーポリシー URL に
   `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/kodomo-growth/privacy.html` を設定
5. プライバシー「栄養表示」：データ収集なし（広告関連は AdMob の SDK 申告に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定

## おでかけ思い出手帳

家族のおでかけ先を「公園・遊び場」「花見・紅葉スポット」「キャンプ・BBQ場」「観光・お城スタンプ帳」の4カテゴリで記録できるアプリ。4カテゴリは共通の`OutingVisit`モデルをカテゴリで絞り込んで使い回す設計にしており、単機能アプリの乱立を避けるため4つの記録機能を1本にまとめた構成になっている（既存の「御朱印帳ログ」とは神社・お寺の御朱印参拝記録という別スコープの別アプリ）。

- iOS版（SwiftUI・App Store提出用）: `ios-odekakememories/`（セットアップ・リリース手順は `ios-odekakememories/README.md`）
- プライバシーポリシー: `odekake-memories/privacy.html`
- 利用規約: `odekake-memories/terms.html`

### リリース手順（iOS / App Store）

1. `ios-odekakememories/OdekakeMemories/Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを2つ作成
   - プレミアム（`com.kuromakuaikin.odekakememories.premium` / 例 ¥160）
   - 広告なし（`com.kuromakuaikin.odekakememories.adfree` / 例 ¥120）＋「購入の復元」
3. 広告：AdMob バナー（広告なし/プレミアム購入者には非表示）。ATT 対応または非パーソナライズ配信
4. App Store Connect：プライバシーポリシー URL に
   `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/odekake-memories/privacy.html` を設定
5. プライバシー「栄養表示」：データ収集なし（広告関連は AdMob の SDK 申告に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定
