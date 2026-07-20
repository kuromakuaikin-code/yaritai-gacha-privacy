import SwiftUI
import SwiftData

// MARK: - 4タブの入口
//
// 4タブとも中身は同じ ModuleListView（module だけが異なる）。
// 見た目・データ構造をタブごとに複製せず、共通ビューをカテゴリで
// パラメータ化することでコードの重複を避けている。

struct ParkView: View {
    var body: some View { ModuleListView(module: .park) }
}

struct SceneryView: View {
    var body: some View { ModuleListView(module: .scenery) }
}

struct CampView: View {
    var body: some View { ModuleListView(module: .camp) }
}

struct SightseeingView: View {
    var body: some View { ModuleListView(module: .sightseeing) }
}

// MARK: - 一覧（モジュール共通）

struct ModuleListView: View {
    let module: OutingModule

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \OutingVisit.visitDate, order: .reverse) private var allVisits: [OutingVisit]

    @State private var searchText = ""
    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: OutingVisit?

    private var visits: [OutingVisit] {
        allVisits.filter { $0.module == module }
    }

    private var filtered: [OutingVisit] {
        visits.filter { v in
            guard !searchText.isEmpty else { return true }
            return v.name.localizedCaseInsensitiveContains(searchText)
                || v.memo.localizedCaseInsensitiveContains(searchText)
                || v.subKind.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if visits.isEmpty {
                    ContentUnavailableView(
                        "記録がありません",
                        systemImage: module.icon,
                        description: Text(module.emptyDescription)
                    )
                } else {
                    List {
                        if !AppConfig.freeTrial, !store.isUnlimited, allVisits.count > AppConfig.freeTotalLimit {
                            Section {
                                Label("無料版は全カテゴリ合計\(AppConfig.freeTotalLimit)件まで。プレミアムで無制限に記録できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(filtered) { visit in
                            Button {
                                editing = visit
                            } label: {
                                VisitRow(visit: visit, module: module)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .searchable(text: $searchText, prompt: module.searchPrompt)
            .navigationTitle(module.label)
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
                AddEditVisitView(module: module, visit: nil)
            }
            .sheet(item: $editing) { visit in
                AddEditVisitView(module: module, visit: visit)
            }
            .alert("記録上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版は全カテゴリ合計\(AppConfig.freeTotalLimit)件まで記録できます。設定タブからプレミアムで無制限に記録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, allVisits.count >= AppConfig.freeTotalLimit {
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

struct VisitRow: View {
    let visit: OutingVisit
    let module: OutingModule

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: module.icon)
                .foregroundStyle(module.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(visit.name.isEmpty ? module.label : visit.name)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    if !visit.subKind.isEmpty {
                        Text(visit.subKind)
                        Text("・").foregroundStyle(.tertiary)
                    }
                    Text(mediumDate(visit.visitDate))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            StarRatingView(rating: visit.rating, size: 12)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 星評価（表示専用）

struct StarRatingView: View {
    let rating: Int
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i < rating ? Color.odekakeTint : Color.secondary.opacity(0.4))
            }
        }
    }
}

// MARK: - 星評価（編集用）

struct StarRatingPicker: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { i in
                Button {
                    rating = (rating == i) ? 0 : i
                } label: {
                    Image(systemName: i <= rating ? "star.fill" : "star")
                        .font(.system(size: 22))
                        .foregroundStyle(i <= rating ? Color.odekakeTint : Color.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 追加・編集（モジュール共通、フォームの見た目だけタブで切り替え）

struct AddEditVisitView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let module: OutingModule
    let visit: OutingVisit?

    @State private var name = ""
    @State private var subKind = ""
    @State private var visitDate = Date()
    @State private var rating = 0
    @State private var detailNote = ""
    @State private var memo = ""

    private var isEditing: Bool { visit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section(module.label) {
                    TextField(module.namePlaceholder, text: $name)

                    if let options = module.subKindOptions {
                        Picker(module.subKindPickerLabel, selection: $subKind) {
                            ForEach(options, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                    }

                    DatePicker("訪問日", selection: $visitDate, displayedComponents: .date)
                }

                Section("評価") {
                    StarRatingPicker(rating: $rating)
                }

                Section(module.detailLabel) {
                    TextField(module.detailPlaceholder, text: $detailNote, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("メモ") {
                    TextField("感想・持ち物・注意点など", text: $memo, axis: .vertical)
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
                        .disabled(name.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        if let options = module.subKindOptions, subKind.isEmpty {
            subKind = options.first ?? ""
        }
        guard let visit else { return }
        name = visit.name
        subKind = visit.subKind
        visitDate = visit.visitDate
        rating = visit.rating
        detailNote = visit.detailNote
        memo = visit.memo
    }

    private func save() {
        let target = visit ?? OutingVisit()
        target.module = module
        target.name = name
        target.subKind = subKind
        target.visitDate = visitDate
        target.rating = rating
        target.detailNote = detailNote
        target.memo = memo
        if visit == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let visit {
            context.delete(visit)
        }
        dismiss()
    }
}
