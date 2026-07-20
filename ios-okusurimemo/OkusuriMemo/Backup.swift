import Foundation
import SwiftData

// MARK: - バックアップ用JSON構造

struct BackupIntakeLog: Codable {
    var date: String
    var timing: String
    var taken: Bool
}

struct BackupMedication: Codable {
    var name: String
    var dosage: String
    var timing: [String]
    var hospitalName: String
    var startDate: String
    var endDate: String?
    var memo: String
    var logs: [BackupIntakeLog]
}

struct BackupMember: Codable {
    var name: String
    var relation: String
    var memo: String
    var medications: [BackupMedication]
}

struct BackupFile: Codable {
    var app = "OkusuriMemo"
    var version = 1
    var exportedAt: String
    var members: [BackupMember]
}

enum BackupService {
    static func export(members: [FamilyMember]) -> Data? {
        let backup = BackupFile(
            exportedAt: ISODay.string(Date()),
            members: members.map { member in
                BackupMember(
                    name: member.name,
                    relation: member.relation,
                    memo: member.memo,
                    medications: (member.medications ?? []).map { med in
                        BackupMedication(
                            name: med.name,
                            dosage: med.dosage,
                            timing: med.timingRaw,
                            hospitalName: med.hospitalName,
                            startDate: ISODay.string(med.startDate),
                            endDate: med.endDate.map { ISODay.string($0) },
                            memo: med.memo,
                            logs: (med.logs ?? []).map { log in
                                BackupIntakeLog(
                                    date: ISODay.string(log.date),
                                    timing: log.timingRaw,
                                    taken: log.taken
                                )
                            }
                        )
                    }
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(backup)
    }

    /// インポートしたお薬件数を返す。失敗時は nil
    @discardableResult
    static func importData(_ data: Data, into context: ModelContext) -> Int? {
        guard let backup = try? JSONDecoder().decode(BackupFile.self, from: data) else { return nil }
        var medicationCount = 0
        for backupMember in backup.members {
            let member = FamilyMember()
            member.name = backupMember.name
            member.relation = backupMember.relation
            member.memo = backupMember.memo
            context.insert(member)

            for backupMedication in backupMember.medications {
                let medication = Medication()
                medication.member = member
                medication.name = backupMedication.name
                medication.dosage = backupMedication.dosage
                medication.timingRaw = backupMedication.timing
                medication.hospitalName = backupMedication.hospitalName
                medication.startDate = ISODay.date(backupMedication.startDate) ?? Date()
                medication.endDate = ISODay.date(backupMedication.endDate)
                medication.memo = backupMedication.memo
                context.insert(medication)
                medicationCount += 1

                for backupLog in backupMedication.logs {
                    let log = IntakeLog()
                    log.medication = medication
                    log.date = ISODay.date(backupLog.date) ?? Date()
                    log.timingRaw = backupLog.timing
                    log.taken = backupLog.taken
                    context.insert(log)
                }
            }
        }
        return medicationCount
    }
}
