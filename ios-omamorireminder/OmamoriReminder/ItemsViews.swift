import SwiftUI
import SwiftData

// MARK: - 一覧

struct OmamoriListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query private var items: [OmamoriItem]

    @State private var kindFilter: OmamoriKind?
    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: OmamoriItem?
    @State private var returnedExpanded = false

    private var filtered: [OmamoriItem] {
        guard let kindFilter else { return items }
        return items.filter { $0.kind == kindFilter }
    }

    /// 未返納：返納時期が近い（または過ぎている）順
    private var activeItems: [OmamoriItem] {
        filtered.filter { !$0.isReturned }
            .sorted { $0.suggestedReturnDate < $1.suggestedReturnDate }
    }

    /// 返納済み：新しい順
    private var returnedItems: [OmamoriItem] {
        filtered.filter { $0.isReturned }
            .sorted { $0.suggestedReturnDate > $1.suggestedReturnDate }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "お守り・御札が登録されていません",
                        systemImage: "seal",
                        description: Text("右上の＋から、いただいたお守りや御札を登録しましょう")
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

                        if activeItems.isEmpty && returnedItems.isEmpty {
                            Section {
                                Text("この種類の登録はありません")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !activeItems.isEmpty {
                            Section("お手元にあるお守り・御札") {
                                ForEach(activeItems) { item in
                                    Button {
                                        editing = item
                                    } label: {
                                        OmamoriRow(item: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .onDelete { offsets in delete(offsets, from: activeItems) }
                            }
                        }

                        if !returnedItems.isEmpty {
                            Section {
                                DisclosureGroup(isExpanded: $returnedExpanded) {
                                    ForEach(returnedItems) { item in
                                        Button {
                                            editing = item
                                        } label: {
                                            OmamoriRow(item: item)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.secondary)
                                    }
                                    .onDelete { offsets in delete(offsets, from: returnedItems) }
                                } label: {
                                    Text("返納済み (\(returnedItems.count)件)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("お守り返納リマインダー")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("すべて") { kindFilter = nil }
                        ForEach(OmamoriKind.allCases) { k in
                            Button(k.label) { kindFilter = k }
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
                AddEditOmamoriView(item: nil)
            }
            .sheet(item: $editing) { item in
                AddEditOmamoriView(item: item)
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

    private func delete(_ offsets: IndexSet, from source: [OmamoriItem]) {
        for index in offsets {
            context.delete(source[index])
        }
    }
}

struct OmamoriRow: View {
    let item: OmamoriItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind.icon)
                .foregroundStyle(Color.omamoriGold)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.shrineName.isEmpty ? "(社寺名未入力)" : item.shrineName)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(item.kind.label)
                    Text("・").foregroundStyle(.tertiary)
                    Text(item.purpose.label)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if item.isDueForReturn {
                    Text("返納時期です")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(Color.red)
                        .clipShape(Capsule())
                } else if item.isReturned {
                    Text("返納済み")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .foregroundStyle(Color.gray)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("授与：\(mediumDate(item.obtainedDate))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("返納目安：\(mediumDate(item.suggestedReturnDate))")
                    .font(.caption2)
                    .foregroundStyle(item.isDueForReturn ? Color.red : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 追加・編集

struct AddEditOmamoriView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let item: OmamoriItem?

    @State private var shrineName = ""
    @State private var kind: OmamoriKind = .omamori
    @State private var purpose: OmamoriPurpose = .kaiun
    @State private var obtainedDate = Date()
    @State private var suggestedReturnDate = defaultReturnDate(from: Date())
    @State private var returnDateManuallyEdited = false
    @State private var isReturned = false
    @State private var memo = ""

    private var isEditing: Bool { item != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("お守り・御札") {
                    TextField("社寺名（例：〇〇神社）", text: $shrineName)
                    Picker("種類", selection: $kind) {
                        ForEach(OmamoriKind.allCases) { k in
                            Label(k.label, systemImage: k.icon).tag(k)
                        }
                    }
                    Picker("ご利益・目的", selection: $purpose) {
                        ForEach(OmamoriPurpose.allCases) { p in
                            Label(p.label, systemImage: p.icon).tag(p)
                        }
                    }
                }

                Section("日付") {
                    DatePicker("授与日", selection: $obtainedDate, displayedComponents: .date)
                        .onChange(of: obtainedDate) { _, newValue in
                            if !returnDateManuallyEdited {
                                suggestedReturnDate = defaultReturnDate(from: newValue)
                            }
                        }
                    DatePicker("返納目安日", selection: $suggestedReturnDate, displayedComponents: .date)
                        .onChange(of: suggestedReturnDate) { _, _ in
                            returnDateManuallyEdited = true
                        }
                    Text("返納目安日は授与日の1年後を自動で設定します。願いの成就時期などに合わせて自由に変更できます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("状況") {
                    Toggle("返納済み", isOn: $isReturned)
                }

                Section("メモ") {
                    TextField("お願いごと・購入場所・エピソードなど", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isEditing {
                    Section {
                        Button("この登録を削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "登録を編集" : "お守り・御札を追加")
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
        guard let item else { return }
        shrineName = item.shrineName
        kind = item.kind
        purpose = item.purpose
        obtainedDate = item.obtainedDate
        suggestedReturnDate = item.suggestedReturnDate
        isReturned = item.isReturned
        memo = item.memo
        // 編集時は既存の返納目安日を尊重し、授与日を変更しても自動上書きしない
        returnDateManuallyEdited = true
    }

    private func save() {
        let target = item ?? OmamoriItem()
        target.shrineName = shrineName
        target.kind = kind
        target.purpose = purpose
        target.obtainedDate = obtainedDate
        target.suggestedReturnDate = suggestedReturnDate
        target.isReturned = isReturned
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
