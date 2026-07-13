import Foundation
import SwiftData
import SwiftUI

// MARK: - 施策カテゴリ

enum ActionCategory: String, CaseIterable, Identifiable {
    case aso, update, ad, price, content, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .aso:     return "ASO"
        case .update:  return "アップデート"
        case .ad:      return "広告"
        case .price:   return "価格"
        case .content: return "コンテンツ"
        case .other:   return "その他"
        }
    }

    var color: Color {
        switch self {
        case .aso:     return .blue
        case .update:  return .green
        case .ad:      return .purple
        case .price:   return .orange
        case .content: return .pink
        case .other:   return .gray
        }
    }
}

// MARK: - SwiftData モデル
// 仕様書の「App」は SwiftUI.App と衝突するため TrackedApp と命名。

@Model
final class TrackedApp {
    var id: UUID = UUID()
    var name: String = ""
    var platform: String?
    var releasedAt: Date?
    var isArchived: Bool = false
    /// 一覧の並び順を安定させるための登録日時（仕様外だが表示専用）
    var createdAt: Date = Date()

    init(name: String = "") {
        self.name = name
    }
}

@Model
final class DailyMetric {
    var id: UUID = UUID()
    var appId: UUID = UUID()
    /// 0:00 に正規化して保存。appId+date の重複は保存時のupsertで防ぐ
    /// （iOS 17 の SwiftData には複合ユニーク制約がないためコード側で保証）
    var date: Date = Date()
    var revenue: Double?
    var downloads: Int?
    var dau: Int?
    var memo: String?

    init(appId: UUID, date: Date) {
        self.appId = appId
        self.date = Day.start(date)
    }
}

@Model
final class Action {
    var id: UUID = UUID()
    var appId: UUID = UUID()
    var date: Date = Date()
    var title: String = ""
    var categoryRaw: String = ActionCategory.other.rawValue
    var detail: String?
    var hypothesis: String?
    var resultNote: String?

    init(appId: UUID, date: Date, title: String, category: ActionCategory) {
        self.appId = appId
        self.date = Day.start(date)
        self.title = title
        self.categoryRaw = category.rawValue
    }

    var category: ActionCategory {
        get { ActionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// 実施から14日たっても振り返り未記入ならバッジを出す
    var needsReview: Bool {
        (resultNote ?? "").isEmpty && Day.start(date) <= Day.add(Day.today(), -14)
    }
}

// MARK: - 共通ヘルパー

/// 選択中アプリの解決（保存されたIDが無効なら先頭のアプリにフォールバック）
func resolveSelectedApp(_ apps: [TrackedApp], _ selectedId: String) -> TrackedApp? {
    apps.first { $0.id.uuidString == selectedId } ?? apps.first
}

/// アプリ削除時に紐づく数値・施策も消す（appId参照のため手動カスケード）
func deleteAppCascade(_ app: TrackedApp, context: ModelContext) {
    let id = app.id
    try? context.delete(model: DailyMetric.self, where: #Predicate { $0.appId == id })
    try? context.delete(model: Action.self, where: #Predicate { $0.appId == id })
    context.delete(app)
}

extension Array where Element == DailyMetric {
    /// 前後比較・グラフ用に (日付, 値) のペア列へ変換
    func samples(_ kind: MetricKind) -> [(date: Date, value: Double?)] {
        map { ($0.date, kind == .revenue ? $0.revenue : $0.downloads.map(Double.init)) }
    }
}

// MARK: - 選択中アプリの切替ヘッダー（全タブ共通）

struct AppScopeHeader: View {
    let apps: [TrackedApp]
    @Binding var selectedId: String

    var body: some View {
        VStack(spacing: 0) {
            if !apps.isEmpty {
                Picker("アプリ", selection: $selectedId) {
                    ForEach(apps) { app in
                        Text(app.name).tag(app.id.uuidString)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .onAppear(perform: normalize)
        .onChange(of: apps.map(\.id)) { _, _ in normalize() }
    }

    private func normalize() {
        if !apps.contains(where: { $0.id.uuidString == selectedId }) {
            selectedId = apps.first?.id.uuidString ?? ""
        }
    }
}

// MARK: - 施策の行表示（記録タブ・施策ノートで共用）

struct ActionRow: View {
    let action: Action

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    CategoryChip(category: action.category)
                    Text(mediumDate(action.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(action.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            if action.needsReview {
                Text("振り返り未記入")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
            }
        }
        .contentShape(Rectangle())
    }
}

struct CategoryChip: View {
    let category: ActionCategory

    var body: some View {
        Text(category.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(category.color.opacity(0.15), in: Capsule())
            .foregroundStyle(category.color)
    }
}
