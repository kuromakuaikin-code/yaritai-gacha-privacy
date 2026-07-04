import Foundation
import SwiftData
import SwiftUI

// MARK: - ステータス

enum PartnerStatus: String, CaseIterable, Identifiable {
    case active, watch, serious, end

    var id: String { rawValue }

    var label: String {
        switch self {
        case .active:  return "やり取り中"
        case .watch:   return "様子見"
        case .serious: return "真剣交際"
        case .end:     return "ご縁なし"
        }
    }

    var color: Color {
        switch self {
        case .active:  return .pink
        case .watch:   return .blue
        case .serious: return .green
        case .end:     return .gray
        }
    }
}

// MARK: - SwiftData モデル

@Model
final class Partner {
    var name: String = ""
    var age: String = ""
    var job: String = ""
    var metVia: String = ""
    var likes: String = ""
    var ng: String = ""
    var memo: String = ""
    var statusRaw: String = PartnerStatus.active.rawValue
    /// 話した話題のID（プリセット a1〜d6 / MY話題のUUID文字列）
    var talked: [String] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \DateRecord.partner)
    var dates: [DateRecord] = []

    init(name: String = "") {
        self.name = name
    }

    var status: PartnerStatus {
        get { PartnerStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var sortedDates: [DateRecord] {
        dates.sorted { $0.date > $1.date }
    }

    var lastDate: DateRecord? { sortedDates.first }

    var avgRating: Int {
        let rated = dates.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return 0 }
        return Int((Double(rated.reduce(0) { $0 + $1.rating }) / Double(rated.count)).rounded())
    }

    /// 今日以降で最も近い「次回の予定日」
    var nextUpcoming: Date? {
        let today = Calendar.current.startOfDay(for: Date())
        return dates.compactMap { $0.nextDate }
            .filter { Calendar.current.startOfDay(for: $0) >= today }
            .min()
    }
}

@Model
final class DateRecord {
    var date: Date = Date()
    var place: String = ""
    var topics: String = ""
    var good: String = ""
    var bad: String = ""
    var next: String = ""
    var nextDate: Date?
    var rating: Int = 0
    var partner: Partner?

    init(date: Date = Date()) {
        self.date = date
    }
}

@Model
final class MyTopic {
    /// 話題チェック（Partner.talked）との紐付け用ID
    var key: String = UUID().uuidString
    var text: String = ""
    var note: String = ""
    var order: Int = 0

    init(text: String = "", note: String = "", order: Int = 0) {
        self.text = text
        self.note = note
        self.order = order
    }
}

// MARK: - 日付ヘルパー（Web版バックアップと互換の "yyyy-MM-dd"）

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

func daysUntilLabel(_ date: Date) -> String {
    let cal = Calendar.current
    let d = cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                               to: cal.startOfDay(for: date)).day ?? 0
    return d <= 0 ? "今日！" : "あと\(d)日"
}

func mediumDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy/M/d"
    return f.string(from: date)
}

// MARK: - サンプルデータ

enum SampleData {
    static func makePartner() -> Partner {
        let p = Partner(name: "サンプル：Aさん")
        p.age = "31"
        p.job = "メーカー営業"
        p.metVia = "婚活アプリ"
        p.likes = "カフェ巡り、猫、温泉"
        p.ng = "仕事の愚痴は控えめに"
        p.memo = "笑顔が素敵。会話のテンポが合う"
        p.talked = ["a1", "a2"]
        let d = DateRecord(date: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date())
        d.place = "駅前のカフェでお茶"
        d.rating = 4
        d.topics = "休日の過ごし方、出身地の話"
        d.good = "聞き上手で話しやすかった"
        d.bad = "少し緊張していたかも"
        d.next = "水族館デート。誕生日を聞く"
        d.nextDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        p.dates.append(d)
        return p
    }
}
