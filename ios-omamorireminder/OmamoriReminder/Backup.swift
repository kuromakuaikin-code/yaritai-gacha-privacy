import Foundation
import SwiftData

// MARK: - バックアップ用JSON構造

struct BackupItem: Codable {
    var shrineName: String
    var kind: String
    var purpose: String
    var obtainedDate: String
    var suggestedReturnDate: String
    var isReturned: Bool
    var memo: String
}

struct BackupFile: Codable {
    var app = "OmamoriReminder"
    var version = 1
    var exportedAt: String
    var items: [BackupItem]
}

enum BackupService {
    static func export(items: [OmamoriItem]) -> Data? {
        let backup = BackupFile(
            exportedAt: ISODay.string(Date()),
            items: items.map {
                BackupItem(
                    shrineName: $0.shrineName,
                    kind: $0.kindRaw,
                    purpose: $0.purposeRaw,
                    obtainedDate: ISODay.string($0.obtainedDate),
                    suggestedReturnDate: ISODay.string($0.suggestedReturnDate),
                    isReturned: $0.isReturned,
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
        for entry in backup.items {
            let item = OmamoriItem()
            item.shrineName = entry.shrineName
            item.kindRaw = entry.kind
            item.purposeRaw = entry.purpose
            item.obtainedDate = ISODay.date(entry.obtainedDate) ?? Date()
            item.suggestedReturnDate = ISODay.date(entry.suggestedReturnDate) ?? defaultReturnDate(from: item.obtainedDate)
            item.isReturned = entry.isReturned
            item.memo = entry.memo
            context.insert(item)
        }
        return backup.items.count
    }
}
