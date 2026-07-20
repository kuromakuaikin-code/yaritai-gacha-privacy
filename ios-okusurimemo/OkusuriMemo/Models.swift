import Foundation
import SwiftData
import SwiftUI

// MARK: - 服用タイミング

enum TimingSlot: String, CaseIterable, Identifiable, Codable {
    case morning, noon, evening, beforeSleep, asNeeded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning:     return "朝"
        case .noon:        return "昼"
        case .evening:     return "晩"
        case .beforeSleep: return "寝る前"
        case .asNeeded:    return "頓服"
        }
    }

    var icon: String {
        switch self {
        case .morning:     return "sunrise.fill"
        case .noon:        return "sun.max.fill"
        case .evening:     return "sunset.fill"
        case .beforeSleep: return "moon.stars.fill"
        case .asNeeded:    return "cross.case.fill"
        }
    }
}

// MARK: - SwiftData モデル

@Model
final class FamilyMember {
    var name: String = ""
    var relation: String = ""
    var memo: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Medication.member)
    var medications: [Medication]? = []

    init() {}
}

@Model
final class Medication {
    var name: String = ""
    var dosage: String = ""
    var timingRaw: [String] = []
    var hospitalName: String = ""
    var startDate: Date = Date()
    var endDate: Date?
    var memo: String = ""
    var createdAt: Date = Date()

    var member: FamilyMember?

    @Relationship(deleteRule: .cascade, inverse: \IntakeLog.medication)
    var logs: [IntakeLog]? = []

    init() {}

    var timing: [TimingSlot] {
        get { timingRaw.compactMap { TimingSlot(rawValue: $0) } }
        set { timingRaw = newValue.map { $0.rawValue } }
    }

    /// 服用中かどうか（開始日〜終了日の範囲に今日が含まれるか。終了日なしは継続中）
    var isActive: Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.startOfDay(for: startDate)
        guard start <= today else { return false }
        if let endDate {
            return cal.startOfDay(for: endDate) >= today
        }
        return true
    }

    /// 服用タイミングの表示順（朝→昼→晩→寝る前→頓服）に整えた要約文字列
    var timingSummary: String {
        let slots = TimingSlot.allCases.filter { timing.contains($0) }
        return slots.isEmpty ? "未設定" : slots.map { $0.label }.joined(separator: "・")
    }
}

@Model
final class IntakeLog {
    var date: Date = Date()
    var timingRaw: String = TimingSlot.morning.rawValue
    var taken: Bool = false

    var medication: Medication?

    init() {}

    var timing: TimingSlot {
        get { TimingSlot(rawValue: timingRaw) ?? .morning }
        set { timingRaw = newValue.rawValue }
    }
}

// MARK: - 日付フォーマット

func mediumDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy/M/d"
    return f.string(from: date)
}

/// お薬の期間表示（開始日〜終了日／継続中）
func dateRangeLabel(start: Date, end: Date?) -> String {
    guard let end else { return "\(mediumDate(start))〜（継続中）" }
    return "\(mediumDate(start))〜\(mediumDate(end))"
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
