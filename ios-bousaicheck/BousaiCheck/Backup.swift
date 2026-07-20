import Foundation
import SwiftData

// MARK: - バックアップ用JSON構造

struct BackupChecklistItem: Codable {
    var name: String
    var category: String
    var isChecked: Bool
    var expiryDate: String?
    var memo: String
    var isPreset: Bool
    var order: Int
}

struct BackupContact: Codable {
    var name: String
    var relationship: String
    var phone: String
    var meetingPoint: String
    var memo: String
}

struct BackupFile: Codable {
    var app = "BousaiCheck"
    var version = 1
    var exportedAt: String
    var checklistItems: [BackupChecklistItem]
    var contacts: [BackupContact]
}

enum BackupService {
    static func export(items: [ChecklistItem], contacts: [EmergencyContact]) -> Data? {
        let backup = BackupFile(
            exportedAt: ISODay.string(Date()),
            checklistItems: items.map {
                BackupChecklistItem(
                    name: $0.name,
                    category: $0.categoryRaw,
                    isChecked: $0.isChecked,
                    expiryDate: $0.expiryDate.map { ISODay.string($0) },
                    memo: $0.memo,
                    isPreset: $0.isPreset,
                    order: $0.order
                )
            },
            contacts: contacts.map {
                BackupContact(
                    name: $0.name,
                    relationship: $0.relationship,
                    phone: $0.phone,
                    meetingPoint: $0.meetingPoint,
                    memo: $0.memo
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(backup)
    }

    /// インポート件数（チェックリスト項目＋連絡先の合計）を返す。失敗時は nil
    @discardableResult
    static func importData(_ data: Data, into context: ModelContext) -> Int? {
        guard let backup = try? JSONDecoder().decode(BackupFile.self, from: data) else { return nil }

        for item in backup.checklistItems {
            let record = ChecklistItem()
            record.name = item.name
            record.categoryRaw = item.category
            record.isChecked = item.isChecked
            record.expiryDate = ISODay.date(item.expiryDate)
            record.memo = item.memo
            record.isPreset = item.isPreset
            record.order = item.order
            context.insert(record)
        }

        for c in backup.contacts {
            let contact = EmergencyContact()
            contact.name = c.name
            contact.relationship = c.relationship
            contact.phone = c.phone
            contact.meetingPoint = c.meetingPoint
            contact.memo = c.memo
            context.insert(contact)
        }

        return backup.checklistItems.count + backup.contacts.count
    }
}
