import SwiftUI
import SwiftData
import UIKit

// MARK: - タブ1: 記録（ホーム）
// 今日の数値入力を最上部に置き、起動から3タップ（収益→DL→保存）で完了する導線。

struct RecordView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrackedApp.createdAt) private var allApps: [TrackedApp]
    @Query private var metrics: [DailyMetric]
    @Query(sort: \Action.date, order: .reverse) private var actions: [Action]
    @AppStorage("selectedAppId") private var selectedAppId = ""

    @State private var targetDay = Day.today()
    @State private var revenueText = ""
    @State private var downloadsText = ""
    @State private var dauText = ""
    @State private var memoText = ""
    @State private var showOptionalFields = false
    @State private var showSavedToast = false
    @State private var saveCount = 0

    @State private var showAppManager = false
    @State private var showActionEditor = false

    @FocusState private var focus: Field?

    enum Field: Hashable {
        case revenue, downloads, dau, memo
    }

    private var apps: [TrackedApp] { allApps.filter { !$0.isArchived } }
    private var selectedApp: TrackedApp? { resolveSelectedApp(apps, selectedAppId) }

    private var recentActions: [Action] {
        guard let app = selectedApp else { return [] }
        return Array(actions.filter { $0.appId == app.id }.prefix(5))
    }

    private var yesterdayMissing: Bool {
        guard let app = selectedApp else { return false }
        let yesterday = Day.add(Day.today(), -1)
        return !metrics.contains { $0.appId == app.id && Day.start($0.date) == yesterday }
    }

    var body: some View {
        NavigationStack {
            Group {
                if apps.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("記録")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showAppManager = true
                        } label: {
                            Label("アプリを管理", systemImage: "square.grid.2x2")
                        }
                        Button {
                            TestData.insert(into: context)
                        } label: {
                            Label("テストデータを投入", systemImage: "wand.and.stars")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("閉じる") { focus = nil }
                }
            }
            .sheet(isPresented: $showAppManager) {
                AppManagerView()
            }
            .sheet(isPresented: $showActionEditor) {
                if let app = selectedApp {
                    ActionEditView(appId: app.id)
                }
            }
        }
    }

    // MARK: 中身

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppScopeHeader(apps: apps, selectedId: $selectedAppId)
                inputCard
                actionsSection
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.success, trigger: saveCount)
        .onAppear(perform: loadFields)
        .onChange(of: selectedApp?.id) { _, _ in
            targetDay = Day.today()
            loadFields()
        }
        .onChange(of: targetDay) { _, _ in loadFields() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("アプリが未登録です", systemImage: "plus.app")
        } description: {
            Text("数値を記録するアプリを追加してください")
        } actions: {
            Button("アプリを追加") { showAppManager = true }
                .buttonStyle(.borderedProminent)
            Button("テストデータを投入") { TestData.insert(into: context) }
        }
    }

    // MARK: 数値入力カード

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(relativeDayLabel(targetDay))の数値")
                    .font(.headline)
                Spacer()
                DatePicker("入力する日", selection: $targetDay, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }

            HStack(alignment: .top, spacing: 12) {
                numberField("収益（円）", text: $revenueText, field: .revenue, keyboard: .decimalPad)
                numberField("DL数", text: $downloadsText, field: .downloads, keyboard: .numberPad)
            }

            DisclosureGroup(isExpanded: $showOptionalFields) {
                VStack(alignment: .leading, spacing: 8) {
                    numberField("DAU", text: $dauText, field: .dau, keyboard: .numberPad)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("メモ")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("気づいたこと", text: $memoText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .focused($focus, equals: .memo)
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("DAU・メモ（任意）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: save) {
                Text("保存")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedApp == nil)

            if showSavedToast {
                Label("保存しました", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }

            if yesterdayMissing && Day.calendar.isDateInToday(targetDay) {
                Button {
                    targetDay = Day.add(Day.today(), -1)
                } label: {
                    Label("昨日の分を入力", systemImage: "arrow.uturn.backward")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func numberField(_ title: String, text: Binding<String>, field: Field,
                             keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("未入力", text: text)
                .keyboardType(keyboard)
                .textFieldStyle(.roundedBorder)
                .focused($focus, equals: field)
        }
    }

    // MARK: 直近の施策

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("直近の施策")
                    .font(.headline)
                Spacer()
                Button {
                    showActionEditor = true
                } label: {
                    Label("追加", systemImage: "plus")
                        .font(.subheadline)
                }
            }
            if recentActions.isEmpty {
                Text("まだ施策がありません。「追加」から最初の施策を記録しましょう")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(recentActions) { action in
                NavigationLink {
                    ActionDetailView(action: action)
                } label: {
                    ActionRow(action: action)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 読み込みと保存

    private func loadFields() {
        guard let app = selectedApp else {
            revenueText = ""; downloadsText = ""; dauText = ""; memoText = ""
            return
        }
        let day = Day.start(targetDay)
        let metric = metrics.first { $0.appId == app.id && Day.start($0.date) == day }
        revenueText = metric?.revenue.map { plainNumber($0) } ?? ""
        downloadsText = metric?.downloads.map(String.init) ?? ""
        dauText = metric?.dau.map(String.init) ?? ""
        memoText = metric?.memo ?? ""
        if !dauText.isEmpty || !memoText.isEmpty {
            showOptionalFields = true
        }
    }

    private func save() {
        guard let app = selectedApp else { return }
        let day = Day.start(targetDay)
        // appId+date は日単位でユニーク: 既存があれば上書き（upsert）
        let metric: DailyMetric
        if let existing = metrics.first(where: { $0.appId == app.id && Day.start($0.date) == day }) {
            metric = existing
        } else {
            metric = DailyMetric(appId: app.id, date: day)
            context.insert(metric)
        }
        metric.revenue = parseDouble(revenueText)
        metric.downloads = parseInt(downloadsText)
        metric.dau = parseInt(dauText)
        let memo = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        metric.memo = memo.isEmpty ? nil : memo

        focus = nil
        saveCount += 1
        withAnimation { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showSavedToast = false }
        }
    }
}

// MARK: - アプリ管理

struct AppManagerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TrackedApp.createdAt) private var apps: [TrackedApp]
    @State private var editingApp: TrackedApp?
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(apps) { app in
                    Button {
                        editingApp = app
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .foregroundStyle(.primary)
                                Text(subtitle(app))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if app.isArchived {
                                Text("アーカイブ")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.15), in: Capsule())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .overlay {
                if apps.isEmpty {
                    ContentUnavailableView("アプリがありません", systemImage: "plus.app",
                                           description: Text("右上の＋からアプリを追加できます"))
                }
            }
            .navigationTitle("アプリを管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完了") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editingApp) { app in
                AppEditView(app: app)
            }
            .sheet(isPresented: $showAdd) {
                AppEditView(app: nil)
            }
        }
    }

    private func subtitle(_ app: TrackedApp) -> String {
        var parts: [String] = []
        if let p = app.platform, !p.isEmpty { parts.append(p) }
        if let r = app.releasedAt { parts.append("リリース " + mediumDate(r)) }
        return parts.isEmpty ? "詳細未設定" : parts.joined(separator: " / ")
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            deleteAppCascade(apps[index], context: context)
        }
    }
}

struct AppEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let app: TrackedApp?

    @State private var name: String
    @State private var platform: String
    @State private var hasReleaseDate: Bool
    @State private var releasedAt: Date
    @State private var isArchived: Bool

    private static let platforms = ["iOS", "Android", "Web"]

    init(app: TrackedApp?) {
        self.app = app
        _name = State(initialValue: app?.name ?? "")
        _platform = State(initialValue: app?.platform ?? "")
        _hasReleaseDate = State(initialValue: app?.releasedAt != nil)
        _releasedAt = State(initialValue: app?.releasedAt ?? Day.today())
        _isArchived = State(initialValue: app?.isArchived ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("アプリ名", text: $name)
                Picker("プラットフォーム", selection: $platform) {
                    Text("未設定").tag("")
                    ForEach(Self.platforms, id: \.self) { p in
                        Text(p).tag(p)
                    }
                }
                Toggle("リリース日を設定", isOn: $hasReleaseDate)
                if hasReleaseDate {
                    DatePicker("リリース日", selection: $releasedAt, displayedComponents: .date)
                }
                if app != nil {
                    Toggle("アーカイブ（切替に表示しない）", isOn: $isArchived)
                }
            }
            .navigationTitle(app == nil ? "アプリを追加" : "アプリを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let target: TrackedApp
        if let app {
            target = app
        } else {
            target = TrackedApp()
            context.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.platform = platform.isEmpty ? nil : platform
        target.releasedAt = hasReleaseDate ? Day.start(releasedAt) : nil
        target.isArchived = isArchived
        dismiss()
    }
}
