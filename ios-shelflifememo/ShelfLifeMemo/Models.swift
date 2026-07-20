import Foundation
import SwiftData
import SwiftUI

// MARK: - アプリのテーマカラー

extension Color {
    /// フレッシュな緑（#6A9C1F 相当）。アプリ全体の tint / アクセントに使用
    static let shelfGreen = Color(red: 0x6A / 255.0, green: 0x9C / 255.0, blue: 0x1F / 255.0)
}

// MARK: - 保存区分

enum FoodCategory: String, CaseIterable, Identifiable, Codable {
    case fridge, freezer, pantry

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fridge:  return "冷蔵"
        case .freezer: return "冷凍"
        case .pantry:  return "常温"
        }
    }

    var icon: String {
        switch self {
        case .fridge:  return "refrigerator"
        case .freezer: return "snowflake"
        case .pantry:  return "cabinet"
        }
    }

    var color: Color {
        switch self {
        case .fridge:  return .blue
        case .freezer: return .cyan
        case .pantry:  return .brown
        }
    }
}

// MARK: - SwiftData モデル

@Model
final class FoodItem {
    var name: String = ""
    var categoryRaw: String = FoodCategory.fridge.rawValue
    var expiryDate: Date = Date()
    var quantity: String = ""
    var location: String = ""
    var isConsumed: Bool = false
    var memo: String = ""
    var createdAt: Date = Date()

    init() {}

    var category: FoodCategory {
        get { FoodCategory(rawValue: categoryRaw) ?? .fridge }
        set { categoryRaw = newValue.rawValue }
    }

    /// 今日を基準にした期限までの残り日数（マイナスは期限切れ）
    var daysUntilExpiry: Int { daysUntil(expiryDate) }
}

/// 今日を基準にした、指定日までの残り日数（マイナスは過去）
func daysUntil(_ date: Date) -> Int {
    let cal = Calendar.current
    let start = cal.startOfDay(for: Date())
    let end = cal.startOfDay(for: date)
    return cal.dateComponents([.day], from: start, to: end).day ?? 0
}

/// 残り日数から表示ラベルを作る（"期限切れ" / "今日まで" / "あとN日"）
func expiryLabel(_ days: Int) -> String {
    if days < 0 { return "期限切れ" }
    if days == 0 { return "今日まで" }
    return "あと\(days)日"
}

/// 残り日数から一覧の色分けを決める（期限切れ・1日以内=赤、3日以内=オレンジ、7日以内=黄、それ以外は標準色）
func expiryColor(_ days: Int) -> Color {
    if days <= 1 { return .red }
    if days <= 3 { return .orange }
    if days <= 7 { return .yellow }
    return .primary
}

// MARK: - 日付フォーマット

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
