# ShortLab — CLAUDE.md

## 最優先ルール

**時間値は必ず `RenderSpec.time()` (timescale 600) で生成する。** `CMTime(seconds:preferredTimescale:)` を直接呼ぶコードは書かない。timescale 混在は音ズレ・分割位置ズレの根本原因であり、発見が遅れるほど修正コストが跳ね上がる。

## ルーティング表

| キーワード | 場所 |
|---|---|
| クリップ/トリム/速度/分割のデータ | `Models/Models.swift` |
| コンポジション構築・向き補正 | `Engine/CompositionEngine.swift` |
| 再生・seek | `Engine/PlayerController.swift` |
| 書き出し・透かし・テキスト焼き込み | `Engine/ExportManager.swift` |
| 編集操作・undo・読み込み・前後カット | `Engine/EditorViewModel.swift` |
| モード切替(かんたん⇔しっかり) | `ShortLabApp.swift`(RootView。既定はかんたんモード) |
| かんたんモード3画面・写真保存 | `Views/SimpleMode.swift` |
| しっかり編集の画面 | `Views/`(EditorView がルート) |
| プロジェクト保存・復元・素材掃除 | `Engine/ProjectStore.swift` |
| 課金(購入・復元・購入状態) | `Engine/PurchaseManager.swift` |
| 購入シート(マークなしにする) | `Views/PaywallSheet.swift` |
| 広告バナーの掲載口 | `Views/AdBannerView.swift`(掲載してよいのは保存完了画面のみ) |
| ストア関連ID(IAP製品ID/AdMob) | `Config/Store.xcconfig`(実IDは `Store.local.xcconfig`・コミット禁止) |
| 文字色 | `Models/Models.swift` の `TextPalette`(プレビューと書き出しは必ず同じパレットを参照) |
| BGM音量 | `CompositionEngine` の audioMix(AVPlayerItem と ExportSession の**両方**に渡す。片方だけだとプレビューと書き出しで音量が変わる) |
| できた動画のプレビュー | `Views/Sheets.swift` の `VideoPreviewSheet`(両モード共用) |
| クリップのサムネイル | `Views/ClipThumbnail.swift`(NSCache・トリム開始0.1秒単位でキー化) |
| 動画音ミュート/BGM音量3択 | `Models`(videoAudioMuted / BGMVolume)+ `CompositionEngine` の audioMix に集約 |
| App Store 掲載文 | `store-listing.md` |
| エラーの平易化 | `Engine/FriendlyError.swift`(生の localizedDescription を利用者に見せない) |
| 触覚フィードバック | `Views/Haptics.swift`(変化が無いときは鳴らさないルール) |
| 書き出し画質 | `ExportManager.export(preset:)`(2択UIはしっかり編集のみ。かんたんモードは1080p固定) |
| アイコン | `ShortLab/Assets.xcassets/AppIcon.appiconset`(1024px 単一) |
| 法的ページ | `privacy.html` / `terms.html`(GitHub Pages 配信) |

## 判断ツリー(迷ったら)

1. **プレビューと書き出しの見た目が違う** → 原因は座標系。オーバーレイは正規化座標(0-1)が唯一の真実。プレビュー(SwiftUI, 左上原点)と CATextLayer(左下原点)の変換ミスを疑う。`ExportManager.textLayer` の y 反転を確認。
2. **音がズレる** → timescale 混在(最優先ルール違反)か、`scaleTimeRange` を video/audio 片方にしか掛けていないか。**特定のクリップだけ無音になる** → 音声トラックが映像より短い素材。CompositionEngine は音声の実在範囲との交差だけを挿入する仕様(全体を throw で失敗させないため)。
3. **書き出しが無言で失敗する** → `AVAssetExportSession` がローカル変数で解放されていないか、`outputURL` の既存ファイル衝突か。
4. **縦横がおかしい/映像が回転する** → `preferredTransform` 未解決。`aspectFitTransform` を通っているか確認。naturalSize を直接使うコードは全部バグ。
5. **seek がカクつく** → `player.seek` を直接呼んでいる箇所がないか。必ず `PlayerController.seek(to:)`(コアレス実装)経由。
6. **新機能を足したくなった** → MVP機能5つ(取り込み/カット結合/テキスト/BGM/書き出し)の外なら実装せず提案に留める。
7. **かんたんモードの文言を書く** → カタカナ専門語禁止(トリム→切る、書き出し→ほぞん、BGM→音楽)。ボタンは高さ60pt以上・必ずテキストラベル付き。機能は「前後カット・文字3位置・音楽択一・保存/共有」から増やさない(増やしたくなったらしっかり編集へ誘導する設計を提案)。
8. **PlayerController/ExportManager の @Published が画面に反映されない** → ネストした ObservableObject は親経由では再描画されない。その値を使うビューで直接 `@ObservedObject` として受け取る(`PlaybackBar` / `SimpleAdjustStep` / `SimpleSaveStep` 参照)。
9. **購入ボタンが「準備中」のまま** → xcconfig 未設定。`Store.local.xcconfig` に `SHORTLAB_PREMIUM_PRODUCT_ID` があるか、`PurchaseManager.isConfigured` を確認。購入が反映されない場合は `Transaction.currentEntitlements`(refreshEntitlements)側を疑う。
10. **復元したプロジェクトの動画が消えている** → `ProjectStore` は絶対パスを保存しない設計(Documents のパスは再インストールで変わる)。ファイル名以外を保存するコードを書いたら差し戻す。素材が見つからないクリップは復元時に黙って除外される仕様。

## タスク処理ルール

- **テストループ**: 成功基準に対して最大5イテレーション。3回失敗したら停止し、根本原因分析を報告してから続行判断を仰ぐ。ループ中は関連テストのみ、完了時に全テスト1回。失敗ログは要約で扱う。
- **完了報告**: 実行したコマンドとテスト結果の証跡を示してから完了と言う。推測での「動くはず」は禁止。前提とトレードオフは明示する。
- **実装後**: 簡素化レビューを1回実施(過剰抽象・デッドコード・不要依存の除去)。
- **実機依存の検証**(書き出し品質・メモリ・実素材での音ズレ)はシミュレータで代替せず、実機確認が必要な項目として明示的にリストアップして報告する。

## 成功基準(MVP受け入れ条件)

1. フォトライブラリから動画を2本以上取り込み、タイムラインに表示される
2. クリップの削除・並べ替え(コンテキストメニュー)・トリム・分割が動作し、undo で戻せる
3. テキストを追加してドラッグ移動でき、**書き出した動画の同じ相対位置に焼き込まれている**(±5%以内)
4. 速度変更(0.5/1.5/2.0x)で映像と音声が同期したまま変速される
5. BGM を追加すると書き出しに含まれ、動画長で正しく切れる
6. 1080p mp4 が書き出され、無料版フラグで透かしが右下に入る
7. 60秒素材×5クリップの書き出しでクラッシュしない(メモリ確認)
8. かんたんモードで「えらぶ→ととのえる→ほぞん」が説明なしで完了できる: 複数本選択→前後カット(もとにもどす含む)→文字(上・まんなか・下)→音楽→動画を作る→写真に保存→LINE共有
9. かんたんモード⇔しっかり編集を切り替えても、クリップ・文字・音楽が引きつがれる

## 機密・境界

- AdMob アプリID・IAP 製品IDはコードに直書きせず xcconfig で管理(リポジトリにコミットしない)
- BGM 素材はライセンス(商用可・クレジット表記条件)を確認したもののみバンドルする

## 実装済み(旧・MVP外)

- StoreKit 2 買い切りIAP(透かし解除+広告非表示、¥600想定) — `PurchaseManager` + `PaywallSheet`。製品IDは xcconfig 注入
- プロジェクト保存 — `ProjectStore`(project.json、クリップはファイル名参照、起動時復元+孤児ファイル掃除)
- AdMob の掲載口 — `AdBannerView`(canImport ガード。パッケージ未追加でもビルド可。掲載は保存完了画面のみ)

## 未実装(残り)

- スタンプ機能(自作素材が揃ってから)
- BGM 同梱素材(ライセンス確認済み mp3 を Resources/BGM/ へ)
- AdMob の実配信(GoogleMobileAds パッケージ追加+実ID設定+実機確認。コード側は配線済み)
- 実機での受け入れ検証(書き出し・購入・復元・プロジェクト復元はシミュレータ代替不可)
- 横動画対応(9:16 固定をやめる案。RenderSpec が全域に効いているため、実機検証とセットでやること)
- かんたんモードへの文字サイズ選択は**判断ツリー7のルールにより見送り**(機能を増やさない)
