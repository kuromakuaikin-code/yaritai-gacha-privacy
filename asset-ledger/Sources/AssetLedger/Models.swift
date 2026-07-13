import Foundation

// MARK: - ファイル種別

enum AssetFileType: String, Codable, CaseIterable, Identifiable {
    case glb
    case usdz
    case image
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .glb: return "GLB"
        case .usdz: return "USDZ"
        case .image: return "画像"
        case .other: return "その他"
        }
    }

    /// 3Dモデルとして扱う種別か
    var is3D: Bool { self == .glb || self == .usdz }

    static func from(url: URL) -> AssetFileType {
        switch url.pathExtension.lowercased() {
        case "glb", "gltf":
            return .glb
        case "usdz", "usd", "usdc", "usda":
            return .usdz
        case "png", "jpg", "jpeg", "webp", "heic", "heif", "tiff", "tif", "gif", "bmp":
            return .image
        default:
            return .other
        }
    }

    /// 台帳に取り込む対象の拡張子か（無関係なファイルは無視する）
    static func isSupported(url: URL) -> Bool {
        from(url: url) != .other
    }
}

// MARK: - 監視フォルダ

struct WatchFolder: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var path: String
    /// セキュリティスコープ付きブックマーク（サンドボックス動作時のみ有効。非サンドボックスではnilでよい）
    var bookmark: Data?
    var isActive: Bool = true

    var name: String { (path as NSString).lastPathComponent }
    var url: URL { URL(fileURLWithPath: path) }
}

// MARK: - 素材

struct Asset: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    /// 元ファイルへの参照（コピー・移動はしない）
    var filePath: String
    var folderID: UUID
    var fileType: AssetFileType
    /// アプリ管理領域(thumbnails/)内のファイル名。未生成ならnil
    var thumbnailFileName: String?
    /// サムネ生成を試みたが失敗した（GLB未対応など）
    var thumbnailFailed: Bool = false
    var fileSize: Int64 = 0
    /// 元ファイルの作成日時
    var createdAt: Date = Date()
    var tags: [String] = []
    var isFavorite: Bool = false
    var note: String?
    /// NEWバッジ管理（false = 未閲覧）
    var isViewed: Bool = false
    /// 元ファイルが見つからない（消失バッジ表示）
    var isMissing: Bool = false

    var fileName: String { (filePath as NSString).lastPathComponent }
    var fileURL: URL { URL(fileURLWithPath: filePath) }

    var thumbnailURL: URL? {
        guard let name = thumbnailFileName else { return nil }
        return LibraryPaths.thumbnailsDir.appendingPathComponent(name)
    }
}

// MARK: - 永続化するデータ全体

struct LibraryData: Codable {
    var folders: [WatchFolder] = []
    var assets: [Asset] = []
    /// サムネ解像度（最大辺px）: 256 or 512
    var thumbnailSize: Int = 256
}

// MARK: - アプリ管理領域のパス

enum LibraryPaths {
    /// ~/Library/Application Support/AssetLedger/
    static let appSupportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("AssetLedger", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let thumbnailsDir: URL = {
        let dir = appSupportDir.appendingPathComponent("thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let libraryFile: URL = appSupportDir.appendingPathComponent("library.json")
}
