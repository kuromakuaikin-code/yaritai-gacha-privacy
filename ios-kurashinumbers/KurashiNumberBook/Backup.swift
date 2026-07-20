import Foundation
import SwiftData

// MARK: - バックアップ用JSON構造（4モジュール共通の1ファイル）

struct BackupUtilityRecord: Codable {
    var kind: String
    var yearMonth: String
    var amountYen: Int
    var usageNote: String
    var memo: String
}

struct BackupPointAccount: Codable {
    var serviceName: String
    var currentBalance: Int
    var lastUpdated: String
    var expiryDate: String?
    var memo: String
}

struct BackupGiftMemory: Codable {
    var personName: String
    var occasion: String
    var month: Int
    var day: Int
    var lastGiftDescription: String
    var lastGiftYear: Int
    var memo: String
}

struct BackupRenewalItem: Codable {
    var name: String
    var category: String
    var dueDate: String
    var reminderNote: String
    var isDone: Bool
}

struct BackupFile: Codable {
    var app = "KurashiNumberBook"
    var version = 1
    var exportedAt: String
    var utilityRecords: [BackupUtilityRecord]
    var pointAccounts: [BackupPointAccount]
    var giftMemories: [BackupGiftMemory]
    var renewalItems: [BackupRenewalItem]
}

enum BackupService {
    static func export(
        utilityRecords: [UtilityRecord],
        pointAccounts: [PointAccount],
        giftMemories: [GiftMemory],
        renewalItems: [RenewalItem]
    ) -> Data? {
        let backup = BackupFile(
            exportedAt: ISODay.string(Date()),
            utilityRecords: utilityRecords.map {
                BackupUtilityRecord(
                    kind: $0.kindRaw,
                    yearMonth: ISODay.string($0.yearMonth),
                    amountYen: $0.amountYen,
                    usageNote: $0.usageNote,
                    memo: $0.memo
                )
            },
            pointAccounts: pointAccounts.map {
                BackupPointAccount(
                    serviceName: $0.serviceName,
                    currentBalance: $0.currentBalance,
                    lastUpdated: ISODay.string($0.lastUpdated),
                    expiryDate: $0.expiryDate.map { ISODay.string($0) },
                    memo: $0.memo
                )
            },
            giftMemories: giftMemories.map {
                BackupGiftMemory(
                    personName: $0.personName,
                    occasion: $0.occasion,
                    month: $0.month,
                    day: $0.day,
                    lastGiftDescription: $0.lastGiftDescription,
                    lastGiftYear: $0.lastGiftYear,
                    memo: $0.memo
                )
            },
            renewalItems: renewalItems.map {
                BackupRenewalItem(
                    name: $0.name,
                    category: $0.categoryRaw,
                    dueDate: ISODay.string($0.dueDate),
                    reminderNote: $0.reminderNote,
                    isDone: $0.isDone
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(backup)
    }

    /// インポート件数（4モジュール合計）を返す。失敗時は nil
    @discardableResult
    static func importData(_ data: Data, into context: ModelContext) -> Int? {
        guard let backup = try? JSONDecoder().decode(BackupFile.self, from: data) else { return nil }

        for item in backup.utilityRecords {
            let record = UtilityRecord()
            record.kindRaw = item.kind
            record.yearMonth = ISODay.date(item.yearMonth) ?? Date()
            record.amountYen = item.amountYen
            record.usageNote = item.usageNote
            record.memo = item.memo
            context.insert(record)
        }

        for item in backup.pointAccounts {
            let account = PointAccount()
            account.serviceName = item.serviceName
            account.currentBalance = item.currentBalance
            account.lastUpdated = ISODay.date(item.lastUpdated) ?? Date()
            account.expiryDate = ISODay.date(item.expiryDate)
            account.memo = item.memo
            context.insert(account)
        }

        for item in backup.giftMemories {
            let memory = GiftMemory()
            memory.personName = item.personName
            memory.occasion = item.occasion
            memory.month = item.month
            memory.day = item.day
            memory.lastGiftDescription = item.lastGiftDescription
            memory.lastGiftYear = item.lastGiftYear
            memory.memo = item.memo
            context.insert(memory)
        }

        for item in backup.renewalItems {
            let renewal = RenewalItem()
            renewal.name = item.name
            renewal.categoryRaw = item.category
            renewal.dueDate = ISODay.date(item.dueDate) ?? Date()
            renewal.reminderNote = item.reminderNote
            renewal.isDone = item.isDone
            context.insert(renewal)
        }

        return backup.utilityRecords.count + backup.pointAccounts.count
            + backup.giftMemories.count + backup.renewalItems.count
    }
}
