import SwiftUI
import SwiftData

// MARK: - 読書記録一覧

struct BookListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \BookRecord.finishedDate, order: .reverse) private var books: [BookRecord]

    @State private var childFilter: String?
    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: BookRecord?

    private var childNames: [String] {
        let names = Set(books.map { $0.childName }.filter { !$0.isEmpty })
        return names.sorted()
    }

    private var filtered: [BookRecord] {
        guard let childFilter else { return books }
        return books.filter { $0.childName == childFilter }
    }

    private var booksThisYear: Int {
        let year = Calendar.current.component(.year, from: Date())
        return filtered.filter { Calendar.current.component(.year, from: $0.finishedDate) == year }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView(
                        "読書記録がありません",
                        systemImage: "book.closed",
                        description: Text("右上の＋から、読んだ本を記録しましょう")
                    )
                } else {
                    List {
                        Section {
                            Text("今年読んだ冊数: \(booksThisYear)冊")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.studyBlue)
                        }
                        if !AppConfig.freeTrial, !store.isUnlimited, books.count > AppConfig.freeItemLimitPerModule {
                            Section {
                                Label("無料版は\(AppConfig.freeItemLimitPerModule)件まで表示中。プレミアムで全件表示できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Section {
                            ForEach(filtered) { book in
                                Button {
                                    editing = book
                                } label: {
                                    BookRow(book: book)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete(perform: delete)
                        }
                    }
                }
            }
            .navigationTitle("読書記録")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("すべて") { childFilter = nil }
                        ForEach(childNames, id: \.self) { name in
                            Button(name) { childFilter = name }
                        }
                    } label: {
                        Label("絞り込み", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addTapped()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddEditBookView(book: nil)
            }
            .sheet(item: $editing) { book in
                AddEditBookView(book: book)
            }
            .alert("登録件数の上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版は読書記録を\(AppConfig.freeItemLimitPerModule)件まで登録できます。設定タブからプレミアムで無制限に登録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, books.count >= AppConfig.freeItemLimitPerModule {
            showPaywall = true
        } else {
            showAdd = true
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filtered[index])
        }
    }
}

struct BookRow: View {
    let book: BookRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "book.closed.fill")
                .foregroundStyle(Color.studyBlue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(book.title.isEmpty ? "(タイトル未入力)" : book.title)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    if !book.childName.isEmpty {
                        Text(book.childName)
                        Text("・").foregroundStyle(.tertiary)
                    }
                    if !book.author.isEmpty {
                        Text(book.author)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                StarRatingView(rating: book.rating)
            }
            Spacer()
            Text(mediumDate(book.finishedDate))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct StarRatingView: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < rating ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - 読書記録の追加・編集

struct AddEditBookView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let book: BookRecord?

    @State private var childName = ""
    @State private var title = ""
    @State private var author = ""
    @State private var finishedDate = Date()
    @State private var rating = 0
    @State private var pagesText = ""
    @State private var summary = ""

    private var isEditing: Bool { book != nil }
    private var pages: Int? { Int(pagesText) }

    var body: some View {
        NavigationStack {
            Form {
                Section("本") {
                    TextField("お子さまの名前", text: $childName)
                    TextField("タイトル", text: $title)
                    TextField("著者", text: $author)
                }
                Section("読了日・評価") {
                    DatePicker("読了日", selection: $finishedDate, displayedComponents: .date)
                    HStack {
                        Text("評価")
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { i in
                                Button {
                                    rating = (i + 1 == rating) ? 0 : i + 1
                                } label: {
                                    Image(systemName: i < rating ? "star.fill" : "star")
                                        .foregroundStyle(.orange)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    HStack {
                        Text("ページ数")
                        Spacer()
                        TextField("任意", text: $pagesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("ページ")
                    }
                }
                Section("感想") {
                    TextField("感想メモ", text: $summary, axis: .vertical)
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
            .navigationTitle(isEditing ? "読書記録を編集" : "読書記録を追加")
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
        guard let book else { return }
        childName = book.childName
        title = book.title
        author = book.author
        finishedDate = book.finishedDate
        rating = book.rating
        pagesText = book.pages.map(String.init) ?? ""
        summary = book.summary
    }

    private func save() {
        let target = book ?? BookRecord()
        target.childName = childName
        target.title = title
        target.author = author
        target.finishedDate = finishedDate
        target.rating = rating
        target.pages = pages
        target.summary = summary
        if book == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let book {
            context.delete(book)
        }
        dismiss()
    }
}
