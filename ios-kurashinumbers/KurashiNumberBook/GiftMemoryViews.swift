import SwiftUI
import SwiftData

// MARK: - 記念日・ギフト履歴 一覧

struct GiftMemoryListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query private var memories: [GiftMemory]

    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: GiftMemory?

    /// 次の記念日が近い順に並べる
    private var sorted: [GiftMemory] {
        memories.sorted { $0.daysUntilNext < $1.daysUntilNext }
    }

    var body: some View {
        NavigationStack {
            Group {
                if memories.isEmpty {
                    ContentUnavailableView(
                        "記録がありません",
                        systemImage: "gift.fill",
                        description: Text("右上の＋から、誕生日や記念日に渡したギフトを記録しましょう")
                    )
                } else {
                    List {
                        if !AppConfig.freeTrial, !store.isUnlimited, memories.count > AppConfig.freeItemLimitPerModule {
                            Section {
                                Label("無料版は\(AppConfig.freeItemLimitPerModule)件まで表示中。プレミアムで全件表示できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(sorted) { memory in
                            Button {
                                editing = memory
                            } label: {
                                GiftMemoryRow(memory: memory)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("記念日・ギフト履歴")
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
                AddEditGiftMemoryView(memory: nil)
            }
            .sheet(item: $editing) { memory in
                AddEditGiftMemoryView(memory: memory)
            }
            .alert("記録上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版は記念日の記録を\(AppConfig.freeItemLimitPerModule)件まで登録できます。設定タブからプレミアムで4つのモジュールすべて無制限に記録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, memories.count >= AppConfig.freeItemLimitPerModule {
            showPaywall = true
        } else {
            showAdd = true
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sorted[index])
        }
    }
}

struct GiftMemoryRow: View {
    let memory: GiftMemory

    private var days: Int { memory.daysUntilNext }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .foregroundStyle(Color.kurashiGold)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(memory.personName.isEmpty ? "(名前未入力)" : memory.personName)・\(memory.occasion)")
                    .font(.subheadline.weight(.semibold))
                Text(monthDayLabel(month: memory.month, day: memory.day))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !memory.lastGiftDescription.isEmpty {
                    Text("前回：\(memory.lastGiftYear)年 \(memory.lastGiftDescription)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(daysLabel(days))
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(deadlineColor(days).opacity(0.15))
                .foregroundStyle(deadlineColor(days))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 追加・編集

struct AddEditGiftMemoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let memory: GiftMemory?

    @State private var personName = ""
    @State private var occasion = ""
    @State private var monthDay = Date()
    @State private var lastGiftDescription = ""
    @State private var lastGiftYear = Calendar.current.component(.year, from: Date())
    @State private var memo = ""

    private var isEditing: Bool { memory != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("相手・行事") {
                    TextField("お名前", text: $personName)
                    TextField("行事（例：誕生日・結婚記念日・父の日）", text: $occasion)
                    DatePicker("日付（年は無視され、月日のみ使用）", selection: $monthDay, displayedComponents: .date)
                }

                Section("前回のギフト") {
                    TextField("内容（例：ハンドクリームのセット）", text: $lastGiftDescription)
                    Stepper("\(lastGiftYear)年", value: $lastGiftYear, in: 2000...2100)
                }

                Section("メモ") {
                    TextField("好み・避けたいもの・サイズなど", text: $memo, axis: .vertical)
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
                        .disabled(personName.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let memory else { return }
        personName = memory.personName
        occasion = memory.occasion
        var comps = DateComponents()
        comps.year = 2001 // うるう年ではない代表年
        comps.month = memory.month
        comps.day = memory.day
        monthDay = Calendar.current.date(from: comps) ?? Date()
        lastGiftDescription = memory.lastGiftDescription
        lastGiftYear = memory.lastGiftYear
        memo = memory.memo
    }

    private func save() {
        let target = memory ?? GiftMemory()
        target.personName = personName
        target.occasion = occasion
        let cal = Calendar.current
        target.month = cal.component(.month, from: monthDay)
        target.day = cal.component(.day, from: monthDay)
        target.lastGiftDescription = lastGiftDescription
        target.lastGiftYear = lastGiftYear
        target.memo = memo
        if memory == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let memory {
            context.delete(memory)
        }
        dismiss()
    }
}
