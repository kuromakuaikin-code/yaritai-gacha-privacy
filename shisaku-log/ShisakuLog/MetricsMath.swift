import Foundation

// このファイルは Foundation のみに依存する純粋ロジック。
// Linux の swiftc でも単体で検証できるよう、UI/SwiftData には依存させないこと。

// MARK: - 日付ヘルパー（日単位の正規化）

enum Day {
    static var calendar: Calendar { Calendar.current }

    /// その日の 0:00 に正規化（DailyMetric の date はすべてこの値で保存する）
    static func start(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    static func today() -> Date { start(Date()) }

    static func add(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }
}

// MARK: - 指標の種類

enum MetricKind: String, CaseIterable, Identifiable {
    case revenue, downloads

    var id: String { rawValue }

    var label: String {
        switch self {
        case .revenue:   return "収益"
        case .downloads: return "DL数"
        }
    }

    var unit: ComparisonUnit {
        self == .revenue ? .yen : .count
    }
}

// MARK: - 前後7日平均の比較

struct BeforeAfter {
    struct Side {
        /// 対象期間の平均。数値がある日が1日もなければ nil
        let average: Double?
        /// 平均の対象になった日数（欠損日は含まない）
        let sampleDays: Int
    }

    let before: Side
    let after: Side

    /// 変化率(%)。どちらかが欠けている・前が0のときは nil
    var changePercent: Double? {
        guard let b = before.average, let a = after.average, b != 0 else { return nil }
        return (a - b) / abs(b) * 100
    }
}

enum Comparison {
    /// 実施日の前7日（前日まで）と後7日（翌日から）の平均を比較する。
    /// 値が nil の日・記録がない日は平均から除外する（端の欠損日対応）。
    static func beforeAfter(actionDate: Date, samples: [(date: Date, value: Double?)]) -> BeforeAfter {
        let day = Day.start(actionDate)
        var byDay: [Date: Double] = [:]
        for s in samples {
            if let v = s.value { byDay[Day.start(s.date)] = v }
        }
        func side(_ offsets: ClosedRange<Int>) -> BeforeAfter.Side {
            let values = offsets.compactMap { byDay[Day.add(day, $0)] }
            guard !values.isEmpty else { return BeforeAfter.Side(average: nil, sampleDays: 0) }
            return BeforeAfter.Side(average: values.reduce(0, +) / Double(values.count),
                                    sampleDays: values.count)
        }
        return BeforeAfter(before: side((-7)...(-1)), after: side(1...7))
    }
}

// MARK: - 表示フォーマット

enum ComparisonUnit {
    case yen, count
}

func yen(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    return "¥" + (f.string(from: NSNumber(value: value.rounded())) ?? "0")
}

/// 小数1桁。".0" は落とす（DL数の平均など）
func plainNumber(_ value: Double) -> String {
    let s = String(format: "%.1f", value)
    return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
}

func formatAverage(_ value: Double?, unit: ComparisonUnit) -> String {
    guard let value else { return "データなし" }
    switch unit {
    case .yen:   return yen(value)
    case .count: return plainNumber(value)
    }
}

/// 例: "前7日平均 ¥320 → 後7日平均 ¥410（+28%）"
/// あくまで前後比較の事実のみ。「効果」とは表現しない。
func comparisonSummary(_ ba: BeforeAfter, unit: ComparisonUnit) -> String {
    guard ba.before.sampleDays > 0 || ba.after.sampleDays > 0 else {
        return "前後7日のデータがありません"
    }
    var text = "前7日平均 \(formatAverage(ba.before.average, unit: unit))"
        + " → 後7日平均 \(formatAverage(ba.after.average, unit: unit))"
    if let pct = ba.changePercent {
        text += String(format: "（%+.0f%%）", pct)
    }
    return text
}

// MARK: - 入力パース

func parseDouble(_ s: String) -> Double? {
    let t = s.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
    return t.isEmpty ? nil : Double(t)
}

func parseInt(_ s: String) -> Int? {
    let t = s.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
    return t.isEmpty ? nil : Int(t)
}

// MARK: - 日付表示

func mediumDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy/M/d"
    return f.string(from: date)
}

func relativeDayLabel(_ date: Date) -> String {
    if Day.calendar.isDateInToday(date) { return "今日" }
    if Day.calendar.isDateInYesterday(date) { return "昨日" }
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "M/d(E)"
    return f.string(from: date)
}

// MARK: - テストデータ用の乱数（再現性のため自前LCG）

struct SeededRandom {
    var state: UInt64

    /// 0.0 ..< 1.0
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64(1) << 53)
    }
}
