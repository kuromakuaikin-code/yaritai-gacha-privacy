import SwiftUI
import SwiftData

// MARK: - 習い事一覧

struct LessonCourseListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \LessonCourse.createdAt, order: .reverse) private var courses: [LessonCourse]

    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: LessonCourse?

    var body: some View {
        NavigationStack {
            Group {
                if courses.isEmpty {
                    ContentUnavailableView(
                        "習い事が登録されていません",
                        systemImage: "figure.walk.circle",
                        description: Text("右上の＋から、お子さまの習い事を登録しましょう")
                    )
                } else {
                    List {
                        if !AppConfig.freeTrial, !store.isUnlimited, courses.count > AppConfig.freeItemLimitPerModule {
                            Section {
                                Label("無料版は\(AppConfig.freeItemLimitPerModule)件まで表示中。プレミアムで全件表示できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(courses) { course in
                            NavigationLink {
                                LessonSessionListView(course: course)
                            } label: {
                                LessonCourseRow(course: course)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("習い事")
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
                AddEditLessonCourseView(course: nil)
            }
            .sheet(item: $editing) { course in
                AddEditLessonCourseView(course: course)
            }
            .alert("登録件数の上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版は習い事を\(AppConfig.freeItemLimitPerModule)件まで登録できます。設定タブからプレミアムで無制限に登録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, courses.count >= AppConfig.freeItemLimitPerModule {
            showPaywall = true
        } else {
            showAdd = true
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(courses[index])
        }
    }
}

struct LessonCourseRow: View {
    let course: LessonCourse

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(course.courseName.isEmpty ? "(未入力)" : course.courseName)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 6) {
                Text(course.childName.isEmpty ? "(お子さま名未入力)" : course.childName)
                if !course.dayOfWeekNote.isEmpty {
                    Text("・").foregroundStyle(.tertiary)
                    Text(course.dayOfWeekNote)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("月謝 \(yen(course.monthlyFee))")
                .font(.caption)
                .foregroundStyle(Color.studyBlue)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 習い事の追加・編集

struct AddEditLessonCourseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let course: LessonCourse?

    @State private var childName = ""
    @State private var courseName = ""
    @State private var monthlyFeeText = ""
    @State private var dayOfWeekNote = ""
    @State private var memo = ""

    private var isEditing: Bool { course != nil }
    private var monthlyFee: Int { Int(monthlyFeeText) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("習い事") {
                    TextField("お子さまの名前", text: $childName)
                    TextField("習い事の名前（例：スイミング）", text: $courseName)
                }
                Section("月謝・曜日") {
                    HStack {
                        Text("月謝")
                        Spacer()
                        TextField("0", text: $monthlyFeeText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("円")
                    }
                    TextField("曜日メモ（例：毎週土曜）", text: $dayOfWeekNote)
                }
                Section("メモ") {
                    TextField("先生・持ち物・目標など", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }
                if isEditing {
                    Section {
                        Button("この習い事を削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "習い事を編集" : "習い事を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(courseName.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let course else { return }
        childName = course.childName
        courseName = course.courseName
        monthlyFeeText = course.monthlyFee > 0 ? String(course.monthlyFee) : ""
        dayOfWeekNote = course.dayOfWeekNote
        memo = course.memo
    }

    private func save() {
        let target = course ?? LessonCourse()
        target.childName = childName
        target.courseName = courseName
        target.monthlyFee = monthlyFee
        target.dayOfWeekNote = dayOfWeekNote
        target.memo = memo
        if course == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let course {
            context.delete(course)
        }
        dismiss()
    }
}

// MARK: - 出席履歴

struct LessonSessionListView: View {
    @Bindable var course: LessonCourse
    @Environment(\.modelContext) private var context

    @State private var showAdd = false
    @State private var editing: LessonSession?

    private var sortedSessions: [LessonSession] {
        course.sessions.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                Button {
                    recordTodayAttended()
                } label: {
                    Label("今日出席したことを記録", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.studyBlue)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if sortedSessions.isEmpty {
                Text("出席・欠席の記録はまだありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Section("記録") {
                    ForEach(sortedSessions) { session in
                        Button {
                            editing = session
                        } label: {
                            LessonSessionRow(session: session)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle(course.courseName.isEmpty ? "出席履歴" : course.courseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddEditLessonSessionView(course: course, session: nil)
        }
        .sheet(item: $editing) { session in
            AddEditLessonSessionView(course: course, session: session)
        }
    }

    private func recordTodayAttended() {
        let session = LessonSession()
        session.date = Calendar.current.startOfDay(for: Date())
        session.attended = true
        session.course = course
        context.insert(session)
        course.sessions.append(session)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sortedSessions[index])
        }
    }
}

struct LessonSessionRow: View {
    let session: LessonSession

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: session.attended ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(session.attended ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(mediumDateWeekday(session.date))
                    .font(.subheadline.weight(.semibold))
                if !session.memo.isEmpty {
                    Text(session.memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(session.attended ? "出席" : "欠席")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background((session.attended ? Color.green : Color.red).opacity(0.15))
                .foregroundStyle(session.attended ? .green : .red)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 出席記録の追加・編集

struct AddEditLessonSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let course: LessonCourse
    let session: LessonSession?

    @State private var date = Date()
    @State private var attended = true
    @State private var memo = ""

    private var isEditing: Bool { session != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                    Toggle("出席した", isOn: $attended)
                }
                Section("メモ") {
                    TextField("振替・遅刻・様子など", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }
                if isEditing {
                    Section {
                        Button("この記録を削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "記録を編集" : "記録を追加")
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
        guard let session else { return }
        date = session.date
        attended = session.attended
        memo = session.memo
    }

    private func save() {
        let target = session ?? LessonSession()
        target.date = date
        target.attended = attended
        target.memo = memo
        if session == nil {
            target.course = course
            context.insert(target)
            course.sessions.append(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let session {
            context.delete(session)
        }
        dismiss()
    }
}
