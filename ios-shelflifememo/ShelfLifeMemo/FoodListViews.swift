import SwiftUI
import SwiftData

// MARK: - 一覧

struct FoodListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(filter: #Predicate<FoodItem> { !$0.isConsumed },
           sort: \FoodItem.expiryDate) private var items: [FoodItem]

    @State private var searchText = ""
    @State private var categoryFilter: FoodCategory?
    @State private var locationFilter: String?
    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: FoodItem?

    private var locations: [String] {
        let set = Set(items.map(\.location).filter { !$0.isEmpty })
        return set.sorted()
    }

    private var filtered: [FoodItem] {
        items.filter { item in
            if let categoryFilter, item.category != categoryFilter { return false }
            if let locationFilter, item.location != locationFilter { return false }
            guard !searchText.isEmpty else { return true }
            return item.name.localizedCaseInsensitiveContains(searchText)
                || item.memo.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "登録された食品がありません",
                        systemImage: "refrigerator",
                        description: Text("右上の＋から、冷蔵庫・冷凍庫・常温保存の食品を登録しましょう")
                    )
                } else {
                    List {
                        if !AppConfig.freeTrial, !store.isUnlimited, items.count > AppConfig.freeItemLimit {
                            Section {
                                Label("無料版は\(AppConfig.freeItemLimit)件まで表示中。プレミアムで全件表示できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(filtered) { item in
                            Button {
                                editing = item
                            } label: {
                                FoodRow(item: item)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    context.delete(item)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                                Button {
                                    item.isConsumed = true
                                } label: {
                                    Label("消費済み", systemImage: "checkmark.circle")
                                }
                                .tint(.shelfGreen)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "食品名・メモで検索")
            .navigationTitle("冷蔵庫の賞味期限メモ")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Section("保存区分") {
                            Button("すべて") { categoryFilter = nil }
                            ForEach(FoodCategory.allCases) { c in
                                Button(c.label) { categoryFilter = c }
                            }
                        }
                        if !locations.isEmpty {
                            Section("保存場所") {
                                Button("すべて") { locationFilter = nil }
                                ForEach(locations, id: \.self) { loc in
                                    Button(loc) { locationFilter = loc }
                                }
                            }
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
                AddEditFoodView(item: nil)
            }
            .sheet(item: $editing) { item in
                AddEditFoodView(item: item)
            }
            .alert("登録上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版は\(AppConfig.freeItemLimit)件まで登録できます。設定タブからプレミアムで無制限に登録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, items.count >= AppConfig.freeItemLimit {
            showPaywall = true
        } else {
            showAdd = true
        }
    }
}

struct FoodRow: View {
    let item: FoodItem

    private var days: Int { item.daysUntilExpiry }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.icon)
                .foregroundStyle(item.category.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name.isEmpty ? "(名前未入力)" : item.name)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(item.category.label)
                    if !item.location.isEmpty {
                        Text("・").foregroundStyle(.tertiary)
                        Text(item.location)
                    }
                    if !item.quantity.isEmpty {
                        Text("・").foregroundStyle(.tertiary)
                        Text(item.quantity)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(expiryLabel(days))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(expiryColor(days))
                Text(mediumDate(item.expiryDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 追加・編集

struct AddEditFoodView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let item: FoodItem?

    @State private var name = ""
    @State private var category: FoodCategory = .fridge
    @State private var expiryDate = Date()
    @State private var quantity = ""
    @State private var location = ""
    @State private var memo = ""

    private var isEditing: Bool { item != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("食品") {
                    TextField("名前（例：牛乳）", text: $name)
                    Picker("保存区分", selection: $category) {
                        ForEach(FoodCategory.allCases) { c in
                            Label(c.label, systemImage: c.icon).tag(c)
                        }
                    }
                }

                Section("期限") {
                    DatePicker("賞味・消費期限", selection: $expiryDate, displayedComponents: .date)
                    HStack(spacing: 10) {
                        QuickDateButton(title: "+3日") { addFromToday(days: 3) }
                        QuickDateButton(title: "+1週間") { addFromToday(days: 7) }
                        QuickDateButton(title: "+1ヶ月") { addFromToday(months: 1) }
                    }
                }

                Section("数量・保存場所") {
                    TextField("数量（例：2個）", text: $quantity)
                    TextField("保存場所（例：野菜室）", text: $location)
                }

                Section("メモ") {
                    TextField("開封状況や用途など", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isEditing {
                    Section {
                        Button("消費済みにする") {
                            item?.isConsumed = true
                            dismiss()
                        }
                        Button("この記録を削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "食品を編集" : "食品を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func addFromToday(days: Int = 0, months: Int = 0) {
        var comps = DateComponents()
        if days != 0 { comps.day = days }
        if months != 0 { comps.month = months }
        expiryDate = Calendar.current.date(byAdding: comps, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private func load() {
        guard let item else { return }
        name = item.name
        category = item.category
        expiryDate = item.expiryDate
        quantity = item.quantity
        location = item.location
        memo = item.memo
    }

    private func save() {
        let target = item ?? FoodItem()
        target.name = name
        target.category = category
        target.expiryDate = expiryDate
        target.quantity = quantity
        target.location = location
        target.memo = memo
        if item == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let item {
            context.delete(item)
        }
        dismiss()
    }
}

private struct QuickDateButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.shelfGreen.opacity(0.15))
                .foregroundStyle(Color.shelfGreen)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
