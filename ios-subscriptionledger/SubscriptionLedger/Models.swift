import Foundation
import SwiftData
import SwiftUI

// MARK: - カテゴリー

enum SubscriptionCategory: String, CaseIterable, Identifiable, Codable {
    case video, music, cloud, news, fitness, game, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .video:   return "動画"
        case .music:   return "音楽"
        case .cloud:   return "クラウド・ストレージ"
        case .news:    return "ニュース・雑誌"
        case .fitness: return "フィットネス"
        case .game:    return "ゲーム"
        case .other:   return "その他"
        }
    }

    var icon: String {
        switch self {
        case .video:   return "play.rectangle.fill"
        case .music:   return "music.note"
        case .cloud:   return "icloud.fill"
        case .news:    return "newspaper.fill"
        case .fitness: return "figure.run"
        case .game:    return "gamecontroller.fill"
        case .other:   return "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .video:   return .red
        case .music:   return .pink
        case .cloud:   return .blue
        case .news:    return .orange
        case .fitness: return .green
        case .game:    return .indigo
        case .other:   return .brand
        }
    }
}

// MARK: - 支払いサイクル

enum BillingCycle: String, CaseIterable, Identifiable, Codable {
    case monthly, yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monthly: return "月払い"
        case .yearly:  return "年払い"
        }
    }
}

// MARK: - SwiftData モデル

@Model
final class Subscription {
    var serviceName: String = ""
    var categoryRaw: String = SubscriptionCategory.other.rawValue
    var billingCycleRaw: String = BillingCycle.monthly.rawValue
    var amount: Int = 0
    /// 支払日（1〜31）。年払いの月は billingMonth を参照
    var billingDay: Int = 1
    /// 年払いの支払月（1〜12）。月払いの場合は未使用
    var billingMonth: Int = 1
    var startDate: Date = Date()
    var isActive: Bool = true
    var memo: String = ""
    var createdAt: Date = Date()

    init() {}

    var category: SubscriptionCategory {
        get { SubscriptionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var billingCycle: BillingCycle {
        get { BillingCycle(rawValue: billingCycleRaw) ?? .monthly }
        set { billingCycleRaw = newValue.rawValue }
    }

    /// 月あたりに換算した金額（年払いは12で割る）
    var monthlyEquivalent: Double {
        switch billingCycle {
        case .monthly: return Double(amount)
        case .yearly:  return Double(amount) / 12.0
        }
    }

    /// 次回の更新日（本日以降で最も近い日付）
    var nextRenewalDate: Date {
        switch billingCycle {
        case .monthly:
            return RenewalCalculator.nextMonthly(day: billingDay, from: Date())
        case .yearly:
            return RenewalCalculator.nextYearly(month: billingMonth, day: billingDay, from: Date())
        }
    }
}

// MARK: - 次回更新日の計算

enum RenewalCalculator {
    /// 指定の年月における実在する日（月末を超える場合は月末に丸める）
    static func clampedDay(_ day: Int, year: Int, month: Int, calendar: Calendar) -> Int {
        guard let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return day
        }
        return min(max(day, 1), range.count)
    }

    static func nextMonthly(day: Int, from reference: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: reference)
        let year = calendar.component(.year, from: today)
        let month = calendar.component(.month, from: today)
        let thisMonthDay = clampedDay(day, year: year, month: month, calendar: calendar)
        if let candidate = calendar.date(from: DateComponents(year: year, month: month, day: thisMonthDay)),
           candidate >= today {
            return candidate
        }
        guard let firstOfThisMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let firstOfNextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfThisMonth) else {
            return today
        }
        let nextYear = calendar.component(.year, from: firstOfNextMonth)
        let nextMonth = calendar.component(.month, from: firstOfNextMonth)
        let nextDay = clampedDay(day, year: nextYear, month: nextMonth, calendar: calendar)
        return calendar.date(from: DateComponents(year: nextYear, month: nextMonth, day: nextDay)) ?? firstOfNextMonth
    }

    static func nextYearly(month: Int, day: Int, from reference: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: reference)
        let year = calendar.component(.year, from: today)
        let thisYearDay = clampedDay(day, year: year, month: month, calendar: calendar)
        if let candidate = calendar.date(from: DateComponents(year: year, month: month, day: thisYearDay)),
           candidate >= today {
            return candidate
        }
        let nextYear = year + 1
        let nextYearDay = clampedDay(day, year: nextYear, month: month, calendar: calendar)
        return calendar.date(from: DateComponents(year: nextYear, month: month, day: nextYearDay))
            ?? today
    }
}

// MARK: - 金額・日付フォーマット

func yen(_ amount: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return "¥" + (formatter.string(from: NSNumber(value: amount)) ?? "\(amount)")
}

func yen(_ amount: Double) -> String {
    yen(Int(amount.rounded()))
}

func mediumDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy/M/d"
    return f.string(from: date)
}

// MARK: - バックアップ互換の "yyyy-MM-dd"

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

// MARK: - サンプルデータ

enum SampleData {
    static func makeSubscription() -> Subscription {
        let s = Subscription()
        s.serviceName = "サンプル：動画配信サービス"
        s.category = .video
        s.billingCycle = .monthly
        s.amount = 1490
        s.billingDay = 15
        s.billingMonth = Calendar.current.component(.month, from: Date())
        s.startDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        s.isActive = true
        s.memo = "家族プラン"
        return s
    }
}
