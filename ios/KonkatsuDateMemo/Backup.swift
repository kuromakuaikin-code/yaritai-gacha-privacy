import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// Web版（date-memo/index.html）のバックアップJSONと互換の形式。
// Web版で書き出したファイルをそのまま読み込める（逆も可）。

struct BackupFile: Codable {
    struct PartnerDTO: Codable {
        var id: String?
        var name: String?
        var age: String?
        var job: String?
        var metVia: String?
        var likes: String?
        var ng: String?
        var memo: String?
        var status: String?
        var talked: [String: Bool]?
        var dates: [DateDTO]?
    }
    struct DateDTO: Codable {
        var id: String?
        var date: String?      // "yyyy-MM-dd"
        var place: String?
        var topics: String?
        var good: String?
        var bad: String?
        var next: String?
        var nextDate: String?  // "yyyy-MM-dd"
        var rating: Int?
    }
    struct MyTopicDTO: Codable {
        var id: String?
        var text: String?
        var note: String?
    }

    var partners: [PartnerDTO] = []
    var myTopics: [MyTopicDTO]?
    var premium: Bool?
    var adFree: Bool?
}

enum Backup {
    static func export(partners: [Partner], myTopics: [MyTopic],
                       premium: Bool, adFree: Bool) throws -> Data {
        var file = BackupFile()
        file.premium = premium
        file.adFree = adFree
        file.partners = partners.map { p in
            BackupFile.PartnerDTO(
                id: UUID().uuidString,
                name: p.name, age: p.age, job: p.job, metVia: p.metVia,
                likes: p.likes, ng: p.ng, memo: p.memo, status: p.statusRaw,
                talked: Dictionary(uniqueKeysWithValues: p.talked.map { ($0, true) }),
                dates: p.sortedDates.map { d in
                    BackupFile.DateDTO(
                        id: UUID().uuidString,
                        date: ISODay.string(d.date),
                        place: d.place, topics: d.topics, good: d.good, bad: d.bad,
                        next: d.next,
                        nextDate: d.nextDate.map { ISODay.string($0) },
                        rating: d.rating)
                })
        }
        file.myTopics = myTopics.sorted { $0.order < $1.order }.map {
            BackupFile.MyTopicDTO(id: $0.key, text: $0.text, note: $0.note)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    /// 既存データを全削除して置き換える
    static func restore(data: Data, context: ModelContext) throws -> Int {
        let file = try JSONDecoder().decode(BackupFile.self, from: data)

        try context.delete(model: Partner.self)
        try context.delete(model: MyTopic.self)

        for dto in file.partners {
            let p = Partner(name: dto.name ?? "")
            p.age = dto.age ?? ""
            p.job = dto.job ?? ""
            p.metVia = dto.metVia ?? ""
            p.likes = dto.likes ?? ""
            p.ng = dto.ng ?? ""
            p.memo = dto.memo ?? ""
            p.statusRaw = dto.status ?? PartnerStatus.active.rawValue
            p.talked = (dto.talked ?? [:]).filter { $0.value }.map { $0.key }
            for dd in dto.dates ?? [] {
                let r = DateRecord(date: ISODay.date(dd.date) ?? Date())
                r.place = dd.place ?? ""
                r.topics = dd.topics ?? ""
                r.good = dd.good ?? ""
                r.bad = dd.bad ?? ""
                r.next = dd.next ?? ""
                r.nextDate = ISODay.date(dd.nextDate)
                r.rating = dd.rating ?? 0
                p.dates.append(r)
            }
            context.insert(p)
        }
        for (i, t) in (file.myTopics ?? []).enumerated() {
            let m = MyTopic(text: t.text ?? "", note: t.note ?? "", order: i)
            if let id = t.id { m.key = id }
            context.insert(m)
        }
        try context.save()
        return file.partners.count
    }
}

// fileExporter 用のドキュメント
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
