import Foundation
import SwiftData

// MARK: - バックアップ用JSON構造

struct BackupChild: Codable {
    var id: String
    var name: String
    var birthday: String
    var sex: String
    var memo: String
}

struct BackupRecord: Codable {
    var childId: String
    var date: String
    var heightCm: Double?
    var weightKg: Double?
    var memo: String
}

struct BackupFile: Codable {
    var app = "KodomoGrowth"
    var version = 1
    var exportedAt: String
    var children: [BackupChild]
    var records: [BackupRecord]
}

enum BackupService {
    static func export(children: [Child]) -> Data? {
        let backupChildren = children.map {
            BackupChild(
                id: $0.uuid.uuidString,
                name: $0.name,
                birthday: ISODay.string($0.birthday),
                sex: $0.sexRaw,
                memo: $0.memo
            )
        }
        let backupRecords = children.flatMap { child in
            child.records.map { record in
                BackupRecord(
                    childId: child.uuid.uuidString,
                    date: ISODay.string(record.date),
                    heightCm: record.heightCm,
                    weightKg: record.weightKg,
                    memo: record.memo
                )
            }
        }
        let backup = BackupFile(
            exportedAt: ISODay.string(Date()),
            children: backupChildren,
            records: backupRecords
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(backup)
    }

    /// インポートした記録件数を返す。失敗時は nil
    @discardableResult
    static func importData(_ data: Data, into context: ModelContext) -> Int? {
        guard let backup = try? JSONDecoder().decode(BackupFile.self, from: data) else { return nil }

        var childMap: [String: Child] = [:]
        for item in backup.children {
            let child = Child()
            child.uuid = UUID(uuidString: item.id) ?? UUID()
            child.name = item.name
            child.birthday = ISODay.date(item.birthday) ?? Date()
            child.sexRaw = item.sex
            child.memo = item.memo
            context.insert(child)
            childMap[item.id] = child
        }

        var count = 0
        for item in backup.records {
            let record = GrowthRecord()
            record.child = childMap[item.childId]
            record.date = ISODay.date(item.date) ?? Date()
            record.heightCm = item.heightCm
            record.weightKg = item.weightKg
            record.memo = item.memo
            context.insert(record)
            count += 1
        }
        return count
    }
}
