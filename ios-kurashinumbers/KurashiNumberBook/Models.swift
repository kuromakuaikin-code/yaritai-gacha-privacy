import Foundation
import SwiftData
import SwiftUI

// MARK: - テーマカラー

extension Color {
    /// アプリ共通のテーマカラー（暖かみのあるゴールド系 #C79A2E）
    static let kurashiGold = Color(red: 199.0 / 255.0, green: 154.0 / 255.0, blue: 46.0 / 255.0)
}

// MARK: - 共通フォーマッタ

func yen(_ amount: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return "¥" + (formatter.string(from: NSNumber(value: amount)) ?? "\(amount)")
}

func mediumDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy/M/d"
    return f.string(from: date)
}

func yearMonthLabel(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy年M月"
    return f.string(from: date)
}

/// 指定日を「その月の1日」に丸める
func startOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
    let comps = calendar.dateComponents([.year, .month], from: date)
    return calendar.date(from: comps) ?? date
}

/// 今日を基準にした、指定日までの残り日数（マイナスは過去）
func daysUntil(_ date: Date, calendar: Calendar = .current) -> Int {
    let start = calendar.startOfDay(for: Date())
    let end = calendar.startOfDay(for: date)
    return calendar.dateComponents([.day], from: start, to: end).day ?? 0
}

/// 残り日数から表示ラベルを作る（"期限切れ" / "本日期限" / "あとN日"）
func daysLabel(_ days: Int) -> String {
    if days < 0 { return "期限切れ" }
    if days == 0 { return "本日期限" }
    return "あと\(days)日"
}

/// 残り日数から色分けを決める（期限切れ・7日以内=赤、30日以内=オレンジ、それ以外は標準色）
func deadlineColor(_ days: Int) -> Color {
    if days <= 7 { return .red }
    if days <= 30 { return .orange }
    return .primary
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

// =========================================================
// MARK: - モジュール1: 光熱費記録（UtilityRecord）
// =========================================================

enum UtilityKind: String, CaseIterable, Identifiable, Codable {
    case electricity, gas, water

    var id: String { rawValue }

    var label: String {
        switch self {
        case .electricity: return "電気"
        case .gas:          return "ガス"
        case .water:        return "水道"
        }
    }

    var icon: String {
        switch self {
        case .electricity: return "bolt.fill"
        case .gas:          return "flame.fill"
        case .water:        return "drop.fill"
        }
    }

    var color: Color {
        switch self {
        case .electricity: return .yellow
        case .gas:          return .orange
        case .water:        return .blue
        }
    }
}

@Model
final class UtilityRecord {
    var kindRaw: String = UtilityKind.electricity.rawValue
    /// その月の1日として保存する年月
    var yearMonth: Date = Date()
    var amountYen: Int = 0
    var usageNote: String = ""
    var memo: String = ""
    var createdAt: Date = Date()

    init() {}

    var kind: UtilityKind {
        get { UtilityKind(rawValue: kindRaw) ?? .electricity }
        set { kindRaw = newValue.rawValue }
    }
}

// =========================================================
// MARK: - モジュール2: ポイ活残高管理（PointAccount）
// =========================================================

@Model
final class PointAccount {
    var serviceName: String = ""
    var currentBalance: Int = 0
    var lastUpdated: Date = Date()
    var expiryDate: Date?
    var memo: String = ""
    var createdAt: Date = Date()

    init() {}

    /// 有効期限までの残り日数（未設定の場合は nil）
    var daysUntilExpiry: Int? {
        guard let expiryDate else { return nil }
        return daysUntil(expiryDate)
    }

    /// 有効期限が30日以内、または期限切れかどうか
    var isExpiringSoon: Bool {
        guard let days = daysUntilExpiry else { return false }
        return days <= 30
    }
}

// =========================================================
// MARK: - モジュール3: 記念日・ギフト履歴（GiftMemory）
// =========================================================

@Model
final class GiftMemory {
    var personName: String = ""
    var occasion: String = ""
    /// 1〜12
    var month: Int = 1
    /// 1〜31
    var day: Int = 1
    var lastGiftDescription: String = ""
    var lastGiftYear: Int = Calendar.current.component(.year, from: Date())
    var memo: String = ""
    var createdAt: Date = Date()

    init() {}

    /// 次回の記念日までの残り日数（今年すでに過ぎていれば来年で計算）
    var daysUntilNext: Int { daysUntilNextOccurrence(month: month, day: day) }
}

/// 月日（year非依存）から、次に訪れるその日までの残り日数を求める
func daysUntilNextOccurrence(month: Int, day: Int, calendar: Calendar = .current) -> Int {
    let today = calendar.startOfDay(for: Date())
    let thisYear = calendar.component(.year, from: today)

    func makeDate(year: Int) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        // 2/29など存在しない日付の場合、月末に丸める
        return calendar.date(from: comps) ?? calendar.date(from: DateComponents(year: year, month: month, day: 28))
    }

    guard var candidate = makeDate(year: thisYear) else { return 0 }
    if candidate < today {
        candidate = makeDate(year: thisYear + 1) ?? candidate
    }
    return calendar.dateComponents([.day], from: today, to: candidate).day ?? 0
}

/// 「◯月◯日」表示
func monthDayLabel(month: Int, day: Int) -> String {
    "\(month)月\(day)日"
}

// =========================================================
// MARK: - モジュール4: 更新期限管理（RenewalItem）
// =========================================================

enum RenewalCategory: String, CaseIterable, Identifiable, Codable {
    case vehicle, license, insurance, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vehicle:   return "車関連"
        case .license:   return "免許・資格"
        case .insurance: return "保険"
        case .other:     return "その他"
        }
    }

    var icon: String {
        switch self {
        case .vehicle:   return "car.fill"
        case .license:   return "person.text.rectangle.fill"
        case .insurance: return "shield.lefthalf.filled"
        case .other:     return "doc.text.fill"
        }
    }

    var color: Color {
        switch self {
        case .vehicle:   return .blue
        case .license:   return .purple
        case .insurance: return .green
        case .other:     return .gray
        }
    }
}

@Model
final class RenewalItem {
    var name: String = ""
    var categoryRaw: String = RenewalCategory.other.rawValue
    var dueDate: Date = Date()
    var reminderNote: String = ""
    var isDone: Bool = false
    var createdAt: Date = Date()

    init() {}

    var category: RenewalCategory {
        get { RenewalCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var daysUntilDue: Int { daysUntil(dueDate) }
}

// MARK: - サンプルデータ（プレビュー等で利用）

enum SampleData {
    static func makeUtilityRecord() -> UtilityRecord {
        let r = UtilityRecord()
        r.kind = .electricity
        r.yearMonth = startOfMonth(Date())
        r.amountYen = 8200
        r.usageNote = "320kWh"
        r.memo = "サンプルデータ"
        return r
    }
}
