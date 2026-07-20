import Foundation
import SwiftData

// MARK: - バックアップ用JSON構造（4モジュール共通の1ファイル）

struct BackupAppliance: Codable {
    var name: String
    var purchaseDate: String
    var purchasePlace: String
    var warrantyYears: Int
    var price: Int?
    var memo: String
}

struct BackupMaintenanceTask: Codable {
    var name: String
    var lastDoneDate: String
    var intervalMonths: Int
    var memo: String
    var isPreset: Bool
}

struct BackupPlant: Codable {
    var name: String
    var species: String?
    var lastWateredDate: String
    var intervalDays: Int
    var memo: String
}

struct BackupSupply: Codable {
    var name: String
    var currentStock: Int
    var lowStockThreshold: Int
    var memo: String
}

struct BackupFile: Codable {
    var app = "KurashiAnshinBook"
    var version = 1
    var exportedAt: String
    var appliances: [BackupAppliance]
    var maintenanceTasks: [BackupMaintenanceTask]
    var plants: [BackupPlant]
    var supplies: [BackupSupply]
}

enum BackupService {
    static func export(appliances: [Appliance], tasks: [MaintenanceTask], plants: [Plant], supplies: [Supply]) -> Data? {
        let backup = BackupFile(
            exportedAt: ISODay.string(Date()),
            appliances: appliances.map {
                BackupAppliance(
                    name: $0.name,
                    purchaseDate: ISODay.string($0.purchaseDate),
                    purchasePlace: $0.purchasePlace,
                    warrantyYears: $0.warrantyYears,
                    price: $0.price,
                    memo: $0.memo
                )
            },
            maintenanceTasks: tasks.map {
                BackupMaintenanceTask(
                    name: $0.name,
                    lastDoneDate: ISODay.string($0.lastDoneDate),
                    intervalMonths: $0.intervalMonths,
                    memo: $0.memo,
                    isPreset: $0.isPreset
                )
            },
            plants: plants.map {
                BackupPlant(
                    name: $0.name,
                    species: $0.species,
                    lastWateredDate: ISODay.string($0.lastWateredDate),
                    intervalDays: $0.intervalDays,
                    memo: $0.memo
                )
            },
            supplies: supplies.map {
                BackupSupply(
                    name: $0.name,
                    currentStock: $0.currentStock,
                    lowStockThreshold: $0.lowStockThreshold,
                    memo: $0.memo
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(backup)
    }

    /// インポート件数（4モジュール合計）を返す。失敗時は nil
    @discardableResult
    static func importData(_ data: Data, into context: ModelContext) -> Int? {
        guard let backup = try? JSONDecoder().decode(BackupFile.self, from: data) else { return nil }

        for item in backup.appliances {
            let appliance = Appliance()
            appliance.name = item.name
            appliance.purchaseDate = ISODay.date(item.purchaseDate) ?? Date()
            appliance.purchasePlace = item.purchasePlace
            appliance.warrantyYears = item.warrantyYears
            appliance.price = item.price
            appliance.memo = item.memo
            context.insert(appliance)
        }

        for item in backup.maintenanceTasks {
            let task = MaintenanceTask()
            task.name = item.name
            task.lastDoneDate = ISODay.date(item.lastDoneDate) ?? Date()
            task.intervalMonths = item.intervalMonths
            task.memo = item.memo
            task.isPreset = item.isPreset
            context.insert(task)
        }

        for item in backup.plants {
            let plant = Plant()
            plant.name = item.name
            plant.species = item.species
            plant.lastWateredDate = ISODay.date(item.lastWateredDate) ?? Date()
            plant.intervalDays = item.intervalDays
            plant.memo = item.memo
            context.insert(plant)
        }

        for item in backup.supplies {
            let supply = Supply()
            supply.name = item.name
            supply.currentStock = item.currentStock
            supply.lowStockThreshold = item.lowStockThreshold
            supply.memo = item.memo
            context.insert(supply)
        }

        return backup.appliances.count + backup.maintenanceTasks.count + backup.plants.count + backup.supplies.count
    }
}
