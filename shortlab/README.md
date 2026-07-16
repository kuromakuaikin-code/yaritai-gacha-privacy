# ShortLab — かんたん動画編集(iOS)

SwiftUI + AVFoundation の縦動画(9:16)編集アプリ MVP。
実装済み: 動画取り込み / カット・結合 / トリム / 分割 / 速度変更 / テキストオーバーレイ(焼き込み) / BGM / 1080p書き出し(透かし対応) / undo

## セットアップ(Mac側)

1. Xcode で新規プロジェクト作成: iOS App / SwiftUI / プロダクト名 `ShortLab` / iOS 17.0+
2. 自動生成された `ContentView.swift` と `ShortLabApp.swift` を削除し、この `ShortLab/` 以下の .swift を全てプロジェクトに追加
3. Info.plist に追加:
   - `NSPhotoLibraryUsageDescription` = 「編集する動画を選ぶために使用します」
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
    ├── ShortLabApp.swift
    ├── Models/Models.swift       # VideoClip / TextOverlayItem / RenderSpec
    ├── Engine/
    │   ├── CompositionEngine.swift   # AVMutableComposition 構築(向き補正込み)
    │   ├── PlayerController.swift    # コアレスseek実装のプレビュー再生
    │   ├── ExportManager.swift       # 書き出し+透かし/テキスト焼き込み
    │   └── EditorViewModel.swift     # 編集操作・undo・PhotosPicker取り込み
    └── Views/
        ├── EditorView.swift          # ルート画面
        ├── PreviewView.swift         # AVPlayerLayer + ドラッグ可能テキスト
        ├── TimelineView.swift        # クリップ帯(選択/移動/削除)
        ├── ToolsGridView.swift       # ツールグリッド
        └── Sheets.swift              # テキスト/速度/トリム/音楽/書き出しシート
```

## 設計上の要点

- **timescale 600 固定**(`RenderSpec.time()`)。音ズレ防止の生命線
- **オーバーレイは正規化座標**でプレビューと書き出しが同じ値を共有(位置ズレ防止)
- **preferredTransform 解決**済みのアスペクトフィット(iPhone縦撮り素材の回転バグ対策)
- **seek はコアレス方式**(スクラブ連打でも詰まらない)
- **ExportSession はプロパティ保持**(途中解放による silent fail 防止)

## 未実装(意図的)

AdMob / StoreKit(買い切り¥600) / スタンプ / プロジェクト永続化 — CLAUDE.md「未実装」参照
