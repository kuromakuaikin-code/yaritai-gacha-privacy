import Foundation
import SwiftData
import SwiftUI

// MARK: - 収集頻度

enum GarbageFrequency: String, CaseIterable, Identifiable, Codable {
    case everyWeek, biweekly, firstAndThird, secondAndFourth

    var id: String { rawValue }

    var label: String {
        switch self {
        case .everyWeek:      return "毎週"
        case .biweekly:       return "隔週"
        case .firstAndThird:  return "第1・3"
        case .secondAndFourth: return "第2・4"
        }
    }
}

// MARK: - SwiftData モデル

@Model
final class GarbageRule {
    /// 分別カテゴリ名（自由入力。例：可燃ごみ、不燃ごみ、資源(缶・びん)、プラスチック、古紙・古布）
    var categoryName: String = ""
    /// 表示色（16進カラーコード、# なし）
    var colorHex: String = "E53935"
    /// 対象曜日。1=日曜〜7=土曜（Calendar の weekday と同じ表現）
    var weekdays: [Int] = []
    var frequencyRaw: String = GarbageFrequency.everyWeek.rawValue
    /// メモ（例：収集は8:30まで）
    var note: String = ""
    var createdAt: Date = Date()

    init() {}

    var frequency: GarbageFrequency {
        get { GarbageFrequency(rawValue: frequencyRaw) ?? .everyWeek }
        set { frequencyRaw = newValue.rawValue }
    }

    var color: Color { Color(hex: colorHex) }

    /// 曜日の要約表示（例："月・木"）。月〜日の順で並べる
    var weekdaySummary: String {
        GomiSchedule.weekdayOrder
            .filter { weekdays.contains($0) }
            .map { GomiSchedule.weekdayLabel($0) }
            .joined(separator: "・")
    }

    /// 指定した日にこのルールが該当するか判定する。
    /// 「隔週」は週番号(weekOfYear)の偶奇、「第1・3」「第2・4」はその月の何週目か(weekOfMonth)で判定する簡易ロジック。
    /// 地域のカレンダーによっては起算日が実際の収集日とずれる場合があるため、あくまで目安として利用すること。
    func applies(on date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        guard weekdays.contains(weekday) else { return false }

        switch frequency {
        case .everyWeek:
            return true
        case .biweekly:
            let weekOfYear = calendar.component(.weekOfYear, from: date)
            return weekOfYear % 2 == 0
        case .firstAndThird:
            let occurrence = calendar.component(.weekOfMonth, from: date)
            return occurrence == 1 || occurrence == 3
        case .secondAndFourth:
            let occurrence = calendar.component(.weekOfMonth, from: date)
            return occurrence == 2 || occurrence == 4
        }
    }
}

// MARK: - 曜日・色のプリセット

enum GomiSchedule {
    /// 月・火・水・木・金・土・日 の表示順（weekday の値は 1=日曜〜7=土曜）
    static let weekdayOrder: [Int] = [2, 3, 4, 5, 6, 7, 1]

    static func weekdayLabel(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "日"
        case 2: return "月"
        case 3: return "火"
        case 4: return "水"
        case 5: return "木"
        case 6: return "金"
        case 7: return "土"
        default: return "?"
        }
    }

    /// 色選択のプリセットパレット（約8色）
    static let presetColors: [(name: String, hex: String)] = [
        ("赤", "E53935"),
        ("オレンジ", "FB8C00"),
        ("黄", "FDD835"),
        ("緑", "43A047"),
        ("青緑", "00897B"),
        ("青", "1E88E5"),
        ("紫", "8E24AA"),
        ("グレー", "757575"),
    ]
}

// MARK: - 色（16進コード）

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// アプリのテーマカラー（#2E8B57 相当のシーグリーン）
    static let gomiTint = Color(hex: "2E8B57")
}

// MARK: - 日付フォーマット

func shortDateLabel(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "M/d(E)"
    return f.string(from: date)
}

// MARK: - バックアップ用の "yyyy-MM-dd"

enum ISODay {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(_ date: Date) -> String { formatter.string(from: date) }
}

// MARK: - サンプルデータ

enum SampleData {
    static func makeRule() -> GarbageRule {
        let r = GarbageRule()
        r.categoryName = "可燃ごみ"
        r.colorHex = "E53935"
        r.weekdays = [2, 5] // 月・木
        r.frequency = .everyWeek
        r.note = "収集は8:30まで"
        return r
    }
}
