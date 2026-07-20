import Foundation
import SwiftData

// MARK: - バックアップ用JSON構造

struct BackupContact: Codable {
    var name: String
    var address: String
    var relationship: String
    var memo: String
}

struct BackupGiftLog: Codable {
    /// バックアップファイル内の `contacts` 配列のインデックス
    var contactIndex: Int
    var occasion: String
    var year: Int
    var sent: Bool
    var received: Bool
    var memo: String
}

struct BackupFile: Codable {
    var app = "NengaMemo"
    var version = 1
    var exportedAt: String
    var contacts: [BackupContact]
    var giftLogs: [BackupGiftLog]
}

enum BackupService {
    static func export(contacts: [Contact]) -> Data? {
        // インデックスで Contact ⇔ GiftLog を対応させる
        var indexByContact: [ObjectIdentifier: Int] = [:]
        for (i, c) in contacts.enumerated() {
            indexByContact[ObjectIdentifier(c)] = i
        }

        let backupContacts = contacts.map {
            BackupContact(name: $0.name, address: $0.address, relationship: $0.relationship, memo: $0.memo)
        }

        var backupLogs: [BackupGiftLog] = []
        for contact in contacts {
            guard let idx = indexByContact[ObjectIdentifier(contact)] else { continue }
            for log in contact.giftLogs {
                backupLogs.append(
                    BackupGiftLog(
                        contactIndex: idx,
                        occasion: log.occasionRaw,
                        year: log.year,
                        sent: log.sent,
                        received: log.received,
                        memo: log.memo
                    )
                )
            }
        }

        let backup = BackupFile(
            exportedAt: ISODay.string(Date()),
            contacts: backupContacts,
            giftLogs: backupLogs
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(backup)
    }

    /// インポートした宛先の件数を返す。失敗時は nil
    @discardableResult
    static func importData(_ data: Data, into context: ModelContext) -> Int? {
        guard let backup = try? JSONDecoder().decode(BackupFile.self, from: data) else { return nil }

        var insertedContacts: [Contact] = []
        for item in backup.contacts {
            let contact = Contact(name: item.name, address: item.address, relationship: item.relationship, memo: item.memo)
            context.insert(contact)
            insertedContacts.append(contact)
        }

        for item in backup.giftLogs {
            guard item.contactIndex >= 0, item.contactIndex < insertedContacts.count else { continue }
            let log = GiftLog(
                occasion: Occasion(rawValue: item.occasion) ?? .other,
                year: item.year,
                sent: item.sent,
                received: item.received,
                memo: item.memo,
                contact: insertedContacts[item.contactIndex]
            )
            context.insert(log)
        }

        return insertedContacts.count
    }
}

// MARK: - Web版バックアップ互換の "yyyy-MM-dd"

enum ISODay {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(_ date: Date) -> String { formatter.string(from: date) }
    static func date(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        return formatter.date(from: s)
    }
}
