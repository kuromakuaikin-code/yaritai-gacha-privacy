import Foundation
import AVFoundation
import SwiftUI
import UIKit

/// タイムライン上の1クリップ。
/// - `url`: アプリ管理ディレクトリにコピー済みのローカルファイル
/// - `trimStart`/`trimEnd`: 元素材内のトリム範囲(秒)
/// - `speed`: 再生速度(0.5 / 1.0 / 1.5 / 2.0)
struct VideoClip: Identifiable, Equatable {
    let id: UUID
    var url: URL
    var assetDuration: Double   // 元素材の長さ(秒)
    var trimStart: Double
    var trimEnd: Double
    var speed: Double

    init(id: UUID = UUID(), url: URL, assetDuration: Double) {
        self.id = id
        self.url = url
        self.assetDuration = assetDuration
        self.trimStart = 0
        self.trimEnd = assetDuration
        self.speed = 1.0
    }

    /// タイムライン上で占める長さ(速度適用後、秒)
    var timelineDuration: Double {
        max(0, (trimEnd - trimStart) / speed)
    }
}

/// プレビュー上のテキストオーバーレイ。
/// 位置は 0.0-1.0 の正規化座標で保持し、プレビューと書き出しで同じ値を使う。
/// これにより「プレビューと書き出しで位置がズレる」典型バグを構造的に防ぐ。
struct TextOverlayItem: Identifiable, Equatable {
    let id: UUID
    var text: String
    var relativePosition: CGPoint   // (0,0)=左上, (1,1)=右下
    var fontSize: CGFloat           // 1080x1920 基準のポイントサイズ
    var colorName: String           // TextPalette のキー

    init(id: UUID = UUID(), text: String,
         relativePosition: CGPoint = CGPoint(x: 0.5, y: 0.4),
         fontSize: CGFloat = 72,
         colorName: String = TextPalette.defaultName) {
        self.id = id
        self.text = text
        self.relativePosition = relativePosition
        self.fontSize = fontSize
        self.colorName = colorName
    }
}

/// 文字色のパレット。プレビュー(SwiftUI)と書き出し(CATextLayer)で
/// 必ずここの同じ値を参照する(独自に色を作るとプレビューと書き出しがズレる)。
/// 背景帯は文字色に合わせて自動で反転する(黒文字だけ白帯)。
enum TextPalette {
    static let defaultName = "white"

    /// (キー, 表示名, 文字色) の順。UIはこの順で並べる
    static let entries: [(name: String, label: String, color: UIColor)] = [
        ("white", "しろ", .white),
        ("yellow", "きいろ", UIColor(red: 1.00, green: 0.84, blue: 0.04, alpha: 1)),
        ("pink", "ピンク", UIColor(red: 1.00, green: 0.42, blue: 0.62, alpha: 1)),
        ("blue", "みずいろ", UIColor(red: 0.35, green: 0.78, blue: 0.94, alpha: 1)),
        ("black", "くろ", UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1))
    ]

    static func uiColor(_ name: String) -> UIColor {
        entries.first { $0.name == name }?.color ?? .white
    }

    static func color(_ name: String) -> Color {
        Color(uiColor: uiColor(name))
    }

    /// 文字の後ろの帯。黒文字のときだけ白帯にして読めるようにする
    static func backgroundUIColor(_ name: String) -> UIColor {
        name == "black"
            ? UIColor.white.withAlphaComponent(0.75)
            : UIColor.black.withAlphaComponent(0.55)
    }

    static func backgroundColor(_ name: String) -> Color {
        Color(uiColor: backgroundUIColor(name))
    }
}

/// BGMトラック(MVPではバンドル内フリー素材から選択)
struct MusicTrack: Identifiable, Equatable {
    let id: UUID
    var name: String
    var url: URL
    var volume: Float

    init(id: UUID = UUID(), name: String, url: URL, volume: Float = 0.6) {
        self.id = id
        self.name = name
        self.url = url
        self.volume = volume
    }
}

/// BGM音量の3択(かんたん・しっかり共通)
enum BGMVolume {
    static let options: [(label: String, value: Float)] = [
        ("ちいさめ", 0.35),
        ("ふつう", 0.6),
        ("おおきめ", 1.0)
    ]
}

/// 編集プロジェクト全体の状態
struct EditorProject: Equatable {
    var clips: [VideoClip] = []
    var textOverlays: [TextOverlayItem] = []
    var music: MusicTrack?
    /// 動画のもとの音を消す(音楽だけにする)。風の音がうるさい等の定番ニーズ
    var videoAudioMuted: Bool = false

    var totalDuration: Double {
        clips.reduce(0) { $0 + $1.timelineDuration }
    }
}

enum RenderSpec {
    /// 全コンポジション共通のタイムスケール。
    /// 混在させると音ズレの温床になるため、時間値は必ずこの値で作る。
    static let timescale: CMTimeScale = 600
    /// 9:16 縦動画固定
    static let renderSize = CGSize(width: 1080, height: 1920)

    static func time(_ seconds: Double) -> CMTime {
        CMTime(seconds: seconds, preferredTimescale: timescale)
    }
}
