import Foundation
import SwiftData

// MARK: - バックアップ用JSON構造

struct BackupRule: Codable {
    var categoryName: String
    var colorHex: String
    var weekdays: [Int]
    var frequency: String
    var note: String
}

struct BackupFile: Codable {
    var app = "GomiCalendar"
    var version = 1
    var exportedAt: String
    var rules: [BackupRule]
}

enum BackupService {
    static func export(rules: [GarbageRule]) -> Data? {
        let backup = BackupFile(
            exportedAt: ISODay.string(Date()),
            rules: rules.map {
                BackupRule(
                    categoryName: $0.categoryName,
                    colorHex: $0.colorHex,
                    weekdays: $0.weekdays,
                    frequency: $0.frequencyRaw,
                    note: $0.note
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
        for item in backup.rules {
            let rule = GarbageRule()
            rule.categoryName = item.categoryName
            rule.colorHex = item.colorHex
            rule.weekdays = item.weekdays
            rule.frequencyRaw = item.frequency
            rule.note = item.note
            context.insert(rule)
        }
        return backup.rules.count
    }
}
