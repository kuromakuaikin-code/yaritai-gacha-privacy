import SwiftUI
import SwiftData

// MARK: - 記録一覧

struct RecordListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \GoshuinEntry.visitDate, order: .reverse) private var entries: [GoshuinEntry]

    @State private var searchText = ""
    @State private var placeTypeFilter: PlaceType?
    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: GoshuinEntry?

    private var filtered: [GoshuinEntry] {
        entries.filter { e in
            if let placeTypeFilter, e.placeType != placeTypeFilter { return false }
            guard !searchText.isEmpty else { return true }
            return e.placeName.localizedCaseInsensitiveContains(searchText)
                || e.prefecture.localizedCaseInsensitiveContains(searchText)
                || e.memo.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "記録がありません",
                        systemImage: "list.bullet.rectangle",
                        description: Text("右上の＋から、御朱印をいただいた参拝の記録を追加しましょう")
                    )
                } else {
                    List {
                        if !AppConfig.freeTrial, !store.isUnlimited, entries.count > AppConfig.freeRecordLimit {
                            Section {
                                Label("無料版は\(AppConfig.freeRecordLimit)件まで表示中。プレミアムで全件表示できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(filtered) { entry in
                            Button {
                                editing = entry
                            } label: {
                                RecordRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "参拝先・都道府県・メモで検索")
            .navigationTitle("御朱印帳ログ")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("すべて") { placeTypeFilter = nil }
                        ForEach(PlaceType.allCases) { t in
                            Button(t.label) { placeTypeFilter = t }
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
                AddEditRecordView(entry: nil)
            }
            .sheet(item: $editing) { entry in
                AddEditRecordView(entry: entry)
            }
            .alert("記録上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版は\(AppConfig.freeRecordLimit)件まで記録できます。設定タブからプレミアムで無制限に記録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, entries.count >= AppConfig.freeRecordLimit {
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

struct RecordRow: View {
    let entry: GoshuinEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.placeType.icon)
                .foregroundStyle(entry.placeType.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.placeName.isEmpty ? "(名称未入力)" : entry.placeName)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(entry.prefecture.isEmpty ? "(都道府県未入力)" : entry.prefecture)
                    Text("・").foregroundStyle(.tertiary)
                    Text(entry.placeType.label)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Label(entry.wishType.label, systemImage: entry.wishType.icon)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(entry.wishType.color.opacity(0.15))
                        .foregroundStyle(entry.wishType.color)
                        .clipShape(Capsule())
                    if entry.rating > 0 {
                        StarRatingView(rating: .constant(entry.rating), interactive: false, size: 10)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(yen(entry.fee))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.toriiRed)
                Text(mediumDate(entry.visitDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 星評価コントロール

struct StarRatingView: View {
    @Binding var rating: Int
    var interactive: Bool = true
    var size: CGFloat = 22
    private let range = 1...5

    var body: some View {
        HStack(spacing: interactive ? 6 : 2) {
            ForEach(range, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i <= rating ? Color.toriiRed : Color.secondary.opacity(0.4))
                    .onTapGesture {
                        guard interactive else { return }
                        rating = (rating == i) ? i - 1 : i
                    }
            }
        }
    }
}

// MARK: - 追加・編集

struct AddEditRecordView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let entry: GoshuinEntry?

    @State private var placeName = ""
    @State private var placeType: PlaceType = .shrine
    @State private var prefecture = ""
    @State private var visitDate = Date()
    @State private var feeText = ""
    @State private var wishType: WishType = .openLuck
    @State private var rating = 0
    @State private var memo = ""

    private var isEditing: Bool { entry != nil }

    private var fee: Int { Int(feeText) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("参拝先") {
                    Picker("種類", selection: $placeType) {
                        ForEach(PlaceType.allCases) { t in
                            Label(t.label, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("名称（例：〇〇神社）", text: $placeName)
                    TextField("都道府県（例：愛知県）", text: $prefecture)
                }

                Section("参拝日・初穂料") {
                    DatePicker("参拝日", selection: $visitDate, displayedComponents: .date)
                    HStack {
                        Text("初穂料・拝観料")
                        Spacer()
                        TextField("300〜500", text: $feeText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("円")
                    }
                }

                Section("祈願・評価") {
                    Picker("祈願内容", selection: $wishType) {
                        ForEach(WishType.allCases) { w in
                            Label(w.label, systemImage: w.icon).tag(w)
                        }
                    }
                    HStack {
                        Text("評価")
                        Spacer()
                        StarRatingView(rating: $rating)
                    }
                }

                Section("メモ（御朱印のデザインなど）") {
                    TextEditor(text: $memo)
                        .frame(minHeight: 120)
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
                        .disabled(placeName.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let entry else { return }
        placeName = entry.placeName
        placeType = entry.placeType
        prefecture = entry.prefecture
        visitDate = entry.visitDate
        feeText = entry.fee > 0 ? String(entry.fee) : ""
        wishType = entry.wishType
        rating = entry.rating
        memo = entry.memo
    }

    private func save() {
        let target = entry ?? GoshuinEntry()
        target.placeName = placeName
        target.placeType = placeType
        target.prefecture = prefecture
        target.visitDate = visitDate
        target.fee = fee
        target.wishType = wishType
        target.rating = rating
        target.memo = memo
        if entry == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let entry {
            context.delete(entry)
        }
        dismiss()
    }
}
