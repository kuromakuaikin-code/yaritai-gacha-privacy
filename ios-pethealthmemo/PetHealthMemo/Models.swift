import Foundation
import SwiftData
import SwiftUI

// MARK: - ペットの種類

enum PetSpecies: String, CaseIterable, Identifiable, Codable {
    case dog, cat, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dog:   return "犬"
        case .cat:   return "猫"
        case .other: return "その他"
        }
    }

    var icon: String {
        switch self {
        case .dog:   return "dog.fill"
        case .cat:   return "cat.fill"
        case .other: return "pawprint.fill"
        }
    }
}

// MARK: - 記録の種類

enum HealthRecordKind: String, CaseIterable, Identifiable, Codable {
    case vaccine, checkup, weight, grooming, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vaccine:  return "ワクチン接種"
        case .checkup:  return "通院・健診"
        case .weight:   return "体重測定"
        case .grooming: return "トリミング"
        case .other:    return "その他"
        }
    }

    var icon: String {
        switch self {
        case .vaccine:  return "syringe.fill"
        case .checkup:  return "stethoscope"
        case .weight:   return "scalemass.fill"
        case .grooming: return "scissors"
        case .other:    return "pawprint.fill"
        }
    }

    var color: Color {
        switch self {
        case .vaccine:  return .red
        case .checkup:  return .blue
        case .weight:   return .green
        case .grooming: return .purple
        case .other:    return .brown
        }
    }

    /// この種類の記録に「次回予定日」の意味があるか（予定タブでの案内文に利用）
    var hasTypicalDueDate: Bool {
        switch self {
        case .vaccine, .checkup: return true
        default: return false
        }
    }
}

// MARK: - SwiftData モデル

@Model
final class Pet {
    /// バックアップJSONでの紐付け用（SwiftDataの永続ID自体はJSONに出力できないため独自に保持）
    var id: UUID = UUID()
    var name: String = ""
    var speciesRaw: String = PetSpecies.dog.rawValue
    var breed: String = ""
    var birthday: Date?
    var memo: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \HealthRecord.pet)
    var records: [HealthRecord]? = []

    init() {}

    var species: PetSpecies {
        get { PetSpecies(rawValue: speciesRaw) ?? .other }
        set { speciesRaw = newValue.rawValue }
    }
}

@Model
final class HealthRecord {
    var pet: Pet?
    var kindRaw: String = HealthRecordKind.checkup.rawValue
    var date: Date = Date()
    var detail: String = ""
    var weightKg: Double?
    var hospitalName: String = ""
    var nextDueDate: Date?
    var memo: String = ""
    var createdAt: Date = Date()

    init() {}

    var kind: HealthRecordKind {
        get { HealthRecordKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }
}

// MARK: - フォーマット

func mediumDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy/M/d"
    return f.string(from: date)
}

func weightLabel(_ kg: Double) -> String {
    if kg == kg.rounded() {
        return String(format: "%.0fkg", kg)
    }
    return String(format: "%.1fkg", kg)
}

/// 今日からの日数差に応じた案内文（マイナスは超過）
func daysUntilLabel(_ date: Date) -> String {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let target = cal.startOfDay(for: date)
    let days = cal.dateComponents([.day], from: today, to: target).day ?? 0
    if days == 0 { return "本日" }
    if days > 0 { return "あと\(days)日" }
    return "\(-days)日超過"
}

func isOverdue(_ date: Date) -> Bool {
    Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
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

// MARK: - サンプルデータ

enum SampleData {
    static func makePet() -> Pet {
        let p = Pet()
        p.name = "サンプル：ポチ"
        p.species = .dog
        p.breed = "柴犬"
        p.birthday = Calendar.current.date(byAdding: .year, value: -2, to: Date())
        p.memo = "元気いっぱい"
        return p
    }
}
