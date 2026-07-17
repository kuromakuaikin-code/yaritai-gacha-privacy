import Foundation
import SwiftData

// MARK: - 会社情報（アプリ内 1 件のみ）

@Model
final class CompanyProfile {
    var companyName: String = ""
    var representative: String?
    var phone: String?
    var address: String?
    var logoFileName: String?

    init(companyName: String = "",
         representative: String? = nil,
         phone: String? = nil,
         address: String? = nil,
         logoFileName: String? = nil) {
        self.companyName = companyName
        self.representative = representative
        self.phone = phone
        self.address = address
        self.logoFileName = logoFileName
    }
}

// MARK: - 案件

@Model
final class Project {
    var id: UUID = UUID()
    var name: String = ""
    var siteAddress: String?
    var clientName: String?
    var startDate: Date?
    var endDate: Date?
    var note: String?
    var statusRaw: String = ProjectStatus.inProgress.rawValue
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \SitePhoto.project)
    var photos: [SitePhoto] = []

    init(name: String = "") {
        self.name = name
    }

    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .inProgress }
        set { statusRaw = newValue.rawValue }
    }

    /// 一覧表示用の「更新日」: 最後に追加された写真の日時、なければ作成日
    var lastActivityAt: Date {
        photos.map(\.createdAt).max() ?? createdAt
    }
}

enum ProjectStatus: String, CaseIterable, Identifiable {
    case inProgress = "in_progress"
    case completed
    var id: String { rawValue }
    var labelJP: String {
        switch self {
        case .inProgress: return "進行中"
        case .completed: return "完了"
        }
    }
}

// MARK: - 現場写真

@Model
final class SitePhoto {
    var id: UUID = UUID()
    var fileName: String = ""
    var thumbFileName: String?
    var takenAt: Date = Date()
    var tagRaw: String = PhotoTag.during.rawValue
    var caption: String?
    var createdAt: Date = Date()
    var project: Project?

    init(fileName: String, thumbFileName: String?, takenAt: Date = Date(), tag: PhotoTag = .during) {
        self.fileName = fileName
        self.thumbFileName = thumbFileName
        self.takenAt = takenAt
        self.tagRaw = tag.rawValue
    }

    var tag: PhotoTag {
        get { PhotoTag(rawValue: tagRaw) ?? .other }
        set { tagRaw = newValue.rawValue }
    }
}

enum PhotoTag: String, CaseIterable, Identifiable {
    case before, during, after, other
    var id: String { rawValue }
    var labelJP: String {
        switch self {
        case .before: return "施工前"
        case .during: return "施工中"
        case .after: return "施工後"
        case .other: return "その他"
        }
    }
}
