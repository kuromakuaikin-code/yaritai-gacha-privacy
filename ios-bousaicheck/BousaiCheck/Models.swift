import Foundation
import SwiftData
import SwiftUI

// MARK: - 品目カテゴリー

enum ItemCategory: String, CaseIterable, Identifiable, Codable {
    case food, water, hygiene, info, valuables, forChildrenElderlyPets, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .food:                    return "非常食"
        case .water:                   return "飲料水"
        case .hygiene:                 return "衛生用品"
        case .info:                    return "情報収集"
        case .valuables:               return "貴重品"
        case .forChildrenElderlyPets:  return "子供・高齢者・ペット用品"
        case .other:                   return "その他"
        }
    }

    var icon: String {
        switch self {
        case .food:                    return "fork.knife"
        case .water:                   return "drop.fill"
        case .hygiene:                 return "bandage.fill"
        case .info:                    return "antenna.radiowaves.left.and.right"
        case .valuables:               return "wallet.pass.fill"
        case .forChildrenElderlyPets:  return "figure.2.and.child.holdinghands"
        case .other:                   return "shippingbox.fill"
        }
    }

    var color: Color {
        switch self {
        case .food:                    return .orange
        case .water:                   return .blue
        case .hygiene:                 return .mint
        case .info:                    return .purple
        case .valuables:               return .brown
        case .forChildrenElderlyPets:  return .pink
        case .other:                   return .gray
        }
    }
}

// MARK: - SwiftData モデル

/// 防災用品のチェックリスト項目。
/// `isPreset == true` は初回起動時に投入される標準項目（削除不可・チェックや編集は可）、
/// `isPreset == false` はユーザーが追加したカスタム項目（無料版は件数制限あり・削除可）。
@Model
final class ChecklistItem {
    var name: String = ""
    var categoryRaw: String = ItemCategory.other.rawValue
    /// 「準備済み」フラグ
    var isChecked: Bool = false
    /// 消費期限・使用期限（非常食・飲料水のローリングストック管理用。任意）
    var expiryDate: Date?
    var memo: String = ""
    var isPreset: Bool = false
    var order: Int = 0

    init() {}

    var category: ItemCategory {
        get { ItemCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

/// 家族の緊急連絡先・集合場所カード
@Model
final class EmergencyContact {
    var name: String = ""
    var relationship: String = ""
    var phone: String = ""
    /// 集合場所などの自由記述
    var meetingPoint: String = ""
    var memo: String = ""

    init() {}
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

// MARK: - 標準チェックリスト（初回起動時にのみ投入）

struct PresetChecklistEntry {
    let name: String
    let category: ItemCategory
    let order: Int
}

enum PresetChecklistData {
    /// 一般的な家庭向け防災グッズの目安一覧。地域・世帯構成により過不足があるため、
    /// あくまで出発点として利用者ごとに見直すことを想定している。
    static let items: [PresetChecklistEntry] = [
        // 飲料水
        PresetChecklistEntry(name: "水（1人1日3L×3日分が目安）", category: .water, order: 0),

        // 非常食
        PresetChecklistEntry(name: "非常食（3日分・加熱不要のものが安心）", category: .food, order: 1),
        PresetChecklistEntry(name: "カセットコンロ・ガスボンベ", category: .food, order: 2),

        // 衛生用品
        PresetChecklistEntry(name: "マスク", category: .hygiene, order: 3),
        PresetChecklistEntry(name: "ウェットティッシュ", category: .hygiene, order: 4),
        PresetChecklistEntry(name: "簡易トイレ", category: .hygiene, order: 5),
        PresetChecklistEntry(name: "常備薬・お薬手帳のコピー", category: .hygiene, order: 6),

        // 情報収集
        PresetChecklistEntry(name: "懐中電灯", category: .info, order: 7),
        PresetChecklistEntry(name: "携帯ラジオ", category: .info, order: 8),
        PresetChecklistEntry(name: "モバイルバッテリー", category: .info, order: 9),
        PresetChecklistEntry(name: "スマホ充電ケーブル", category: .info, order: 10),
        PresetChecklistEntry(name: "予備電池", category: .info, order: 11),

        // 貴重品
        PresetChecklistEntry(name: "現金（小銭を含む）", category: .valuables, order: 12),
        PresetChecklistEntry(name: "保険証・身分証のコピー", category: .valuables, order: 13),
        PresetChecklistEntry(name: "通帳・印鑑のコピー", category: .valuables, order: 14),

        // 子供・高齢者・ペット用品
        PresetChecklistEntry(name: "子供用おむつ・粉ミルク・離乳食", category: .forChildrenElderlyPets, order: 15),
        PresetChecklistEntry(name: "ペット用フード・水・トイレ用品", category: .forChildrenElderlyPets, order: 16),

        // その他
        PresetChecklistEntry(name: "ヘルメット・防災頭巾", category: .other, order: 17),
        PresetChecklistEntry(name: "軍手", category: .other, order: 18),
        PresetChecklistEntry(name: "雨具・防寒具（アルミブランケット等）", category: .other, order: 19),
    ]
}
