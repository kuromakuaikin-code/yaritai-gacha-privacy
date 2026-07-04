import SwiftUI
import SwiftData

// MARK: - 話題タブ（ブラウズ）

struct TopicsBrowseView: View {
    @EnvironmentObject private var store: PurchaseStore
    @State private var showPaywall = false
    @State private var showGacha = false

    var body: some View {
        NavigationStack {
            List {
                if !store.premium {
                    Section {
                        Button {
                            showPaywall = true
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("⭐ プレミアムで話題を全種類解放")
                                    .font(.subheadline.weight(.bold))
                                Text("残り22種の話題（会話の流れの例つき）を解放｜\(AppConfig.freeTrial ? "今なら無料" : AppConfig.premiumPriceLabel + " 買い切り")")
                                    .font(.caption)
                            }
                        }
                        .listRowBackground(
                            LinearGradient(colors: [.pink, Color(red: 0.7, green: 0.24, blue: 0.35)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                        .foregroundStyle(.white)
                    }
                }
                Section {
                    Button {
                        showGacha = true
                    } label: {
                        Label("話題ガチャで3つ引く", systemImage: "dice")
                    }
                }
                ForEach(TopicData.categories) { cat in
                    TopicCategorySection(category: cat, partner: nil,
                                         showPaywall: $showPaywall)
                }
            }
            .navigationTitle("話題リスト")
            .sheet(isPresented: $showPaywall) { PaywallView(message: nil) }
            .sheet(isPresented: $showGacha) { GachaView(partner: nil) }
        }
    }
}

// MARK: - お相手ごとの話題チェック

struct TopicChecklistView: View {
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \MyTopic.order) private var myTopics: [MyTopic]
    @Bindable var partner: Partner

    @State private var showPaywall = false
    @State private var showGacha = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(partner.name).font(.subheadline.weight(.bold))
                        Spacer()
                        Text("\(done) / \(total) 話した")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ProgressView(value: total > 0 ? Double(done) / Double(total) : 0)
                        .tint(.pink)
                }
            }
            Section {
                Button {
                    showGacha = true
                } label: {
                    Label("話題ガチャで3つ引く", systemImage: "dice")
                }
            }
            if !myTopics.isEmpty {
                Section("📝 MY話題リスト") {
                    ForEach(myTopics) { t in
                        TopicCheckRow(id: t.key, title: t.text,
                                      note: t.note.isEmpty ? nil : t.note,
                                      flow: nil, partner: partner)
                    }
                }
            }
            ForEach(TopicData.categories) { cat in
                TopicCategorySection(category: cat, partner: partner,
                                     showPaywall: $showPaywall)
            }
        }
        .navigationTitle("話題チェック")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView(message: nil) }
        .sheet(isPresented: $showGacha) { GachaView(partner: partner) }
    }

    private var total: Int {
        TopicData.unlockedTopics(premium: store.premium).count + myTopics.count
    }

    private var done: Int {
        let valid = Set(TopicData.unlockedTopics(premium: store.premium).map(\.id))
            .union(myTopics.map(\.key))
        return partner.talked.filter { valid.contains($0) }.count
    }
}

// MARK: - カテゴリセクション（共通）

struct TopicCategorySection: View {
    @EnvironmentObject private var store: PurchaseStore
    let category: TopicCategory
    let partner: Partner?
    @Binding var showPaywall: Bool

    private var unlocked: Bool { category.free || store.premium }

    var body: some View {
        Section {
            if unlocked {
                ForEach(category.topics) { topic in
                    TopicCheckRow(id: topic.id, title: topic.title,
                                  note: nil, flow: topic.flow, partner: partner)
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("タップして解放（\(category.topics.count)話題）")
                        Spacer()
                        Text(AppConfig.freeTrial ? "テスト中は無料" : AppConfig.premiumPriceLabel)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            HStack {
                Text(category.name)
                if !unlocked {
                    Text("⭐ プレミアム").font(.caption2.weight(.bold)).foregroundStyle(.orange)
                }
            }
        }
    }
}

// MARK: - 話題行（チェック＋会話フロー展開）

struct TopicCheckRow: View {
    let id: String
    let title: String
    let note: String?
    let flow: TopicFlow?
    let partner: Partner?

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if let partner {
                    Button {
                        toggleTalked(partner)
                    } label: {
                        Image(systemName: talked(partner) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(talked(partner) ? .pink : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Text(title)
                    .strikethrough(partner.map(talked) ?? false, color: .secondary)
                    .foregroundStyle((partner.map(talked) ?? false) ? .secondary : .primary)
                Spacer()
                if flow != nil || note != nil {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if flow != nil || note != nil {
                    withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
                }
            }

            if expanded {
                if let flow {
                    FlowView(flow: flow)
                } else if let note {
                    Text("📝 " + note)
                        .font(.footnote)
                        .padding(10)
                        .background(Color.pink.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func talked(_ p: Partner) -> Bool { p.talked.contains(id) }

    private func toggleTalked(_ p: Partner) {
        if let i = p.talked.firstIndex(of: id) {
            p.talked.remove(at: i)
        } else {
            p.talked.append(id)
        }
    }
}

struct FlowView: View {
    let flow: TopicFlow

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("💬 " + flow.q)
                .font(.footnote)
                .padding(10)
                .background(Color.pink.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack {
                Spacer()
                Text("🗣 「\(flow.a)」")
                    .font(.footnote).foregroundStyle(.secondary)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Text("↩ 答えに合わせて聞き返す")
                .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            ForEach(flow.d.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 8) {
                    Text(flow.d[i].tag)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                    Text(flow.d[i].text).font(.footnote)
                }
            }
        }
    }
}

// MARK: - MYメモタブ

struct MyTopicsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MyTopic.order) private var myTopics: [MyTopic]

    @State private var editing: MyTopic?
    @State private var adding = false
    @State private var showGacha = false

    var body: some View {
        NavigationStack {
            Group {
                if myTopics.isEmpty {
                    ContentUnavailableView {
                        Label("まだメモがありません", systemImage: "square.and.pencil")
                    } description: {
                        Text("「今度これを話したい」「次に聞くこと」を自由にメモ。お相手の話題チェックやカンペ、話題ガチャにも自動で入ります。")
                    } actions: {
                        Button("追加する") { adding = true }.buttonStyle(.bordered)
                    }
                } else {
                    List {
                        ForEach(myTopics) { t in
                            Button {
                                editing = t
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(t.text)
                                    if !t.note.isEmpty {
                                        Text("📝 " + t.note)
                                            .font(.caption).foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { idx in
                            idx.map { myTopics[$0] }.forEach(context.delete)
                        }
                        .onMove { from, to in
                            var items = myTopics
                            items.move(fromOffsets: from, toOffset: to)
                            for (i, item) in items.enumerated() { item.order = i }
                        }
                        Section {
                            Button {
                                showGacha = true
                            } label: {
                                Label("話題ガチャで3つ引く", systemImage: "dice")
                            }
                        }
                    }
                }
            }
            .navigationTitle("MYメモ")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $adding) { MyTopicFormView(topic: nil) }
            .sheet(item: $editing) { MyTopicFormView(topic: $0) }
            .sheet(isPresented: $showGacha) { GachaView(partner: nil) }
        }
    }
}

struct MyTopicFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var myTopics: [MyTopic]

    let topic: MyTopic?

    @State private var text = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("話したいこと（必須）", text: $text)
                TextField("メモ・聞き方（任意）", text: $note, axis: .vertical)
            }
            .navigationTitle(topic == nil ? "MY話題を追加" : "MY話題を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let t = topic ?? MyTopic(order: (myTopics.map(\.order).max() ?? -1) + 1)
                        t.text = text.trimmingCharacters(in: .whitespaces)
                        t.note = note.trimmingCharacters(in: .whitespaces)
                        if topic == nil { context.insert(t) }
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let topic { text = topic.text; note = topic.note }
            }
        }
    }
}

// MARK: - 話題ガチャ

struct GachaView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \MyTopic.order) private var myTopics: [MyTopic]

    let partner: Partner?

    struct Pick: Identifiable {
        let id = UUID()
        let title: String
        let question: String
        let hint: (tag: String, text: String)?
        let note: String?
    }

    @State private var picks: [Pick] = []

    var body: some View {
        NavigationStack {
            List {
                Text(partner == nil ? "解放中の話題からランダムに3つ引きます。"
                                    : "まだ話していない話題からランダムに3つ引きます。")
                    .font(.caption).foregroundStyle(.secondary)
                if picks.isEmpty {
                    Text("引ける話題がありません。全部話しました！🎉")
                }
                ForEach(picks) { pick in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pick.title).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        Text("💬 " + pick.question).font(.subheadline.weight(.bold))
                        if let hint = pick.hint {
                            HStack(alignment: .top, spacing: 8) {
                                Text(hint.tag)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                                Text(hint.text).font(.footnote)
                            }
                        }
                        if let note = pick.note, !note.isEmpty {
                            Text("📝 " + note).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                Button {
                    roll()
                } label: {
                    Label("もう一回引く", systemImage: "dice.fill")
                }
            }
            .navigationTitle("🎲 話題ガチャ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear(perform: roll)
        }
    }

    private func roll() {
        let talked = Set(partner?.talked ?? [])
        var pool: [Pick] = TopicData.unlockedTopics(premium: store.premium)
            .filter { !talked.contains($0.id) }
            .map { t in
                Pick(title: t.title, question: t.flow.q,
                     hint: t.flow.d.randomElement().map { ($0.tag, $0.text) },
                     note: nil)
            }
        pool += myTopics.filter { !talked.contains($0.key) }.map {
            Pick(title: "📝 MY話題", question: $0.text, hint: nil, note: $0.note)
        }
        picks = Array(pool.shuffled().prefix(3))
    }
}
