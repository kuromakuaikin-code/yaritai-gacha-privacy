import Foundation
import SwiftData

// MARK: - テストデータ投入（成功基準1の検証用）
// アプリ2本 × 30日分の数値 × 施策3件を生成する。
// 記録タブの「…」メニュー、または初回起動の空状態から実行できる。

enum TestData {
    struct ActionSpec {
        let offset: Int          // 今日から何日前に実施したか（負の値）
        let title: String
        let category: ActionCategory
        let hypothesis: String
        let boost: Double        // 実施日以降の数値に掛ける倍率（前後比較が見えるように）
        let resultNote: String?  // nil なら振り返り未記入（バッジ確認用）
    }

    static func insert(into context: ModelContext) {
        let existingNames = ((try? context.fetch(FetchDescriptor<TrackedApp>())) ?? []).map(\.name)
        var rng = SeededRandom(state: 20_260_713)
        let today = Day.today()

        func makeApp(name: String, platform: String,
                     baseRevenue: Double, baseDownloads: Double,
                     actionSpecs: [ActionSpec], missingDays: Set<Int>) {
            // 二重投入を防ぐ（同名アプリがあればスキップ）
            guard !existingNames.contains(name) else { return }

            let app = TrackedApp(name: name)
            app.platform = platform
            app.releasedAt = Day.add(today, -120)
            context.insert(app)

            for offset in -29...0 {
                // 欠損日をわざと作る（前後比較の「欠損日は除外」の検証用）
                if missingDays.contains(offset) { continue }
                var boost = 1.0
                for spec in actionSpecs where offset >= spec.offset {
                    boost *= spec.boost
                }
                let metric = DailyMetric(appId: app.id, date: Day.add(today, offset))
                metric.revenue = (baseRevenue * boost * (0.8 + rng.next() * 0.4)).rounded()
                metric.downloads = Int((baseDownloads * boost * (0.7 + rng.next() * 0.6)).rounded())
                metric.dau = Int((baseDownloads * 8 * boost * (0.8 + rng.next() * 0.4)).rounded())
                context.insert(metric)
            }

            for spec in actionSpecs {
                let action = Action(appId: app.id, date: Day.add(today, spec.offset),
                                    title: spec.title, category: spec.category)
                action.hypothesis = spec.hypothesis
                action.detail = "（テストデータ）"
                action.resultNote = spec.resultNote
                context.insert(action)
            }
        }

        makeApp(
            name: "やりたいガチャ",
            platform: "iOS",
            baseRevenue: 320,
            baseDownloads: 12,
            actionSpecs: [
                ActionSpec(offset: -20, title: "ASOキーワード変更", category: .aso,
                           hypothesis: "検索流入が増えてDLが1.2倍になる", boost: 1.25,
                           resultNote: "前後で数値が上向いた。もう少し様子を見る。"),
                ActionSpec(offset: -12, title: "アップデートv1.2公開", category: .update,
                           hypothesis: "不具合修正で評価と継続率が上がる", boost: 1.1,
                           resultNote: nil),
                ActionSpec(offset: -5, title: "SNSで紹介投稿", category: .content,
                           hypothesis: "一時的にDLが跳ねる", boost: 1.15,
                           resultNote: nil),
            ],
            missingDays: [-27, -14]
        )

        makeApp(
            name: "盆踊りナビ愛知",
            platform: "Web",
            baseRevenue: 150,
            baseDownloads: 30,
            actionSpecs: [
                ActionSpec(offset: -18, title: "スクショと説明文を刷新", category: .aso,
                           hypothesis: "ストアの転換率が上がる", boost: 1.15,
                           resultNote: nil),
                ActionSpec(offset: -10, title: "紹介記事を公開", category: .content,
                           hypothesis: "検索流入が増える", boost: 1.2,
                           resultNote: nil),
                ActionSpec(offset: -4, title: "広告配信を開始", category: .ad,
                           hypothesis: "DLが1.3倍になる", boost: 1.3,
                           resultNote: nil),
            ],
            missingDays: [-22, -9]
        )
    }
}
