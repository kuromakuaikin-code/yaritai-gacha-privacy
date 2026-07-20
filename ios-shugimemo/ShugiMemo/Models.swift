import Foundation
import SwiftData
import SwiftUI

// MARK: - 行事の種類

enum EventKind: String, CaseIterable, Identifiable, Codable {
    case wedding, funeral, birth, entrance, newHome, getWell, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wedding:  return "結婚祝い"
        case .funeral:  return "香典・お悔やみ"
        case .birth:    return "出産祝い"
        case .entrance: return "入学・卒業祝い"
        case .newHome:  return "新築祝い"
        case .getWell:  return "お見舞い"
        case .other:    return "その他"
        }
    }

    var icon: String {
        switch self {
        case .wedding:  return "heart.fill"
        case .funeral:  return "leaf.fill"
        case .birth:    return "figure.child"
        case .entrance: return "graduationcap.fill"
        case .newHome:  return "house.fill"
        case .getWell:  return "cross.case.fill"
        case .other:    return "gift.fill"
        }
    }

    /// 「お返し」の呼び方（種類によって慣習の名称が異なる）
    var returnLabel: String {
        switch self {
        case .funeral: return "香典返し"
        default:       return "内祝い・お返し"
        }
    }

    var color: Color {
        switch self {
        case .wedding:  return .pink
        case .funeral:  return .gray
        case .birth:    return .orange
        case .entrance: return .blue
        case .newHome:  return .green
        case .getWell:  return .purple
        case .other:    return .brown
        }
    }
}

// MARK: - 関係性

enum Relation: String, CaseIterable, Identifiable, Codable {
    case family, relative, friend, work, neighbor, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .family:   return "家族・親族"
        case .relative: return "親戚"
        case .friend:   return "友人"
        case .work:     return "職場"
        case .neighbor: return "近所・地域"
        case .other:    return "その他"
        }
    }
}

// MARK: - 授受の方向

enum Direction: String, CaseIterable, Identifiable, Codable {
    case given, received

    var id: String { rawValue }

    var label: String {
        switch self {
        case .given:    return "渡した"
        case .received: return "いただいた"
        }
    }

    var shortLabel: String {
        switch self {
        case .given:    return "OUT"
        case .received: return "IN"
        }
    }
}

// MARK: - お返し状況

enum ReturnStatus: String, CaseIterable, Identifiable, Codable {
    case notNeeded, pending, done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notNeeded: return "不要"
        case .pending:   return "未対応"
        case .done:      return "対応済み"
        }
    }

    var color: Color {
        switch self {
        case .notNeeded: return .gray
        case .pending:   return .red
        case .done:      return .green
        }
    }
}

// MARK: - SwiftData モデル

@Model
final class GiftRecord {
    var eventKindRaw: String = EventKind.wedding.rawValue
    var relationRaw: String = Relation.friend.rawValue
    var directionRaw: String = Direction.given.rawValue
    var returnStatusRaw: String = ReturnStatus.notNeeded.rawValue
    var personName: String = ""
    var eventTitle: String = ""
    var amount: Int = 0
    var date: Date = Date()
    var memo: String = ""
    var createdAt: Date = Date()

    init() {}

    var eventKind: EventKind {
        get { EventKind(rawValue: eventKindRaw) ?? .other }
        set { eventKindRaw = newValue.rawValue }
    }

    var relation: Relation {
        get { Relation(rawValue: relationRaw) ?? .other }
        set { relationRaw = newValue.rawValue }
    }

    var direction: Direction {
        get { Direction(rawValue: directionRaw) ?? .given }
        set { directionRaw = newValue.rawValue }
    }

    var returnStatus: ReturnStatus {
        get { ReturnStatus(rawValue: returnStatusRaw) ?? .notNeeded }
        set { returnStatusRaw = newValue.rawValue }
    }

    /// お返しの目安金額（半返しを基準に、切りのよい額へ丸め）
    var suggestedReturnAmount: Int { suggestedReturn(for: amount) }
}

/// 半返しを基準に、切りのよい額へ丸めたお返しの目安金額
func suggestedReturn(for amount: Int) -> Int {
    let half = Double(amount) / 2.0
    let step = half >= 10000 ? 5000.0 : (half >= 3000 ? 1000.0 : 500.0)
    return max(Int((half / step).rounded()) * Int(step), 0)
}

// MARK: - 金額フォーマット

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

// MARK: - 相場ガイド（静的データ・目安）

struct MarketRate: Identifiable {
    let id = UUID()
    let eventKind: EventKind
    let relation: Relation
    let rangeLabel: String
    let note: String
}

enum MarketRateData {
    static let all: [MarketRate] = [
        // 結婚祝い（ご祝儀）
        MarketRate(eventKind: .wedding, relation: .family, rangeLabel: "3万〜10万円", note: "兄弟姉妹・子など。会費制の場合は会費のみのことも"),
        MarketRate(eventKind: .wedding, relation: .relative, rangeLabel: "3万〜5万円", note: "甥・姪・いとこなど"),
        MarketRate(eventKind: .wedding, relation: .friend, rangeLabel: "3万円", note: "偶数は避け、慶事は奇数額が基本"),
        MarketRate(eventKind: .wedding, relation: .work, rangeLabel: "3万〜5万円", note: "上司は多め、同僚・部下は3万円が目安"),
        MarketRate(eventKind: .wedding, relation: .neighbor, rangeLabel: "2万〜3万円", note: ""),
        MarketRate(eventKind: .wedding, relation: .other, rangeLabel: "1万〜3万円", note: ""),

        // 香典
        MarketRate(eventKind: .funeral, relation: .family, rangeLabel: "5万〜10万円", note: "実の親。祖父母・兄弟姉妹は1万〜5万円が目安"),
        MarketRate(eventKind: .funeral, relation: .relative, rangeLabel: "1万〜3万円", note: "おじ・おば・いとこなど"),
        MarketRate(eventKind: .funeral, relation: .friend, rangeLabel: "5千〜1万円", note: ""),
        MarketRate(eventKind: .funeral, relation: .work, rangeLabel: "5千〜1万円", note: "同僚・上司・その家族など"),
        MarketRate(eventKind: .funeral, relation: .neighbor, rangeLabel: "3千〜5千円", note: "町内会・自治会での取り決めがある地域も"),
        MarketRate(eventKind: .funeral, relation: .other, rangeLabel: "3千〜1万円", note: "新札は避け、香典袋の表書きは宗教に合わせる"),

        // 出産祝い
        MarketRate(eventKind: .birth, relation: .family, rangeLabel: "1万〜3万円", note: "祖父母は5万円以上のことも"),
        MarketRate(eventKind: .birth, relation: .relative, rangeLabel: "5千〜1万円", note: ""),
        MarketRate(eventKind: .birth, relation: .friend, rangeLabel: "5千〜1万円", note: ""),
        MarketRate(eventKind: .birth, relation: .work, rangeLabel: "3千〜5千円", note: "連名の場合は1人あたり1千〜3千円"),
        MarketRate(eventKind: .birth, relation: .neighbor, rangeLabel: "3千〜5千円", note: ""),
        MarketRate(eventKind: .birth, relation: .other, rangeLabel: "3千〜1万円", note: ""),

        // 入学・卒業祝い
        MarketRate(eventKind: .entrance, relation: .family, rangeLabel: "1万〜3万円", note: "祖父母から孫へ。小学校入学は少なめのことも"),
        MarketRate(eventKind: .entrance, relation: .relative, rangeLabel: "5千〜1万円", note: ""),
        MarketRate(eventKind: .entrance, relation: .friend, rangeLabel: "3千〜5千円", note: ""),
        MarketRate(eventKind: .entrance, relation: .work, rangeLabel: "3千〜5千円", note: ""),
        MarketRate(eventKind: .entrance, relation: .neighbor, rangeLabel: "3千〜5千円", note: ""),
        MarketRate(eventKind: .entrance, relation: .other, rangeLabel: "3千〜1万円", note: ""),

        // 新築祝い
        MarketRate(eventKind: .newHome, relation: .family, rangeLabel: "3万〜10万円", note: ""),
        MarketRate(eventKind: .newHome, relation: .relative, rangeLabel: "1万〜3万円", note: ""),
        MarketRate(eventKind: .newHome, relation: .friend, rangeLabel: "5千〜1万円", note: ""),
        MarketRate(eventKind: .newHome, relation: .work, rangeLabel: "5千〜1万円", note: ""),
        MarketRate(eventKind: .newHome, relation: .neighbor, rangeLabel: "3千〜5千円", note: "火に関わる品（ライター等）は贈らない慣習に注意"),
        MarketRate(eventKind: .newHome, relation: .other, rangeLabel: "5千〜3万円", note: ""),

        // お見舞い
        MarketRate(eventKind: .getWell, relation: .family, rangeLabel: "5千〜1万円", note: ""),
        MarketRate(eventKind: .getWell, relation: .relative, rangeLabel: "5千〜1万円", note: ""),
        MarketRate(eventKind: .getWell, relation: .friend, rangeLabel: "3千〜5千円", note: ""),
        MarketRate(eventKind: .getWell, relation: .work, rangeLabel: "3千〜5千円", note: "連名のことも多い"),
        MarketRate(eventKind: .getWell, relation: .neighbor, rangeLabel: "3千〜5千円", note: ""),
        MarketRate(eventKind: .getWell, relation: .other, rangeLabel: "3千〜1万円", note: ""),
    ]

    static func rates(for kind: EventKind) -> [MarketRate] {
        all.filter { $0.eventKind == kind }
    }
}

// MARK: - サンプルデータ

enum SampleData {
    static func makeRecord() -> GiftRecord {
        let r = GiftRecord()
        r.eventTitle = "サンプル：〇〇さん結婚式"
        r.personName = "サンプル 花子"
        r.eventKind = .wedding
        r.relation = .friend
        r.direction = .given
        r.amount = 30000
        r.date = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        r.memo = "友人代表で受付も担当"
        return r
    }
}
