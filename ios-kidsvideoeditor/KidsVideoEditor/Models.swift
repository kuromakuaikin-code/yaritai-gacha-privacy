import Foundation
import SwiftUI
import UIKit

// MARK: - クリップ（選択した動画1本ぶん）

struct VideoClip: Identifiable, Equatable {
    let id: UUID
    var assetURL: URL          // 端末内にコピーした動画ファイルのURL
    var duration: Double       // 元動画の総尺（秒）
    var trimStart: Double
    var trimEnd: Double
    var thumbnail: UIImage?

    var trimmedDuration: Double { max(0, trimEnd - trimStart) }

    init(id: UUID = UUID(), assetURL: URL, duration: Double, thumbnail: UIImage? = nil) {
        self.id = id
        self.assetURL = assetURL
        self.duration = duration
        self.trimStart = 0
        self.trimEnd = duration
        self.thumbnail = thumbnail
    }

    static func == (lhs: VideoClip, rhs: VideoClip) -> Bool { lhs.id == rhs.id }
}

// MARK: - テキストキャプション

enum CaptionPosition: String, CaseIterable, Identifiable, Hashable {
    case top, center, bottom
    var id: String { rawValue }
    var label: String {
        switch self {
        case .top: return "うえ"
        case .center: return "まんなか"
        case .bottom: return "した"
        }
    }
}

struct CaptionStyle: Identifiable, Equatable {
    let id: Int
    let name: String
    let color: Color
    let isFree: Bool // 無料版で使えるスタイルかどうか
}

enum CaptionStyleData {
    // 全6種類。先頭2つ（isFree = true）が無料版で使える組み合わせ。
    static let all: [CaptionStyle] = [
        CaptionStyle(id: 0, name: "ポップ", color: .pink, isFree: true),
        CaptionStyle(id: 1, name: "そら", color: .blue, isFree: true),
        CaptionStyle(id: 2, name: "たいよう", color: .orange, isFree: false),
        CaptionStyle(id: 3, name: "みどり", color: .green, isFree: false),
        CaptionStyle(id: 4, name: "むらさき", color: .purple, isFree: false),
        CaptionStyle(id: 5, name: "きんいろ", color: .yellow, isFree: false),
    ]
}

struct ProjectCaption {
    var text: String = ""
    var styleID: Int = 0
    var position: CaptionPosition = .bottom
}

// MARK: - ステッカー（絵文字）

enum StickerPosition: String, CaseIterable, Identifiable, Hashable {
    case topLeft, topRight, center, bottomLeft, bottomRight
    var id: String { rawValue }
    var label: String {
        switch self {
        case .topLeft: return "ひだり うえ"
        case .topRight: return "みぎ うえ"
        case .center: return "まんなか"
        case .bottomLeft: return "ひだり した"
        case .bottomRight: return "みぎ した"
        }
    }
}

enum StickerData {
    // 全20種類。先頭6つが無料版で選べる絵文字。
    static let allEmoji = ["🎉", "🌈", "⭐️", "🦄", "🐶", "🐱", "🎂", "🍦", "🚀", "⚽️",
                            "🎈", "🎵", "❤️", "👍", "😂", "🌟", "🔥", "🎁", "🏆", "🍭"]
    static let freeEmoji = Array(allEmoji.prefix(6))
}

struct PlacedSticker: Identifiable {
    let id = UUID()
    var emoji: String
    var position: StickerPosition
}

// MARK: - BGM

struct BGMTrack: Identifiable, Equatable {
    let id: String        // バンドルに入れるファイル名（拡張子込み）
    let title: String

    // ⚠️ 実際の音源ファイルはこのリポジトリには含まれていません。
    // 開発者が著作権フリー（ロイヤリティフリー）の音源をこのファイル名で
    // Xcodeプロジェクトのバンドルに追加する必要があります。詳細はREADME参照。
    static let all: [BGMTrack] = [
        BGMTrack(id: "bgm_happy1.m4a", title: "たのしい 1"),
        BGMTrack(id: "bgm_happy2.m4a", title: "たのしい 2"),
        BGMTrack(id: "bgm_calm1.m4a", title: "しずか 1"),
    ]
}

struct MusicSettings {
    var enabled: Bool = false
    var trackID: String = BGMTrack.all.first?.id ?? "bgm_happy1.m4a"
    var volume: Double = 0.6
}

// MARK: - 画面遷移ステップ（つくるフロー用）

enum FlowStep: Hashable {
    case clipPicker
    case trim(UUID)
    case caption
    case stickers
    case music
    case export
}

// MARK: - プロジェクト全体（メモリ内のみ。保存・再読込はしない）

@MainActor
final class VideoProject: ObservableObject {
    @Published var clips: [VideoClip] = []
    @Published var caption = ProjectCaption()
    @Published var stickers: [PlacedSticker] = []
    @Published var music = MusicSettings()
    @Published var path = NavigationPath()

    var totalTrimmedDuration: Double {
        clips.reduce(0) { $0 + $1.trimmedDuration }
    }

    func reset() {
        clips = []
        caption = ProjectCaption()
        stickers = []
        music = MusicSettings()
    }
}
