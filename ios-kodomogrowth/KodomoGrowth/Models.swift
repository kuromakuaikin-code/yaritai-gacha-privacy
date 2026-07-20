import Foundation
import SwiftData
import SwiftUI

// MARK: - 性別

enum Sex: String, CaseIterable, Identifiable, Codable {
    case male, female, unspecified

    var id: String { rawValue }

    var label: String {
        switch self {
        case .male:        return "男の子"
        case .female:      return "女の子"
        case .unspecified: return "未設定"
        }
    }

    var icon: String {
        switch self {
        case .male:        return "figure.child"
        case .female:      return "figure.child"
        case .unspecified: return "person.fill"
        }
    }

    var color: Color {
        switch self {
        case .male:        return .blue
        case .female:      return .pink
        case .unspecified: return .kodomoTeal
        }
    }
}

// MARK: - SwiftData モデル

@Model
final class Child {
    var uuid: UUID = UUID()
    var name: String = ""
    var birthday: Date = Date()
    var sexRaw: String = Sex.unspecified.rawValue
    var memo: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \GrowthRecord.child)
    var records: [GrowthRecord] = []

    init() {}

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .unspecified }
        set { sexRaw = newValue.rawValue }
    }
}

@Model
final class GrowthRecord {
    var child: Child?
    var date: Date = Date()
    var heightCm: Double?
    var weightKg: Double?
    var memo: String = ""
    var createdAt: Date = Date()

    init() {}
}

// MARK: - 年齢の計算・表示

/// 生年月日から指定日時点の「n歳nヶ月」表記を返す（1歳未満は「nヶ月」）
func ageLabel(birthday: Date, at date: Date) -> String {
    let cal = Calendar.current
    let start = cal.startOfDay(for: birthday)
    let end = cal.startOfDay(for: date)
    guard end >= start else { return "0ヶ月" }
    let comps = cal.dateComponents([.year, .month], from: start, to: end)
    let years = max(comps.year ?? 0, 0)
    let months = max(comps.month ?? 0, 0)
    if years <= 0 {
        return "\(months)ヶ月"
    }
    return "\(years)歳\(months)ヶ月"
}

/// 生年月日から指定日時点までの月齢（グラフのX軸用）
func ageInMonths(birthday: Date, at date: Date) -> Int {
    let cal = Calendar.current
    let start = cal.startOfDay(for: birthday)
    let end = cal.startOfDay(for: date)
    guard end >= start else { return 0 }
    let comps = cal.dateComponents([.month], from: start, to: end)
    return max(comps.month ?? 0, 0)
}

// MARK: - 数値フォーマット

func heightLabel(_ value: Double?) -> String {
    guard let value else { return "－" }
    return String(format: "%.1f cm", value)
}

func weightLabel(_ value: Double?) -> String {
    guard let value else { return "－" }
    return String(format: "%.2f kg", value)
}

func mediumDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy/M/d"
    return f.string(from: date)
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
