import Foundation
import SwiftData

// MARK: - バックアップ用JSON構造

struct BackupPet: Codable {
    var id: String
    var name: String
    var species: String
    var breed: String
    var birthday: String?
    var memo: String
}

struct BackupRecord: Codable {
    var petID: String
    var kind: String
    var date: String
    var detail: String
    var weightKg: Double?
    var hospitalName: String
    var nextDueDate: String?
    var memo: String
}

struct BackupFile: Codable {
    var app = "PetHealthMemo"
    var version = 1
    var exportedAt: String
    var pets: [BackupPet]
    var records: [BackupRecord]
}

struct BackupImportResult {
    var petCount: Int
    var recordCount: Int
}

enum BackupService {
    static func export(pets: [Pet], records: [HealthRecord]) -> Data? {
        let backup = BackupFile(
            exportedAt: ISODay.string(Date()),
            pets: pets.map {
                BackupPet(
                    id: $0.id.uuidString,
                    name: $0.name,
                    species: $0.speciesRaw,
                    breed: $0.breed,
                    birthday: $0.birthday.map { ISODay.string($0) },
                    memo: $0.memo
                )
            },
            records: records.map {
                BackupRecord(
                    petID: $0.pet?.id.uuidString ?? "",
                    kind: $0.kindRaw,
                    date: ISODay.string($0.date),
                    detail: $0.detail,
                    weightKg: $0.weightKg,
                    hospitalName: $0.hospitalName,
                    nextDueDate: $0.nextDueDate.map { ISODay.string($0) },
                    memo: $0.memo
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(backup)
    }

    /// インポート結果（ペット数・記録数）を返す。失敗時は nil
    @discardableResult
    static func importData(_ data: Data, into context: ModelContext) -> BackupImportResult? {
        guard let backup = try? JSONDecoder().decode(BackupFile.self, from: data) else { return nil }

        var petByOldID: [String: Pet] = [:]
        for item in backup.pets {
            let pet = Pet()
            pet.name = item.name
            pet.speciesRaw = item.species
            pet.breed = item.breed
            pet.birthday = ISODay.date(item.birthday)
            pet.memo = item.memo
            context.insert(pet)
            petByOldID[item.id] = pet
        }

        for item in backup.records {
            let record = HealthRecord()
            record.pet = petByOldID[item.petID]
            record.kindRaw = item.kind
            record.date = ISODay.date(item.date) ?? Date()
            record.detail = item.detail
            record.weightKg = item.weightKg
            record.hospitalName = item.hospitalName
            record.nextDueDate = ISODay.date(item.nextDueDate)
            record.memo = item.memo
            context.insert(record)
        }

        return BackupImportResult(petCount: backup.pets.count, recordCount: backup.records.count)
    }
}
