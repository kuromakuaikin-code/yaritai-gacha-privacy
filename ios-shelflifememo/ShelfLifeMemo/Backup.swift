import Foundation
import SwiftData

// MARK: - バックアップ用JSON構造

struct BackupFoodItem: Codable {
    var name: String
    var category: String
    var expiryDate: String
    var quantity: String
    var location: String
    var isConsumed: Bool
    var memo: String
}

struct BackupFile: Codable {
    var app = "ShelfLifeMemo"
    var version = 1
    var exportedAt: String
    var items: [BackupFoodItem]
}

enum BackupService {
    static func export(items: [FoodItem]) -> Data? {
        let backup = BackupFile(
            exportedAt: ISODay.string(Date()),
            items: items.map {
                BackupFoodItem(
                    name: $0.name,
                    category: $0.categoryRaw,
                    expiryDate: ISODay.string($0.expiryDate),
                    quantity: $0.quantity,
                    location: $0.location,
                    isConsumed: $0.isConsumed,
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
            let item = FoodItem()
            item.name = entry.name
            item.categoryRaw = entry.category
            item.expiryDate = ISODay.date(entry.expiryDate) ?? Date()
            item.quantity = entry.quantity
            item.location = entry.location
            item.isConsumed = entry.isConsumed
            item.memo = entry.memo
            context.insert(item)
        }
        return backup.items.count
    }
}
