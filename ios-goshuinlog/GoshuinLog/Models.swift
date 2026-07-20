import Foundation
import SwiftData
import SwiftUI

// MARK: - 参拝先の種類

enum PlaceType: String, CaseIterable, Identifiable, Codable {
    case shrine, temple

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shrine: return "神社"
        case .temple: return "寺"
        }
    }

    var icon: String {
        switch self {
        case .shrine: return "building.columns.fill"
        case .temple: return "building.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .shrine: return .toriiRed
        case .temple: return .brown
        }
    }
}

// MARK: - 祈願・参拝の目的

enum WishType: String, CaseIterable, Identifiable, Codable {
    case openLuck, enmusubi, gakugyo, health, business, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .openLuck: return "開運招福"
        case .enmusubi: return "縁結び"
        case .gakugyo:  return "学業成就"
        case .health:   return "健康祈願"
        case .business: return "商売繁盛"
        case .other:    return "その他"
        }
    }

    var icon: String {
        switch self {
        case .openLuck: return "sparkles"
        case .enmusubi: return "heart.fill"
        case .gakugyo:  return "graduationcap.fill"
        case .health:   return "cross.case.fill"
        case .business: return "yensign.circle.fill"
        case .other:    return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .openLuck: return .orange
        case .enmusubi: return .pink
        case .gakugyo:  return .blue
        case .health:   return .green
        case .business: return .purple
        case .other:    return .gray
        }
    }
}

// MARK: - SwiftData モデル

@Model
final class GoshuinEntry {
    var placeName: String = ""
    var placeTypeRaw: String = PlaceType.shrine.rawValue
    var prefecture: String = ""
    var visitDate: Date = Date()
    var fee: Int = 0
    var wishTypeRaw: String = WishType.openLuck.rawValue
    var rating: Int = 0
    var memo: String = ""
    var createdAt: Date = Date()

    init() {}

    var placeType: PlaceType {
        get { PlaceType(rawValue: placeTypeRaw) ?? .shrine }
        set { placeTypeRaw = newValue.rawValue }
    }

    var wishType: WishType {
        get { WishType(rawValue: wishTypeRaw) ?? .other }
        set { wishTypeRaw = newValue.rawValue }
    }
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

// MARK: - 都道府県データ（訪問カバレッジ集計用）

enum PrefectureData {
    /// 47都道府県（北海道〜沖縄）。集計タブの「訪れた都道府県」カバレッジの母数として使用
    static let all: [String] = [
        "北海道",
        "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県",
        "岐阜県", "静岡県", "愛知県", "三重県",
        "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県",
        "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県",
        "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県",
        "沖縄県",
    ]

    static let count = all.count

    static let set = Set(all)
}

// MARK: - サンプルデータ

enum SampleData {
    static func makeEntry() -> GoshuinEntry {
        let e = GoshuinEntry()
        e.placeName = "サンプル：〇〇神社"
        e.placeType = .shrine
        e.prefecture = "愛知県"
        e.visitDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        e.fee = 500
        e.wishType = .openLuck
        e.rating = 4
        e.memo = "紺地に金の墨書き、中央に大きな朱印。参道の紅葉がきれいだった"
        return e
    }
}
