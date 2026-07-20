import Foundation
import SwiftData

// MARK: - バックアップ用JSON構造

struct BackupSubscription: Codable {
    var serviceName: String
    var category: String
    var billingCycle: String
    var amount: Int
    var billingDay: Int
    var billingMonth: Int
    var startDate: String
    var isActive: Bool
    var memo: String
}

struct BackupFile: Codable {
    var app = "SubscriptionLedger"
    var version = 1
    var exportedAt: String
    var subscriptions: [BackupSubscription]
}

enum BackupService {
    static func export(subscriptions: [Subscription]) -> Data? {
        let backup = BackupFile(
            exportedAt: ISODay.string(Date()),
            subscriptions: subscriptions.map {
                BackupSubscription(
                    serviceName: $0.serviceName,
                    category: $0.categoryRaw,
                    billingCycle: $0.billingCycleRaw,
                    amount: $0.amount,
                    billingDay: $0.billingDay,
                    billingMonth: $0.billingMonth,
                    startDate: ISODay.string($0.startDate),
                    isActive: $0.isActive,
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
        for item in backup.subscriptions {
            let subscription = Subscription()
            subscription.serviceName = item.serviceName
            subscription.categoryRaw = item.category
            subscription.billingCycleRaw = item.billingCycle
            subscription.amount = item.amount
            subscription.billingDay = item.billingDay
            subscription.billingMonth = item.billingMonth
            subscription.startDate = ISODay.date(item.startDate) ?? Date()
            subscription.isActive = item.isActive
            subscription.memo = item.memo
            context.insert(subscription)
        }
        return backup.subscriptions.count
    }
}
