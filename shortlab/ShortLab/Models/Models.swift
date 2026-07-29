import Foundation
import AVFoundation
import SwiftUI

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

    init(id: UUID = UUID(), text: String,
         relativePosition: CGPoint = CGPoint(x: 0.5, y: 0.4),
         fontSize: CGFloat = 72) {
        self.id = id
        self.text = text
        self.relativePosition = relativePosition
        self.fontSize = fontSize
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

/// 編集プロジェクト全体の状態
struct EditorProject: Equatable {
    var clips: [VideoClip] = []
    var textOverlays: [TextOverlayItem] = []
    var music: MusicTrack?

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
