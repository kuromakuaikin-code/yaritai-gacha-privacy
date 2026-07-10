# yaritai-gacha-privacy
Privacy policy for やりたいガチャ

## 盆踊りナビ

全国の盆踊り（町内会・商店街レベルの小さなものまで）を探せる情報サイト。

- サイト本体: `bon-odori/index.html`
- 公開URL: https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/bon-odori/
- 機能: キーワード検索／都道府県・時期（月）・規模での絞り込み／特徴タグ（屋台・飛び入りOKなど）／お気に入り／「地域の盆踊りを登録」（端末内 localStorage に保存）
- イベントデータは `index.html` 内の `EVENTS` 配列に記載。追加・修正はそこを編集する

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
