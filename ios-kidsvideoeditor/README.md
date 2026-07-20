# きっず動画編集（KidsVideoEditor）iOS版（SwiftUI）

子ども（保護者が近くで見守ることを前提）が、写真アプリの動画クリップを選んで並べ替え・トリミングし、大きく読みやすいテキストキャプションと絵文字スタンプ、BGMを加えて1本の動画にまとめ、写真アプリに保存できるアプリ。iOS 17+ / SwiftUI（SwiftDataなどの永続化は不使用・プロジェクトはその場限りのメモリ内データ）。

このアプリは **Kids カテゴリ**（子ども向けアプリ）としての申請を想定しています。通常アプリより審査・実装の要件が多いため、本READMEの「Kidsカテゴリ チェックリスト」を必ず確認してください。

## 機能

- 動画選択（`PhotosPicker`、`.videos`フィルタ、1〜複数本）
- クリップの並べ替え（◀▶ボタン。ドラッグ操作は使わず、誤操作しにくいシンプルなボタン式）・削除・サムネイル表示（`AVAssetImageGenerator`）
- トリミング（`AVPlayer`プレビュー + 開始/終了の2つの`Slider`）
- テキストキャプション（30文字まで、6種類の色/フォントの組み合わせから選択、上/中/下の3配置）
- 絵文字スタンプ（20種類から選択、5つのプリセット位置に配置）
- BGM（開発者が用意する著作権フリー音源から選ぶのみ。個人のミュージックライブラリからの選曲は著作権リスクを避けるため不可。音量スライダーとON/OFF）
- 動画の合成・書き出し（`AVMutableComposition` + `AVMutableVideoComposition` + `AVVideoCompositionCoreAnimationTool`によるテキスト/スタンプ/すかしの焼き込み、`AVAssetExportSession`で書き出し、進捗バー表示、`PHPhotoLibrary`で写真アプリに保存）
- 無料版はすかし付き・プレミアム購入（買い切り・¥360）ですかし解除+クリップ数無制限（合計5分まで）+全スタイル/全スタンプ解放
- 保護者ゲート（簡単な計算問題）：プレミアム購入・外部リンク（プライバシーポリシー/利用規約）・共有シートの前に必ず表示
- パスコードロックやバックアップ機能は実装していません（本アプリは記録として保存する個人情報を持たないため、意図的に省略しています）

## ⚠️ 音源ファイルを追加してください（リリース前に必須）

本アプリのBGM機能は、以下のファイル名を参照するコードのみが実装されており、**実際の音声ファイルはこのリポジトリに含まれていません**。開発者がリリース前に、著作権フリー（ロイヤリティフリー、商用利用・改変可・帰属表示不要または表示対応可能なライセンス）の音源を用意し、以下の正確なファイル名で Xcode プロジェクトのバンドルリソースとして追加してください（`ios-kidsvideoeditor/KidsVideoEditor/` 配下、またはXcodeのAssetsではなく通常のバンドルリソースとして追加し、ターゲットメンバーシップを有効にすること）。

- `bgm_happy1.m4a`（たのしい 1）
- `bgm_happy2.m4a`（たのしい 2）
- `bgm_calm1.m4a`（しずか 1）

ファイル名・拡張子は `ios-kidsvideoeditor/KidsVideoEditor/Models.swift` の `BGMTrack.all` と完全に一致させる必要があります（変更する場合はコード側も合わせて変更してください）。音源が見つからない場合、プレビュー再生は失敗し（開発者向けメッセージを表示）、書き出し時もBGMなしで処理が続行されます（アプリがクラッシュしない設計にはなっていますが、リリース前に必ず実音源で動作確認してください）。

## セットアップ

### 方法A: XcodeGen（推奨）

```bash
brew install xcodegen
cd ios-kidsvideoeditor
xcodegen
open KidsVideoEditor.xcodeproj
```

### 方法B: 手動

1. Xcode → File → New → Project → iOS App
   - Product Name: `KidsVideoEditor`（表示名は後で「きっず動画編集」に）
   - Interface: SwiftUI / Storage: **None**
   - Minimum Deployment: iOS 17.0
2. 自動生成された `ContentView.swift` と `〜App.swift` を削除
3. `ios-kidsvideoeditor/KidsVideoEditor/` の `.swift` 全ファイルをプロジェクトにドラッグ（Copy items if needed）
4. Info.plist（または Build Settings の `INFOPLIST_KEY_*`）に以下を追加
   - `NSPhotoLibraryUsageDescription`: 「動画を選んで編集するために使用します」
   - `NSPhotoLibraryAddUsageDescription`: 「作成した動画を保存するために使用します」
5. BGM音源ファイル（上記「⚠️ 音源ファイルを追加してください」参照）をバンドルに追加
6. ビルド（⌘R）

アプリアイコンは未作成です。Assets の AppIcon に 1024×1024 のアイコン画像を用意して設定してください。

## リリース前チェックリスト

1. `Store.swift` の `AppConfig.freeTrial` を `false` に
2. App Store Connect で非消耗型IAPを1つ作成
   - プレミアム（`com.kuromakuaikin.kidsvideoeditor.premium` / ¥360）＋「購入の復元」動作確認
3. BGM音源ファイルを正しいファイル名で追加（上記セクション参照）し、プレビュー再生・書き出し後の動画に実際にBGMが乗ることを確認
4. プライバシーポリシーURL: `https://kuromakuaikin-code.github.io/yaritai-gacha-privacy/kids-video-editor/privacy.html`
5. プライバシー「栄養表示」（App Privacy）：ユーザーデータ収集なしとして申告（広告SDKを組み込む場合はそのSDKの申告内容に従う）
6. アプリアイコン（1024×1024）を用意して Assets に設定

## Kidsカテゴリ 対応チェックリスト（App Store 審査用）

Kids カテゴリのアプリは通常アプリより審査基準が厳しく、以下を必ず確認してください。

- [x] 保護者ゲート：`ParentalGateView.swift` に実装済み。プレミアム購入・外部リンク・共有シートの前に表示されることを実機で確認すること
- [x] 行動ターゲティング広告なし：`AppConfig.adsEnabled = false`（既定オフ）。広告を有効化する場合は `AdBannerView.swift` のコード内コメントに従い、AdMobの「児童向けタグ設定」(TFCD) を有効化し、非パーソナライズ配信のみとすること
- [x] ATT（App Tracking Transparency）のトラッキング許可ダイアログを一切表示しないこと（Kidsカテゴリでは禁止）。`NSUserTrackingUsageDescription` は追加しないこと
- [ ] 将来的に広告SDKやサードパーティSDK（分析ツール等）を追加する場合、それぞれが子ども向けアプリ規制（COPPA等）に準拠していることを個別に確認すること
- [ ] プライバシーポリシーURLをApp Store Connectに設定（上記参照）
- [ ] Info.plist の写真ライブラリ利用目的説明文（`NSPhotoLibraryUsageDescription` / `NSPhotoLibraryAddUsageDescription`）が設定されていることを確認（`project.yml` に設定済み）
- [ ] アプリアイコンをKidsカテゴリの審査ガイドラインに沿って用意（暴力的・不適切な表現がないこと）
- [ ] 実機での動作確認（下記「重要な注意」参照。特にエクスポート機能は必須）

## 重要な注意

- このコードはLinux環境で作成したため **Xcodeでのビルド未確認** です。ビルドエラーが出た場合はエラーメッセージを共有してください（すぐ修正します）。
- **とりわけ `ExportView.swift` のAVFoundation合成・書き出しパイプライン（`AVMutableComposition` / `AVMutableVideoComposition` / `AVVideoCompositionCoreAnimationTool` によるテキスト・スタンプ・すかしの焼き込み、BGMミックス、`AVAssetExportSession`での書き出し）は、Mac・実機・シミュレータでの動作確認が一度もできていません。** 特に以下は想定と異なる挙動になりやすいため、実際の動画クリップ（特に縦向き・横向き両方、複数クリップの組み合わせ）でリリース前に十分にテストしてください。
  - 縦動画（ポートレート）撮影時の回転メタデータの処理（`preferredTransform`）
  - 複数クリップの解像度・向きが異なる場合のレンダリングサイズの扱い（現状は先頭クリップの向き・サイズを基準にしている簡略実装）
  - テキストキャプション・スタンプ・すかしの座標変換（`CATextLayer`の配置がプレビューと書き出し結果で一致するか）
  - BGMのループ挿入と音量ミックス（`AVMutableAudioMixInputParameters` / `setVolumeRamp`）
  - 書き出し進捗（`AVAssetExportSession.progress`のポーリング）が実機で滑らかに更新されるか
  - `PHPhotoLibrary`への保存が権限ダイアログを含めて正しく動作するか
