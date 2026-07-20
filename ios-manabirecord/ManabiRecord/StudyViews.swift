import SwiftUI
import SwiftData

// MARK: - 勉強の目標一覧

struct StudyGoalListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \StudyGoal.createdAt, order: .reverse) private var goals: [StudyGoal]

    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: StudyGoal?

    var body: some View {
        NavigationStack {
            Group {
                if goals.isEmpty {
                    ContentUnavailableView(
                        "目標が登録されていません",
                        systemImage: "chart.bar",
                        description: Text("右上の＋から、資格・勉強の目標を登録しましょう")
                    )
                } else {
                    List {
                        if !AppConfig.freeTrial, !store.isUnlimited, goals.count > AppConfig.freeItemLimitPerModule {
                            Section {
                                Label("無料版は\(AppConfig.freeItemLimitPerModule)件まで表示中。プレミアムで全件表示できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(goals) { goal in
                            NavigationLink {
                                StudyLogListView(goal: goal)
                            } label: {
                                StudyGoalRow(goal: goal)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("勉強進捗")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addTapped()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddEditStudyGoalView(goal: nil)
            }
            .sheet(item: $editing) { goal in
                AddEditStudyGoalView(goal: goal)
            }
            .alert("登録件数の上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版は目標を\(AppConfig.freeItemLimitPerModule)件まで登録できます。設定タブからプレミアムで無制限に登録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, goals.count >= AppConfig.freeItemLimitPerModule {
            showPaywall = true
        } else {
            showAdd = true
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(goals[index])
        }
    }
}

struct StudyGoalRow: View {
    let goal: StudyGoal

    private var daysLabel: String {
        let days = goal.daysUntilTarget
        if days > 0 { return "あと\(days)日" }
        if days == 0 { return "今日が目標日" }
        return "\(-days)日超過"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(goal.title.isEmpty ? "(未入力)" : goal.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(daysLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(goal.daysUntilTarget < 0 ? .red : .secondary)
            }
            ProgressView(value: goal.progress)
                .tint(Color.studyBlue)
            HStack {
                Text("\(goal.totalMinutesLogged)分 / \(goal.totalMinutesGoal)分")
                Spacer()
                Text("目標日 \(mediumDate(goal.targetDate))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 目標の追加・編集

struct AddEditStudyGoalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let goal: StudyGoal?

    @State private var title = ""
    @State private var targetDate = Date()
    @State private var totalMinutesGoalText = ""
    @State private var memo = ""

    private var isEditing: Bool { goal != nil }
    private var totalMinutesGoal: Int { Int(totalMinutesGoalText) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("目標") {
                    TextField("目標名（例：英検3級）", text: $title)
                    DatePicker("目標日", selection: $targetDate, displayedComponents: .date)
                    HStack {
                        Text("目標時間")
                        Spacer()
                        TextField("0", text: $totalMinutesGoalText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("分")
                    }
                }
                Section("メモ") {
                    TextField("教材・受験日程など", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }
                if isEditing {
                    Section {
                        Button("この目標を削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "目標を編集" : "目標を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let goal else { return }
        title = goal.title
        targetDate = goal.targetDate
        totalMinutesGoalText = goal.totalMinutesGoal > 0 ? String(goal.totalMinutesGoal) : ""
        memo = goal.memo
    }

    private func save() {
        let target = goal ?? StudyGoal()
        target.title = title
        target.targetDate = targetDate
        target.totalMinutesGoal = totalMinutesGoal
        target.memo = memo
        if goal == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let goal {
            context.delete(goal)
        }
        dismiss()
    }
}

// MARK: - 勉強ログ履歴

struct StudyLogListView: View {
    @Bindable var goal: StudyGoal
    @Environment(\.modelContext) private var context

    @State private var logDate = Date()
    @State private var minutesText = ""
    @State private var logMemo = ""
    @State private var editing: StudyLog?

    private var sortedLogs: [StudyLog] {
        goal.logs.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section("進捗") {
                ProgressView(value: goal.progress)
                    .tint(Color.studyBlue)
                Text("\(goal.totalMinutesLogged)分 / \(goal.totalMinutesGoal)分（\(Int(goal.progress * 100))%）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("勉強時間を記録") {
                DatePicker("日付", selection: $logDate, displayedComponents: .date)
                HStack {
                    Text("時間")
                    Spacer()
                    TextField("分", text: $minutesText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("分")
                }
                TextField("メモ（任意）", text: $logMemo)
                Button("記録を追加") {
                    addLog()
                }
                .disabled(Int(minutesText) == nil || Int(minutesText) == 0)
            }

            if !sortedLogs.isEmpty {
                Section("履歴") {
                    ForEach(sortedLogs) { log in
                        Button {
                            editing = log
                        } label: {
                            StudyLogRow(log: log)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle(goal.title.isEmpty ? "勉強ログ" : goal.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { log in
            AddEditStudyLogView(goal: goal, log: log)
        }
    }

    private func addLog() {
        guard let minutes = Int(minutesText), minutes > 0 else { return }
        let log = StudyLog()
        log.date = logDate
        log.minutesStudied = minutes
        log.memo = logMemo
        log.goal = goal
        context.insert(log)
        goal.logs.append(log)
        minutesText = ""
        logMemo = ""
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sortedLogs[index])
        }
    }
}

struct StudyLogRow: View {
    let log: StudyLog

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(mediumDate(log.date))
                    .font(.subheadline.weight(.semibold))
                if !log.memo.isEmpty {
                    Text(log.memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(log.minutesStudied)分")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.studyBlue)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 勉強ログの編集

struct AddEditStudyLogView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let goal: StudyGoal
    let log: StudyLog?

    @State private var date = Date()
    @State private var minutesText = ""
    @State private var memo = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("時間")
                        Spacer()
                        TextField("分", text: $minutesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("分")
                    }
                    TextField("メモ", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Button("この記録を削除", role: .destructive) {
                        deleteAndDismiss()
                    }
                }
            }
            .navigationTitle("記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let log else { return }
        date = log.date
        minutesText = log.minutesStudied > 0 ? String(log.minutesStudied) : ""
        memo = log.memo
    }

    private func save() {
        guard let log else { return }
        log.date = date
        log.minutesStudied = Int(minutesText) ?? 0
        log.memo = memo
        dismiss()
    }

    private func deleteAndDismiss() {
        if let log {
            context.delete(log)
        }
        dismiss()
    }
}
