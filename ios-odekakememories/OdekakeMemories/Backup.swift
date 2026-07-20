import Foundation
import SwiftData

// MARK: - バックアップ用JSON構造

struct BackupVisit: Codable {
    var module: String
    var name: String
    var subKind: String
    var visitDate: String
    var rating: Int
    var detailNote: String
    var memo: String
}

struct BackupFile: Codable {
    var app = "OdekakeMemories"
    var version = 1
    var exportedAt: String
    var visits: [BackupVisit]
}

enum BackupService {
    static func export(visits: [OutingVisit]) -> Data? {
        let backup = BackupFile(
            exportedAt: ISODay.string(Date()),
            visits: visits.map {
                BackupVisit(
                    module: $0.moduleRaw,
                    name: $0.name,
                    subKind: $0.subKind,
                    visitDate: ISODay.string($0.visitDate),
                    rating: $0.rating,
                    detailNote: $0.detailNote,
                    memo: $0.memo
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(backup)
    }

    /// インポート件数を返す。失敗時は nil
    @discardableResult
    static func importData(_ data: Data, into context: ModelContext) -> Int? {
        guard let backup = try? JSONDecoder().decode(BackupFile.self, from: data) else { return nil }
        for item in backup.visits {
            let visit = OutingVisit()
            visit.moduleRaw = item.module
            visit.name = item.name
            visit.subKind = item.subKind
            visit.visitDate = ISODay.date(item.visitDate) ?? Date()
            visit.rating = item.rating
            visit.detailNote = item.detailNote
            visit.memo = item.memo
            context.insert(visit)
        }
        return backup.visits.count
    }
}
