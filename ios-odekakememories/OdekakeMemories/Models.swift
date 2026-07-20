import Foundation
import SwiftData
import SwiftUI

// MARK: - おでかけモジュール（4カテゴリ共通）
//
// 4つのタブ（公園・遊び場／花見・紅葉／キャンプ・BBQ／観光スタンプ）は、
// 「場所名・訪問日・評価・メモ」という基本の形が共通しているため、
// あえて4つの似たようなモデルに分けず、1つの OutingVisit モデルを
// module（カテゴリ）で絞り込んで使い回す設計にしている。
// タブごとに見せるフィールドのラベル・選択肢だけを切り替える。

enum OutingModule: String, CaseIterable, Identifiable, Codable {
    case park, scenery, camp, sightseeing

    var id: String { rawValue }

    /// 一覧・共通表示用の正式名称
    var label: String {
        switch self {
        case .park:        return "公園・遊び場"
        case .scenery:      return "花見・紅葉スポット"
        case .camp:         return "キャンプ・BBQ場"
        case .sightseeing:  return "観光・お城スタンプ帳"
        }
    }

    /// タブバー表示用の短い名称
    var tabLabel: String {
        switch self {
        case .park:        return "公園・遊び場"
        case .scenery:      return "花見・紅葉"
        case .camp:         return "キャンプ・BBQ"
        case .sightseeing:  return "観光スタンプ"
        }
    }

    var icon: String {
        switch self {
        case .park:        return "figure.and.child.holdinghands"
        case .scenery:      return "leaf.fill"
        case .camp:         return "tent.fill"
        case .sightseeing:  return "building.columns.fill"
        }
    }

    var color: Color {
        switch self {
        case .park:        return .green
        case .scenery:      return .pink
        case .camp:         return .brown
        case .sightseeing:  return .blue
        }
    }

    /// サブ種別の選択肢。nil の場合はそのタブで種類ピッカーを表示しない
    var subKindOptions: [String]? {
        switch self {
        case .park:         return nil
        case .scenery:       return ["桜", "紅葉", "その他"]
        case .camp:          return ["キャンプ場", "BBQ場", "その他"]
        case .sightseeing:   return ["城", "観光地", "博物館・美術館", "その他"]
        }
    }

    var subKindPickerLabel: String { "種類" }

    /// detailNote フィールドのラベル（タブによって意味が異なる）
    var detailLabel: String {
        switch self {
        case .park:        return "設備"
        case .scenery:      return "見頃メモ"
        case .camp:         return "設備"
        case .sightseeing:  return "カテゴリメモ"
        }
    }

    var detailPlaceholder: String {
        switch self {
        case .park:        return "例：滑り台、砂場、トイレ、駐車場"
        case .scenery:      return "例：3月下旬〜4月上旬が見頃"
        case .camp:         return "例：直火可、シャワーあり、レンタル用品あり"
        case .sightseeing:  return "例：現存12天守の一つ、御城印あり"
        }
    }

    var namePlaceholder: String {
        switch self {
        case .park:        return "公園名（例：〇〇公園）"
        case .scenery:      return "スポット名（例：〇〇千本桜）"
        case .camp:         return "施設名（例：〇〇キャンプ場）"
        case .sightseeing:  return "名称（例：〇〇城）"
        }
    }

    var emptyDescription: String {
        switch self {
        case .park:        return "右上の＋から、公園・遊び場の記録を追加しましょう"
        case .scenery:      return "右上の＋から、お花見・紅葉スポットの記録を追加しましょう"
        case .camp:         return "右上の＋から、キャンプ・BBQ場の記録を追加しましょう"
        case .sightseeing:  return "右上の＋から、観光・お城の記録を追加しましょう"
        }
    }

    var searchPrompt: String { "名前・メモで検索" }
}

// MARK: - SwiftData モデル（4モジュール共通）

@Model
final class OutingVisit {
    var moduleRaw: String = OutingModule.park.rawValue
    /// 場所名
    var name: String = ""
    /// 訪問日
    var visitDate: Date = Date()
    /// 評価（0〜5）
    var rating: Int = 0
    /// タブによって意味が変わる自由記述（設備／見頃メモ／カテゴリメモ）
    var detailNote: String = ""
    /// サブ種別（桜／紅葉、城／観光地 など。park・camp では未使用の場合あり）
    var subKind: String = ""
    /// 自由メモ
    var memo: String = ""
    var createdAt: Date = Date()

    init() {}

    var module: OutingModule {
        get { OutingModule(rawValue: moduleRaw) ?? .park }
        set { moduleRaw = newValue.rawValue }
    }
}

// MARK: - 日付フォーマット

func mediumDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy/M/d"
    return f.string(from: date)
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
