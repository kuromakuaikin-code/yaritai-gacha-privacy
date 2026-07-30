import Foundation
import CoreGraphics

/// プロジェクトの保存・復元(アプリを閉じても編集の続きができる)。
/// - 保存先: Documents/project.json
/// - クリップは Documents/clips/ 内のファイル名だけを記録する。
///   Documents の絶対パスはアプリ更新・再インストールで変わるため、保存してはいけない。
/// - BGM はバンドル素材のファイル名で記録し、復元時に BGMLibrary から引き直す
///   (バンドルのパスもビルドごとに変わるため)。
enum ProjectStore {

    static var clipsDirectory: URL {
        URL.documentsDirectory.appendingPathComponent("clips", isDirectory: true)
    }

    private static var fileURL: URL {
        URL.documentsDirectory.appendingPathComponent("project.json")
    }

    /// 保存形式。runtime モデルと分離しておくことで、
    /// モデル側の変更が保存済みデータの互換を壊さないようにする。
    private struct Stored: Codable {
        struct Clip: Codable {
            var id: UUID
            var fileName: String
            var assetDuration: Double
            var trimStart: Double
            var trimEnd: Double
            var speed: Double
        }
        struct Text: Codable {
            var id: UUID
            var text: String
            var x: Double
            var y: Double
            var fontSize: Double
            // 後から追加したフィールド。旧データには無いため Optional で受ける
            var colorName: String?
        }
        struct Music: Codable {
            var fileName: String
            var volume: Float
        }
        var version = 1
        var clips: [Clip] = []
        var texts: [Text] = []
        var music: Music?
        // 後から追加したフィールド。旧データには無いため Optional で受ける
        var videoAudioMuted: Bool?
    }

    static func save(_ project: EditorProject) {
        var stored = Stored()
        stored.clips = project.clips.map {
            Stored.Clip(id: $0.id, fileName: $0.url.lastPathComponent,
                        assetDuration: $0.assetDuration,
                        trimStart: $0.trimStart, trimEnd: $0.trimEnd, speed: $0.speed)
        }
        stored.texts = project.textOverlays.map {
            Stored.Text(id: $0.id, text: $0.text,
                        x: $0.relativePosition.x, y: $0.relativePosition.y,
                        fontSize: Double($0.fontSize),
                        colorName: $0.colorName)
        }
        stored.music = project.music.map {
            Stored.Music(fileName: $0.url.lastPathComponent, volume: $0.volume)
        }
        stored.videoAudioMuted = project.videoAudioMuted
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 復元。素材ファイルが消えているクリップは黙って除外し、全滅なら nil。
    static func load() -> EditorProject? {
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode(Stored.self, from: data)
        else { return nil }

        var project = EditorProject()
        for c in stored.clips {
            let url = clipsDirectory.appendingPathComponent(c.fileName)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            var clip = VideoClip(id: c.id, url: url, assetDuration: c.assetDuration)
            clip.trimStart = max(0, min(c.trimStart, c.assetDuration))
            clip.trimEnd = max(clip.trimStart + 0.1, min(c.trimEnd, c.assetDuration))
            clip.speed = c.speed
            project.clips.append(clip)
        }
        guard !project.clips.isEmpty else { return nil }

        project.textOverlays = stored.texts.map {
            TextOverlayItem(id: $0.id, text: $0.text,
                            relativePosition: CGPoint(x: $0.x, y: $0.y),
                            fontSize: CGFloat($0.fontSize),
                            colorName: $0.colorName ?? TextPalette.defaultName)
        }
        if let m = stored.music,
           var track = BGMLibrary.tracks().first(where: { $0.url.lastPathComponent == m.fileName }) {
            track.volume = m.volume
            project.music = track
        }
        project.videoAudioMuted = stored.videoAudioMuted ?? false
        return project
    }

    /// どのクリップからも参照されなくなった clips/ 内のファイルを消す(起動時・やりなおし時の掃除)
    static func cleanupOrphanClips(keeping project: EditorProject) {
        let kept = Set(project.clips.map { $0.url.lastPathComponent })
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: clipsDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files where !kept.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
