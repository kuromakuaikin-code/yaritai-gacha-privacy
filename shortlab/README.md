# ShortLab — かんたん動画編集(iOS)

SwiftUI + AVFoundation の縦動画(9:16)編集アプリ MVP。
実装済み: 動画取り込み / カット・結合 / トリム / 分割 / 速度変更 / テキストオーバーレイ(焼き込み) / BGM / 1080p書き出し(透かし対応) / undo

**既定はかんたんモード**(シニア・非クリエイター向けの3画面一本道: えらぶ → ととのえる → ほぞん)。
右上「しっかり編集」で従来のフル編集画面に切替でき、編集内容は両モードで共有される。
かんたんモードは明るい配色・大ボタン・専門用語なし(トリム→切る、書き出し→ほぞん)で、
「前後を切る / 文字を上・まんなか・下に入れる / 音楽をつける / 写真に保存 / LINEで送る」だけに絞っている。

## セットアップ

### 方法A: XcodeGen(推奨・Info.plist設定込み)

```bash
brew install xcodegen
cd shortlab
xcodegen
open ShortLab.xcodeproj
```

### 方法B: 手動

1. Xcode で新規プロジェクト作成: iOS App / SwiftUI / プロダクト名 `ShortLab` / iOS 17.0+
2. 自動生成された `ContentView.swift` と `ShortLabApp.swift` を削除し、この `ShortLab/` 以下の .swift を全てプロジェクトに追加
3. Info.plist に追加:
   - `NSPhotoLibraryUsageDescription` = 「編集する動画を選ぶために使用します」
   - `NSPhotoLibraryAddUsageDescription` = 「作った動画を写真に保存するために使用します」(かんたんモードの「写真に ほぞんする」で必要)

### Macが手元にない場合

- **ビルド確認**: push のたびに GitHub Actions のMacランナーが署名なしビルドを実行する(`.github/workflows/shortlab-build.yml`)。コンパイルエラーはActionsタブで確認できる
- **実機テスト・提出**: Actions 上で fastlane による署名付きビルド → TestFlight 配信が可能(証明書と App Store Connect API キーを Secrets に登録して組む。Expo の `eas build` に相当する手作り版)。もしくは中古 Mac mini / クラウドMac(月数千円)が現実的
4. (任意)BGM: `Resources/BGM/` に mp3 を追加してターゲットに含める
   - ファイル名: `summer_bgm.mp3`, `lofi_chill.mp3`, `upbeat_pop.mp3`, `acoustic_morning.mp3`
   - フリー素材の商用利用・アプリ同梱条件を必ず確認すること
5. 実機でビルド(書き出し・メモリ検証はシミュレータ不可)

## Claude Code での続行

`CLAUDE.md` に最優先ルール・判断ツリー・受け入れ条件を記載済み。
最初の指示例:

```
CLAUDE.mdの成功基準1〜7を満たすことを確認したい。
まずビルドを通し、コンパイルエラーがあれば修正。
その後、受け入れ条件を上から順に実機で検証できるチェックリストを作って。
```

## 構成

```
ShortLab/
├── CLAUDE.md                     # Claude Code 用ルール・受け入れ条件
├── README.md
└── ShortLab/
    ├── ShortLabApp.swift         # RootView(かんたん⇔しっかりのモード切替、既定はかんたん)
    ├── Models/Models.swift       # VideoClip / TextOverlayItem / RenderSpec
    ├── Engine/
    │   ├── CompositionEngine.swift   # AVMutableComposition 構築(向き補正込み)
    │   ├── PlayerController.swift    # コアレスseek実装のプレビュー再生
    │   ├── ExportManager.swift       # 書き出し+透かし/テキスト焼き込み
    │   └── EditorViewModel.swift     # 編集操作・undo・PhotosPicker取り込み・前後カット
    └── Views/
        ├── SimpleMode.swift          # かんたんモード(えらぶ→ととのえる→ほぞんの3画面)
        ├── EditorView.swift          # しっかり編集のルート画面
        ├── PreviewView.swift         # AVPlayerLayer + ドラッグ可能テキスト
        ├── TimelineView.swift        # クリップ帯(選択/移動/削除)
        ├── ToolsGridView.swift       # ツールグリッド
        └── Sheets.swift              # テキスト/速度/トリム/音楽/書き出しシート・BGMLibrary
```

## 設計上の要点

- **timescale 600 固定**(`RenderSpec.time()`)。音ズレ防止の生命線
- **オーバーレイは正規化座標**でプレビューと書き出しが同じ値を共有(位置ズレ防止)
- **preferredTransform 解決**済みのアスペクトフィット(iPhone縦撮り素材の回転バグ対策)
- **seek はコアレス方式**(スクラブ連打でも詰まらない)
- **ExportSession はプロパティ保持**(途中解放による silent fail 防止)

## 未実装(意図的)

AdMob / StoreKit(買い切り¥600) / スタンプ / プロジェクト永続化 — CLAUDE.md「未実装」参照
