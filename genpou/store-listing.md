# App Store 掲載情報（コピペ用）— 現報

## アプリ名（30文字以内）

```
現報 - 現場写真を日報・完了報告PDFに
```

## サブタイトル（30文字以内）

```
5分で完了報告。写真整理と報告書作成
```

## キーワード（100文字以内・カンマ区切り）

```
工事,現場,写真,日報,報告書,完了報告,台帳,施工,建設,電気,設備,内装,塗装,職人,一人親方,PDF
```

## 説明文

```
LINEに散らばる現場写真を、案件単位の正式PDFに。

「現報」は、電気・設備・内装・塗装など、現場で働く下請け・一人親方のための報告書アプリです。写真の整理から日報・完了報告書の作成、元請けへの提出まで、iPhoneひとつで完結します。

■ こんな経験ありませんか？
・現場写真がカメラロールとLINEに散らばって、どの案件のか分からない
・帰ってから日報を作るのが億劫で、つい溜めてしまう
・完了報告書のために、パソコンで写真を並べて…が毎回つらい

■ 主な機能

【案件ごとに写真を整理】
撮った写真は案件フォルダに自動で整理。「施工前・施工中・施工後」のタグをつければ、あとから探すのも一瞬です。

【日報PDFをその場で】
日付を選んで写真にチェックを入れるだけ。屋号・案件名・写真・時刻・キャプション入りの日報PDFが数十秒で完成します。

【完了報告書もワンタップ】
施工前→施工中→施工後の順に写真が自動で並んだ「工事完了報告書」を作成。代表者の署名欄付きで、そのまま元請けに提出できます。

【そのまま共有】
できあがったPDFはLINE・メールですぐ送信。電波のない現場でも作成できます（オフライン対応）。

■ 現場のための設計
・大きめのボタン、シンプルな画面。手袋を外してすぐ操作
・アカウント登録不要。開いてすぐ使えます
・写真も案件情報もすべて端末内に保存。サーバーには一切送信されません

■ 料金
個人プラン（月額・自動更新）
初回14日間は無料でお試しいただけます。トライアル終了後は、写真の追加とPDF作成に購入が必要です（保存済みデータの閲覧はいつでも可能）。

報告書づくりに使っていた夜の30分を、現場のあなたに返します。
```

## プロモーションテキスト（170文字以内・随時変更可）

```
現場写真を案件ごとに整理して、日報・完了報告書PDFをiPhoneだけで作成。施工前後のタグ整理、署名欄付き完了報告、LINE共有まで。初回14日間無料。
```

## その他の設定

| 項目 | 値 |
|---|---|
| カテゴリ | ビジネス（サブ: 仕事効率化） |
| 年齢制限 | 4+ |
| プライバシーポリシーURL | https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/genpou/privacy.html |
| 利用規約URL（任意欄） | https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/genpou/terms.html |
| 著作権 | © 2026 kuromakuaikin |

## サブスクリプション設定（App Store Connect）

| 項目 | 値 |
|---|---|
| 商品ID | `genpou.personal.monthly` |
| 参照名 | 個人プラン（月額） |
| 表示名 | 個人プラン |
| 説明 | 写真整理とPDF作成が使い放題 |
| 期間 | 1ヶ月（自動更新） |
| Introductory Offer | 14日間無料 |
| 価格 | 未定（コード変更不要。Connect 側の設定のみで反映） |

## プライバシー「栄養表示」の回答

- ユーザーデータの収集: **なし**
- 写真・会社情報・案件データ: すべて端末内保存のみ（収集に該当しない）
- 広告なし・解析なし・トラッキングなし
- 決済は Apple の IAP（アプリはユーザーの決済情報に触れない）

## 審査メモ（Review Notes に貼る用）

```
This app is a tool for construction subcontractors to organize job-site photos
by project and generate daily/completion report PDFs on device.

- NO server: all data (photos, projects, company profile) is stored only on
  the device (SwiftData + local files). PDFs are generated offline with PDFKit.
- NO account registration, NO ads, NO analytics, NO tracking.
- One auto-renewable subscription ("genpou.personal.monthly") with a 14-day
  free introductory offer. After expiry, adding photos and generating PDFs
  requires the subscription; viewing existing data remains available.
- Camera and photo library are used only to capture/select job-site photos.

Test instructions: complete onboarding (enter any business name), create a
project, add photos from the library, then tap 日報PDF (daily report) or
完了報告 (completion report) to generate and preview a PDF.
```

## スクリーンショット構成案（6.7インチ必須）

1. 案件詳細の写真グリッド（タグチップ付き）＋コピー「散らばる現場写真を、案件ごとに」
2. 完了報告PDFのプレビュー ＋「5分で完了報告」
3. 日報作成画面（チェックリスト）＋「日付を選んで、チェックするだけ」
4. タグ編集シート ＋「施工前・施工中・施工後で自動整理」
5. 共有シート ＋「そのままLINEで元請けへ」
6. オンボーディング/設定 ＋「登録不要・端末内保存・オフライン対応」
