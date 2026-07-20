import Foundation
import SwiftData
import SwiftUI

// MARK: - モジュール1: 習い事の出席・月謝記録

@Model
final class LessonCourse {
    var childName: String = ""
    var courseName: String = ""
    var monthlyFee: Int = 0
    /// 例：「毎週土曜」など自由入力の曜日メモ
    var dayOfWeekNote: String = ""
    var memo: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \LessonSession.course)
    var sessions: [LessonSession] = []

    init() {}
}

@Model
final class LessonSession {
    var date: Date = Date()
    var attended: Bool = true
    var memo: String = ""
    var course: LessonCourse?

    init() {}
}

// MARK: - モジュール2: 読書記録

@Model
final class BookRecord {
    var childName: String = ""
    var title: String = ""
    var author: String = ""
    var finishedDate: Date = Date()
    /// 0〜5の評価
    var rating: Int = 0
    /// ページ数（未入力可）
    var pages: Int?
    /// 感想メモ
    var summary: String = ""
    var createdAt: Date = Date()

    init() {}
}

// MARK: - モジュール3: 資格・勉強進捗管理

@Model
final class StudyGoal {
    var title: String = ""
    var targetDate: Date = Date()
    var totalMinutesGoal: Int = 0
    var memo: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \StudyLog.goal)
    var logs: [StudyLog] = []

    init() {}

    /// これまでに記録した勉強時間の合計（分）
    var totalMinutesLogged: Int { logs.reduce(0) { $0 + $1.minutesStudied } }

    /// 目標に対する進捗率（0.0〜1.0）
    var progress: Double {
        guard totalMinutesGoal > 0 else { return 0 }
        return min(Double(totalMinutesLogged) / Double(totalMinutesGoal), 1.0)
    }

    /// 目標日までの残り日数（過ぎている場合は負の値）
    var daysUntilTarget: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let target = cal.startOfDay(for: targetDate)
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }
}

@Model
final class StudyLog {
    var date: Date = Date()
    var minutesStudied: Int = 0
    var memo: String = ""
    var goal: StudyGoal?

    init() {}
}

// MARK: - モジュール4: 学校行事・持ち物チェックリスト

@Model
final class SchoolEvent {
    var title: String = ""
    var date: Date = Date()
    var memo: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \ChecklistEntry.event)
    var entries: [ChecklistEntry] = []

    init() {}

    var checkedCount: Int { entries.filter { $0.isChecked }.count }
}

@Model
final class ChecklistEntry {
    var text: String = ""
    var isChecked: Bool = false
    var createdAt: Date = Date()
    var event: SchoolEvent?

    init() {}
}

// MARK: - 日付フォーマット

func mediumDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy/M/d"
    return f.string(from: date)
}

func mediumDateWeekday(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy/M/d(E)"
    return f.string(from: date)
}

func yen(_ amount: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return "¥" + (formatter.string(from: NSNumber(value: amount)) ?? "\(amount)")
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
