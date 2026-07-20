import Foundation
import SwiftData
import SwiftUI

// MARK: - アプリのテーマカラー（金茶色 #9C6B1F 系）

extension Color {
    /// #9C6B1F (156, 107, 31)
    static let omamoriGold = Color(red: 156.0 / 255.0, green: 107.0 / 255.0, blue: 31.0 / 255.0)
}

// MARK: - 種類（お守り・御札・破魔矢・その他）

enum OmamoriKind: String, CaseIterable, Identifiable, Codable {
    case omamori, ofuda, hamaya, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .omamori: return "お守り"
        case .ofuda:   return "御札"
        case .hamaya:  return "破魔矢"
        case .other:   return "その他"
        }
    }

    var icon: String {
        switch self {
        case .omamori: return "seal.fill"
        case .ofuda:   return "rectangle.portrait.fill"
        case .hamaya:  return "arrow.up.forward"
        case .other:   return "questionmark.circle.fill"
        }
    }
}

// MARK: - ご利益・目的

enum OmamoriPurpose: String, CaseIterable, Identifiable, Codable {
    case kaiun, kotsu, enmusubi, kenko, gakugyo, anzan, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .kaiun:    return "開運招福"
        case .kotsu:    return "交通安全"
        case .enmusubi: return "縁結び"
        case .kenko:    return "健康祈願"
        case .gakugyo:  return "学業成就"
        case .anzan:    return "安産祈願"
        case .other:    return "その他"
        }
    }

    var icon: String {
        switch self {
        case .kaiun:    return "sparkles"
        case .kotsu:    return "car.fill"
        case .enmusubi: return "heart.fill"
        case .kenko:    return "cross.case.fill"
        case .gakugyo:  return "graduationcap.fill"
        case .anzan:    return "figure.child"
        case .other:    return "star.fill"
        }
    }
}

// MARK: - SwiftData モデル

@Model
final class OmamoriItem {
    var shrineName: String = ""
    var kindRaw: String = OmamoriKind.omamori.rawValue
    var purposeRaw: String = OmamoriPurpose.kaiun.rawValue
    var obtainedDate: Date = Date()
    var suggestedReturnDate: Date = Date()
    var isReturned: Bool = false
    var memo: String = ""
    var createdAt: Date = Date()

    init() {}

    var kind: OmamoriKind {
        get { OmamoriKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var purpose: OmamoriPurpose {
        get { OmamoriPurpose(rawValue: purposeRaw) ?? .other }
        set { purposeRaw = newValue.rawValue }
    }

    /// 返納時期を過ぎている（かつ未返納）かどうか
    var isDueForReturn: Bool {
        !isReturned && suggestedReturnDate <= Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400)
    }
}

/// 授与日から1年後を目安の返納日として算出する
func defaultReturnDate(from obtainedDate: Date) -> Date {
    Calendar.current.date(byAdding: .year, value: 1, to: obtainedDate) ?? obtainedDate
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

// MARK: - 作法ガイド（静的データ・一般的な目安）

struct GuideEntry: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

enum GuideData {
    static let entries: [GuideEntry] = [
        GuideEntry(
            title: "お守り・御札の返納方法",
            body: "授与された神社・お寺に持参し、境内の「古札納所」「返納所」などに納めるのが基本です。年末年始には「どんど焼き」（左義長）でお焚き上げされる地域も多くあります。遠方で直接持参できない場合は、郵送での返納を受け付けている神社・お寺もあるので、事前に確認しましょう。"
        ),
        GuideEntry(
            title: "違う神社・お寺に返してもよいか",
            body: "本来は授与された神社・お寺に返すのが望ましいとされますが、遠方などの事情で難しい場合は、同じ系統（神社なら神社、お寺ならお寺）の別の社寺に相談すると受け付けてくれることがあります。特に大きな神社・有名寺院では、他社寺のお守りでも受け入れている場合があります。訪問前に電話などで確認すると安心です。"
        ),
        GuideEntry(
            title: "返納の時期の目安",
            body: "「1年」が一般的な目安とされていますが、これは絶対的な決まりではありません。合格祈願や安産祈願など願いが成就した時点で感謝を込めて返納する考え方や、願いが叶うまで持ち続けてよいという考え方もあります。年始の初詣のタイミングで前年のお守りを返し、新しいお守りを受けるという流れが多く見られます。"
        ),
        GuideEntry(
            title: "複数の神社・お寺のお守りを一緒に持ってもよいか",
            body: "「神様同士がけんかする」といった俗説もありますが、複数のお守りを一緒に持つこと自体を明確に禁じている教義は一般的ではありません。それぞれの神社・お寺への感謝の気持ちを持って大切に扱うことが基本とされています。気になる場合は、授与された社寺に確認してみるとよいでしょう。"
        ),
        GuideEntry(
            title: "古いお守り・御札の処分方法",
            body: "家庭の燃えるゴミとして処分することは、一般的には避けるべきとされています。まずは授与された神社・お寺、または近隣の神社・お寺に相談し、古札納所やお焚き上げで供養してもらうのが基本です。どうしても持参が難しい場合は、白い紙に包んで塩で清めてから処分するなど、丁寧に扱う工夫をする方もいます。"
        ),
        GuideEntry(
            title: "お焚き上げ・どんど焼きについて",
            body: "「どんど焼き」は主に小正月（1月15日前後）に行われる火祭りの行事で、正月飾りとあわせて前年のお守り・御札をお焚き上げする地域の風習です。開催の有無や日程は神社・地域によって異なるため、事前に確認しておくと安心です。プラスチックや金属が使われているお守り・御札は、お焚き上げできない場合があるので注意しましょう。"
        ),
        GuideEntry(
            title: "お守りの正しい持ち方・保管方法",
            body: "お守りは、目的に応じて身につける（交通安全なら車内、学業成就なら鞄など）のが一般的です。持ち歩かない場合は、家の中の清潔で目線より高い場所に安置するとよいとされています。中身を開けたり、粗雑に扱ったりすることは避けましょう。"
        ),
    ]
}
