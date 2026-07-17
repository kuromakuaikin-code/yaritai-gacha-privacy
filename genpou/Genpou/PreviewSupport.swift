import Foundation
import SwiftData

/// #Preview 用のインメモリ ModelContainer とサンプルデータ
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: CompanyProfile.self, Project.self, SitePhoto.self,
            configurations: config
        )
        let context = container.mainContext

        let profile = CompanyProfile(companyName: "山田電設",
                                     representative: "山田 太郎",
                                     phone: "090-0000-0000",
                                     address: "愛知県名古屋市中区丸の内1-1-1")
        context.insert(profile)

        let project = Project(name: "○○ビル 3F 電気工事")
        project.siteAddress = "名古屋市中村区名駅2-2-2"
        project.clientName = "△△工務店"
        project.startDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        project.endDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())
        project.note = "分電盤更新と照明LED化"
        context.insert(project)

        for (index, tag) in [PhotoTag.before, .during, .during, .after].enumerated() {
            let photo = SitePhoto(fileName: "sample\(index).jpg",
                                  thumbFileName: nil,
                                  takenAt: Calendar.current.date(byAdding: .hour, value: -index, to: Date())!,
                                  tag: tag)
            photo.caption = index == 1 ? "分電盤 配線完了" : nil
            photo.project = project
            context.insert(photo)
        }
        return container
    }()

    /// オンボーディング確認用（データなし）
    static let emptyContainer: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: CompanyProfile.self, Project.self, SitePhoto.self,
            configurations: config
        )
    }()

    static var sampleProject: Project {
        let projects = (try? container.mainContext.fetch(FetchDescriptor<Project>())) ?? []
        return projects.first ?? Project(name: "サンプル案件")
    }

    static var samplePhoto: SitePhoto {
        let photos = (try? container.mainContext.fetch(FetchDescriptor<SitePhoto>())) ?? []
        return photos.first ?? SitePhoto(fileName: "sample.jpg", thumbFileName: nil)
    }
}
