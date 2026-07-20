import Foundation
import SwiftData
import SwiftUI

// MARK: - モジュール1: 家電の保証期限管理

@Model
final class Appliance {
    var name: String = ""
    var purchaseDate: Date = Date()
    var purchasePlace: String = ""
    var warrantyYears: Int = 1
    var price: Int?
    var memo: String = ""
    var createdAt: Date = Date()

    init() {}

    /// 保証期限日（購入日 + 保証年数）
    var warrantyEndDate: Date {
        Calendar.current.date(byAdding: .year, value: warrantyYears, to: purchaseDate) ?? purchaseDate
    }
}

// MARK: - モジュール2: 住まいのメンテナンス記録

@Model
final class MaintenanceTask {
    var name: String = ""
    var lastDoneDate: Date = Date()
    var intervalMonths: Int = 1
    var memo: String = ""
    /// 初回起動時に投入される標準タスク（削除・編集は可。無料版の件数制限の対象外）
    var isPreset: Bool = false
    var createdAt: Date = Date()

    init() {}

    /// 次回目安日（前回実施日 + 周期月数）
    var nextDueDate: Date {
        Calendar.current.date(byAdding: .month, value: intervalMonths, to: lastDoneDate) ?? lastDoneDate
    }
}

// MARK: - モジュール3: 観葉植物の水やり管理

@Model
final class Plant {
    var name: String = ""
    var species: String?
    var lastWateredDate: Date = Date()
    var intervalDays: Int = 7
    var memo: String = ""
    var createdAt: Date = Date()

    init() {}

    /// 次回水やり目安日（前回水やり日 + 周期日数）
    var nextWaterDate: Date {
        Calendar.current.date(byAdding: .day, value: intervalDays, to: lastWateredDate) ?? lastWateredDate
    }
}

// MARK: - モジュール4: 日用品の在庫管理

@Model
final class Supply {
    var name: String = ""
    var currentStock: Int = 0
    var lowStockThreshold: Int = 1
    var memo: String = ""
    var createdAt: Date = Date()

    init() {}

    var isLowStock: Bool { currentStock <= lowStockThreshold }
}

// MARK: - 日付フォーマット

func mediumDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy/M/d"
    return f.string(from: date)
}

func yen(_ amount: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return "¥" + (formatter.string(from: NSNumber(value: amount)) ?? "\(amount)")
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

// MARK: - 期限までの日数・ステータス表示

/// 今日から指定日までの日数（過ぎていればマイナス）
func daysUntil(_ date: Date) -> Int {
    let cal = Calendar.current
    let start = cal.startOfDay(for: Date())
    let end = cal.startOfDay(for: date)
    return cal.dateComponents([.day], from: start, to: end).day ?? 0
}

/// 期限までの日数に応じた表示色。期限切れ・30日以内は赤、90日以内は橙、それ以外は標準色
/// （家電の保証期限・住まいのメンテナンスで共通利用）
func dueStatusColor(daysUntil days: Int) -> Color {
    if days <= 30 { return .red }
    if days <= 90 { return .orange }
    return .primary
}

func dueStatusLabel(daysUntil days: Int) -> String {
    if days < 0 { return "期限切れ（\(-days)日経過）" }
    if days == 0 { return "本日が期限" }
    return "あと\(days)日"
}

/// 水やり用のステータス色（期限切れ・当日のみ赤、それ以外は標準色）
func waterStatusColor(daysUntil days: Int) -> Color {
    days <= 0 ? .red : .primary
}

func waterStatusLabel(daysUntil days: Int) -> String {
    if days < 0 { return "水やり忘れ（\(-days)日超過）" }
    if days == 0 { return "本日が目安" }
    return "あと\(days)日"
}

// MARK: - メンテナンス標準タスク（初回起動時にのみ投入）

struct PresetMaintenanceEntry {
    let name: String
    let intervalMonths: Int
}

enum PresetMaintenanceData {
    /// 一般的な戸建て・集合住宅向けの目安。住まいの設備構成により過不足があるため、
    /// あくまで出発点として利用者ごとに見直すことを想定している。
    static let items: [PresetMaintenanceEntry] = [
        PresetMaintenanceEntry(name: "エアコンフィルターの掃除", intervalMonths: 1),
        PresetMaintenanceEntry(name: "排水口・排水トラップのヌメリ取り", intervalMonths: 1),
        PresetMaintenanceEntry(name: "換気扇フィルターの掃除", intervalMonths: 3),
        PresetMaintenanceEntry(name: "浴室換気扇の掃除", intervalMonths: 3),
        PresetMaintenanceEntry(name: "窓のパッキン・サッシのカビ点検", intervalMonths: 6),
        PresetMaintenanceEntry(name: "エアコン室外機まわりの清掃", intervalMonths: 6),
        PresetMaintenanceEntry(name: "火災報知器（火災警報器）の電池・動作確認", intervalMonths: 12),
        PresetMaintenanceEntry(name: "給湯器の点検", intervalMonths: 12),
    ]
}

// MARK: - 初回起動時の標準データ投入

enum PresetSeeder {
    /// メンテナンスタスクの標準データを、まだ1件も投入されていない場合にのみ登録する（冪等）
    @MainActor
    static func seedMaintenanceTasksIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<MaintenanceTask>(
            predicate: #Predicate { $0.isPreset == true }
        )
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        let today = Date()
        for entry in PresetMaintenanceData.items {
            let task = MaintenanceTask()
            task.name = entry.name
            task.lastDoneDate = today
            task.intervalMonths = entry.intervalMonths
            task.memo = ""
            task.isPreset = true
            context.insert(task)
        }
    }
}
