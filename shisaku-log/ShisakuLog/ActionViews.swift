import SwiftUI
import SwiftData
import UIKit

// MARK: - タブ3: 施策ノート

struct ActionListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrackedApp.createdAt) private var allApps: [TrackedApp]
    @Query(sort: \Action.date, order: .reverse) private var actions: [Action]
    @AppStorage("selectedAppId") private var selectedAppId = ""

    @State private var filter: ActionCategory?
    @State private var showAdd = false

    private var apps: [TrackedApp] { allApps.filter { !$0.isArchived } }
    private var selectedApp: TrackedApp? { resolveSelectedApp(apps, selectedAppId) }

    private var filtered: [Action] {
        guard let app = selectedApp else { return [] }
        return actions.filter {
            $0.appId == app.id && (filter == nil || $0.category == filter)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if apps.isEmpty {
                    ContentUnavailableView("アプリが未登録です", systemImage: "list.bullet.rectangle",
                                           description: Text("記録タブでアプリを追加してください"))
                } else {
                    VStack(spacing: 0) {
                        AppScopeHeader(apps: apps, selectedId: $selectedAppId)
                            .padding([.horizontal, .top])
                        categoryChips
                        List {
                            ForEach(filtered) { action in
                                NavigationLink {
                                    ActionDetailView(action: action)
                                } label: {
                                    ActionRow(action: action)
                                }
                            }
                            .onDelete(perform: delete)
                        }
                        .listStyle(.plain)
                        .overlay {
                            if filtered.isEmpty {
                                ContentUnavailableView("施策がありません", systemImage: "note.text",
                                                       description: Text("右上の＋から施策を追加できます"))
                            }
                        }
                    }
                }
            }
            .navigationTitle("施策ノート")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .disabled(selectedApp == nil)
                }
            }
            .sheet(isPresented: $showAdd) {
                if let app = selectedApp {
                    ActionEditView(appId: app.id)
                }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, label: "すべて")
                ForEach(ActionCategory.allCases) { category in
                    chip(category, label: category.label)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func chip(_ category: ActionCategory?, label: String) -> some View {
        let isOn = filter == category
        return Button {
            filter = category
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isOn ? Color.indigo : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filtered[index])
        }
    }
}

// MARK: - 施策の詳細（仮説 → 前後比較 → 振り返り）

struct ActionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var metrics: [DailyMetric]
    @Query private var apps: [TrackedApp]

    let action: Action

    @State private var showEdit = false
    @State private var confirmDelete = false

    private var appMetrics: [DailyMetric] {
        metrics.filter { $0.appId == action.appId }
    }

    private var appName: String {
        apps.first { $0.id == action.appId }?.name ?? "不明なアプリ"
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        CategoryChip(category: action.category)
                        Text("実施日 " + mediumDate(action.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(action.title)
                        .font(.title3.weight(.semibold))
                    Text(appName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            Section("内容") {
                Text(textOrPlaceholder(action.detail))
                    .foregroundStyle(hasText(action.detail) ? .primary : .secondary)
            }

            Section("仮説") {
                Text(textOrPlaceholder(action.hypothesis))
                    .foregroundStyle(hasText(action.hypothesis) ? .primary : .secondary)
            }

            Section {
                comparisonRow(kind: .revenue)
                comparisonRow(kind: .downloads)
            } header: {
                Text("前後比較（前7日 / 後7日）")
            } footer: {
                Text("実施日前日までの7日平均と、実施翌日からの7日平均です。数値がない日は除外しています。あくまで前後比較であり、施策の効果を保証するものではありません。")
            }

            Section("振り返り") {
                TextEditor(text: resultNoteBinding)
                    .frame(minHeight: 100)
                if action.needsReview {
                    Label("実施から14日以上たっています。振り返りを記入しましょう",
                          systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("施策の詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            ActionEditView(appId: action.appId, action: action)
        }
        .confirmationDialog("この施策を削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                context.delete(action)
                dismiss()
            }
        }
    }

    private var resultNoteBinding: Binding<String> {
        Binding(
            get: { action.resultNote ?? "" },
            set: { action.resultNote = $0.isEmpty ? nil : $0 }
        )
    }

    private func comparisonRow(kind: MetricKind) -> some View {
        let ba = Comparison.beforeAfter(actionDate: action.date,
                                        samples: appMetrics.samples(kind))
        return VStack(alignment: .leading, spacing: 4) {
            Text(kind.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(comparisonSummary(ba, unit: kind.unit))
                .font(.subheadline)
            if ba.before.sampleDays > 0 || ba.after.sampleDays > 0 {
                Text("対象日数: 前\(ba.before.sampleDays)日 / 後\(ba.after.sampleDays)日")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func hasText(_ s: String?) -> Bool {
        !(s ?? "").isEmpty
    }

    private func textOrPlaceholder(_ s: String?) -> String {
        hasText(s) ? (s ?? "") : "未記入"
    }
}

// MARK: - 施策の追加・編集

struct ActionEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let appId: UUID
    var action: Action?

    @State private var date: Date
    @State private var title: String
    @State private var category: ActionCategory
    @State private var detail: String
    @State private var hypothesis: String

    init(appId: UUID, action: Action? = nil) {
        self.appId = appId
        self.action = action
        _date = State(initialValue: action?.date ?? Day.today())
        _title = State(initialValue: action?.title ?? "")
        _category = State(initialValue: action?.category ?? .other)
        _detail = State(initialValue: action?.detail ?? "")
        _hypothesis = State(initialValue: action?.hypothesis ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("実施日", selection: $date, displayedComponents: .date)
                TextField("タイトル（例: ASOキーワード変更）", text: $title)
                Picker("カテゴリ", selection: $category) {
                    ForEach(ActionCategory.allCases) { c in
                        Text(c.label).tag(c)
                    }
                }
                Section("内容") {
                    TextField("何をどう変えたか", text: $detail, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("仮説") {
                    TextField("期待する効果", text: $hypothesis, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(action == nil ? "施策を追加" : "施策を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHypothesis = hypothesis.trimmingCharacters(in: .whitespacesAndNewlines)

        let target: Action
        if let action {
            target = action
        } else {
            target = Action(appId: appId, date: date, title: trimmedTitle, category: category)
            context.insert(target)
        }
        target.date = Day.start(date)
        target.title = trimmedTitle
        target.category = category
        target.detail = trimmedDetail.isEmpty ? nil : trimmedDetail
        target.hypothesis = trimmedHypothesis.isEmpty ? nil : trimmedHypothesis
        dismiss()
    }
}
