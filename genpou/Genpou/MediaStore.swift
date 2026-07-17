import Foundation
import UIKit

/// 写真・ロゴのディスク保存を一手に引き受ける。
/// ルート: Application Support/Genpou/photos/{projectId}/
enum MediaStore {
    static let maxOriginalSide: CGFloat = 2048
    static let maxThumbSide: CGFloat = 400
    private static let jpegQuality: CGFloat = 0.85

    // MARK: - パス

    static var rootURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Genpou", isDirectory: true)
    }

    static func photosDir(projectId: UUID) -> URL {
        rootURL.appendingPathComponent("photos", isDirectory: true)
            .appendingPathComponent(projectId.uuidString, isDirectory: true)
    }

    static var logoDir: URL {
        rootURL.appendingPathComponent("logo", isDirectory: true)
    }

    static var reportsDir: URL {
        rootURL.appendingPathComponent("reports", isDirectory: true)
    }

    static func photoURL(fileName: String, projectId: UUID) -> URL {
        photosDir(projectId: projectId).appendingPathComponent(fileName)
    }

    static func logoURL(fileName: String) -> URL {
        logoDir.appendingPathComponent(fileName)
    }

    // MARK: - 保存

    /// 原画（長辺 2048px）とサムネ（長辺 400px）を JPEG で保存し、ファイル名を返す。
    static func savePhoto(_ image: UIImage, projectId: UUID) throws -> (fileName: String, thumbFileName: String) {
        let dir = photosDir(projectId: projectId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let baseName = UUID().uuidString
        let fileName = "\(baseName).jpg"
        let thumbFileName = "\(baseName)_thumb.jpg"

        let original = resized(image, maxSide: maxOriginalSide)
        let thumb = resized(image, maxSide: maxThumbSide)

        guard let originalData = original.jpegData(compressionQuality: jpegQuality),
              let thumbData = thumb.jpegData(compressionQuality: jpegQuality) else {
            throw MediaStoreError.encodeFailed
        }
        try originalData.write(to: dir.appendingPathComponent(fileName), options: .atomic)
        try thumbData.write(to: dir.appendingPathComponent(thumbFileName), options: .atomic)
        return (fileName, thumbFileName)
    }

    /// 会社ロゴを保存してファイル名を返す（既存ロゴは削除）。
    static func saveLogo(_ image: UIImage, replacing oldFileName: String?) throws -> String {
        try FileManager.default.createDirectory(at: logoDir, withIntermediateDirectories: true)
        if let oldFileName {
            try? FileManager.default.removeItem(at: logoURL(fileName: oldFileName))
        }
        let fileName = "\(UUID().uuidString).jpg"
        let resizedLogo = resized(image, maxSide: 600)
        guard let data = resizedLogo.jpegData(compressionQuality: jpegQuality) else {
            throw MediaStoreError.encodeFailed
        }
        try data.write(to: logoURL(fileName: fileName), options: .atomic)
        return fileName
    }

    // MARK: - 読み込み

    static func loadPhoto(_ photo: SitePhoto) -> UIImage? {
        guard let projectId = photo.project?.id else { return nil }
        return UIImage(contentsOfFile: photoURL(fileName: photo.fileName, projectId: projectId).path)
    }

    static func loadThumb(_ photo: SitePhoto) -> UIImage? {
        guard let projectId = photo.project?.id else { return nil }
        if let thumbName = photo.thumbFileName,
           let image = UIImage(contentsOfFile: photoURL(fileName: thumbName, projectId: projectId).path) {
            return image
        }
        return loadPhoto(photo)
    }

    static func loadLogo(fileName: String?) -> UIImage? {
        guard let fileName else { return nil }
        return UIImage(contentsOfFile: logoURL(fileName: fileName).path)
    }

    // MARK: - 削除

    /// 写真 1 枚分のファイルを削除（モデル側の削除は呼び出し元で行う）。
    static func deleteFiles(of photo: SitePhoto) {
        guard let projectId = photo.project?.id else { return }
        try? FileManager.default.removeItem(at: photoURL(fileName: photo.fileName, projectId: projectId))
        if let thumbName = photo.thumbFileName {
            try? FileManager.default.removeItem(at: photoURL(fileName: thumbName, projectId: projectId))
        }
    }

    /// 案件フォルダごと削除。
    static func deletePhotosDir(projectId: UUID) {
        try? FileManager.default.removeItem(at: photosDir(projectId: projectId))
    }

    // MARK: - リサイズ

    /// 長辺が maxSide を超える場合に縮小。EXIF の向きも正規化される。
    static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longSide = max(size.width, size.height)
        let scale = longSide > maxSide ? maxSide / longSide : 1
        let newSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

enum MediaStoreError: Error {
    case encodeFailed
}
