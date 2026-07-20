import Foundation
import SwiftData

// MARK: - バックアップ用JSON構造

struct BackupRecord: Codable {
    var placeName: String
    var placeType: String
    var prefecture: String
    var visitDate: String
    var fee: Int
    var wishType: String
    var rating: Int
    var memo: String
}

struct BackupFile: Codable {
    var app = "GoshuinLog"
    var version = 1
    var exportedAt: String
    var records: [BackupRecord]
}

enum BackupService {
    static func export(entries: [GoshuinEntry]) -> Data? {
        let backup = BackupFile(
            exportedAt: ISODay.string(Date()),
            records: entries.map {
                BackupRecord(
                    placeName: $0.placeName,
                    placeType: $0.placeTypeRaw,
                    prefecture: $0.prefecture,
                    visitDate: ISODay.string($0.visitDate),
                    fee: $0.fee,
                    wishType: $0.wishTypeRaw,
                    rating: $0.rating,
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
        for item in backup.records {
            let entry = GoshuinEntry()
            entry.placeName = item.placeName
            entry.placeTypeRaw = item.placeType
            entry.prefecture = item.prefecture
            entry.visitDate = ISODay.date(item.visitDate) ?? Date()
            entry.fee = item.fee
            entry.wishTypeRaw = item.wishType
            entry.rating = item.rating
            entry.memo = item.memo
            context.insert(entry)
        }
        return backup.records.count
    }
}
