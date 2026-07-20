import Foundation
import SwiftData
import SwiftUI

// MARK: - 行事の種類

enum Occasion: String, CaseIterable, Identifiable, Codable {
    case nengajo, ochugen, oseibo, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nengajo: return "年賀状"
        case .ochugen: return "お中元"
        case .oseibo:  return "お歳暮"
        case .other:   return "その他"
        }
    }

    var icon: String {
        switch self {
        case .nengajo: return "envelope.fill"
        case .ochugen: return "gift.fill"
        case .oseibo:  return "gift.fill"
        case .other:   return "seal.fill"
        }
    }

    var color: Color {
        switch self {
        case .nengajo: return .nengaRed
        case .ochugen: return .green
        case .oseibo:  return .blue
        case .other:   return .brown
        }
    }
}

// MARK: - SwiftData モデル：宛先

@Model
final class Contact {
    var name: String = ""
    var address: String = ""
    var relationship: String = ""
    var memo: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \GiftLog.contact)
    var giftLogs: [GiftLog] = []

    init(name: String = "", address: String = "", relationship: String = "", memo: String = "") {
        self.name = name
        self.address = address
        self.relationship = relationship
        self.memo = memo
        self.createdAt = Date()
    }
}

// MARK: - SwiftData モデル：贈答記録

@Model
final class GiftLog {
    var occasionRaw: String = Occasion.nengajo.rawValue
    var year: Int = Calendar.current.component(.year, from: Date())
    var sent: Bool = false
    var received: Bool = false
    var memo: String = ""
    var contact: Contact?

    init(occasion: Occasion = .nengajo, year: Int = Calendar.current.component(.year, from: Date()),
         sent: Bool = false, received: Bool = false, memo: String = "", contact: Contact? = nil) {
        self.occasionRaw = occasion.rawValue
        self.year = year
        self.sent = sent
        self.received = received
        self.memo = memo
        self.contact = contact
    }

    var occasion: Occasion {
        get { Occasion(rawValue: occasionRaw) ?? .other }
        set { occasionRaw = newValue.rawValue }
    }
}

// MARK: - 現在年

func currentYear() -> Int {
    Calendar.current.component(.year, from: Date())
}

// MARK: - テーマカラー（New Year Red）

extension Color {
    static let nengaRed = Color(red: 0.7765, green: 0.1569, blue: 0.1569)
}

// MARK: - 日付フォーマット

func mediumDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy/M/d"
    return f.string(from: date)
}
