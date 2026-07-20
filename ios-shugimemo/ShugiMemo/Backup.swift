import Foundation
import SwiftData

// MARK: - バックアップ用JSON構造

struct BackupRecord: Codable {
    var eventKind: String
    var relation: String
    var direction: String
    var returnStatus: String
    var personName: String
    var eventTitle: String
    var amount: Int
    var date: String
    var memo: String
}

struct BackupFile: Codable {
    var app = "ShugiMemo"
    var version = 1
    var exportedAt: String
    var records: [BackupRecord]
}

enum BackupService {
    static func export(records: [GiftRecord]) -> Data? {
        let backup = BackupFile(
            exportedAt: ISODay.string(Date()),
            records: records.map {
                BackupRecord(
                    eventKind: $0.eventKindRaw,
                    relation: $0.relationRaw,
                    direction: $0.directionRaw,
                    returnStatus: $0.returnStatusRaw,
                    personName: $0.personName,
                    eventTitle: $0.eventTitle,
                    amount: $0.amount,
                    date: ISODay.string($0.date),
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
            let record = GiftRecord()
            record.eventKindRaw = item.eventKind
            record.relationRaw = item.relation
            record.directionRaw = item.direction
            record.returnStatusRaw = item.returnStatus
            record.personName = item.personName
            record.eventTitle = item.eventTitle
            record.amount = item.amount
            record.date = ISODay.date(item.date) ?? Date()
            record.memo = item.memo
            context.insert(record)
        }
        return backup.records.count
    }
}
