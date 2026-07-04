import SwiftUI
import SwiftData

// MARK: - お相手詳細

struct PartnerDetailView: View {
    @EnvironmentObject private var store: PurchaseStore
    @Bindable var partner: Partner

    @State private var editProfile = false
    @State private var editingRecord: DateRecord?
    @State private var addRecord = false

    var body: some View {
        List {
            Section {
                profileHeader
                if !partner.likes.isEmpty { info("好きなもの", partner.likes) }
                if !partner.ng.isEmpty { info("NG・地雷", partner.ng, color: .red) }
                if !partner.memo.isEmpty { info("メモ", partner.memo) }
            }

            Section {
                NavigationLink {
                    BriefView(partner: partner)
                } label: {
                    Label("デート前カンペ", systemImage: "list.clipboard")
                }
                NavigationLink {
                    TopicChecklistView(partner: partner)
                } label: {
                    HStack {
                        Label("話題チェック", systemImage: "bubble.left.and.bubble.right")
                        Spacer()
                        Text("\(talkedCount) / \(totalTopics) 話した")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("デート記録（\(partner.dates.count)回）") {
                let sorted = partner.sortedDates
                if sorted.isEmpty {
                    Text("まだ記録がありません。デートの後に振り返りを残しましょう。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(Array(sorted.enumerated()), id: \.element.persistentModelID) { i, record in
                    Button {
                        editingRecord = record
                    } label: {
                        DateRecordRow(record: record, number: sorted.count - i)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(partner.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編集") { editProfile = true }
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    addRecord = true
                } label: {
                    Label("デート記録を追加", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $editProfile) { PartnerFormView(partner: partner) }
        .sheet(isPresented: $addRecord) { DateFormView(partner: partner, record: nil) }
        .sheet(item: $editingRecord) { record in
            DateFormView(partner: partner, record: record)
        }
    }

    @Query private var myTopics: [MyTopic]

    private var talkedCount: Int {
        let valid = Set(TopicData.unlockedTopics(premium: store.premium).map(\.id))
            .union(myTopics.map(\.key))
        return partner.talked.filter { valid.contains($0) }.count
    }

    private var totalTopics: Int {
        TopicData.unlockedTopics(premium: store.premium).count + myTopics.count
    }

    private var profileHeader: some View {
        HStack(spacing: 12) {
            AvatarView(name: partner.name)
            VStack(alignment: .leading, spacing: 2) {
                Text(partner.name).font(.headline)
                Text([partner.age.isEmpty ? nil : "\(partner.age)歳",
                      partner.job.isEmpty ? nil : partner.job,
                      partner.metVia.isEmpty ? nil : partner.metVia]
                    .compactMap { $0 }.joined(separator: "・"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(partner.status.label)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(partner.status.color.opacity(0.15))
                .foregroundStyle(partner.status.color)
                .clipShape(Capsule())
        }
    }

    private func info(_ title: String, _ text: String, color: Color = .secondary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(color)
            Text(text).font(.subheadline)
        }
    }
}

struct DateRecordRow: View {
    let record: DateRecord
    let number: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("\(number)回目")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.pink.opacity(0.12))
                    .foregroundStyle(.pink)
                    .clipShape(Capsule())
                Text(mediumDate(record.date)).font(.subheadline.weight(.bold))
                Text(record.place).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            if record.rating > 0 {
                Text(String(repeating: "★", count: record.rating)
                     + String(repeating: "☆", count: 5 - record.rating))
                    .font(.caption).foregroundStyle(.orange)
            }
            if !record.topics.isEmpty { Text(record.topics).font(.footnote) }
            if !record.good.isEmpty { labeled("👍 良かったこと", record.good, .green) }
            if !record.bad.isEmpty { labeled("🤔 気になったこと", record.bad, .red) }
            if !record.next.isEmpty || record.nextDate != nil {
                labeled("📌 次回・宿題" + (record.nextDate.map { "（\(mediumDate($0))）" } ?? ""),
                        record.next, .blue)
            }
        }
        .padding(.vertical, 2)
    }

    private func labeled(_ title: String, _ text: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(color)
            if !text.isEmpty { Text(text).font(.footnote) }
        }
    }
}

// MARK: - デート記録フォーム

struct DateFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let partner: Partner
    let record: DateRecord?

    @State private var date = Date()
    @State private var place = ""
    @State private var topics = ""
    @State private var good = ""
    @State private var bad = ""
    @State private var next = ""
    @State private var hasNextDate = false
    @State private var nextDate = Date()
    @State private var rating = 0
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                    TextField("場所・プラン", text: $place)
                    HStack {
                        Text("手応え")
                        Spacer()
                        ForEach(1...5, id: \.self) { n in
                            Button {
                                rating = (rating == n) ? 0 : n
                            } label: {
                                Image(systemName: n <= rating ? "star.fill" : "star")
                                    .foregroundStyle(.orange)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("振り返り") {
                    TextField("話したこと・内容", text: $topics, axis: .vertical)
                    TextField("👍 良かったこと", text: $good, axis: .vertical)
                    TextField("🤔 気になったこと", text: $bad, axis: .vertical)
                }
                Section("次回") {
                    TextField("📌 次回の予定・宿題", text: $next, axis: .vertical)
                    Toggle("次回の予定日が決まっている", isOn: $hasNextDate)
                    if hasNextDate {
                        DatePicker("予定日", selection: $nextDate, displayedComponents: .date)
                    }
                }
                if record != nil {
                    Section {
                        Button("この記録を削除", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(record == nil ? "デート記録を追加" : "デート記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear(perform: load)
            .confirmationDialog("この記録を削除します。よろしいですか？",
                                isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("削除する", role: .destructive) {
                    if let record { context.delete(record) }
                    partner.updatedAt = Date()
                    dismiss()
                }
            }
        }
    }

    private func load() {
        guard let r = record else { return }
        date = r.date; place = r.place; topics = r.topics
        good = r.good; bad = r.bad; next = r.next; rating = r.rating
        if let nd = r.nextDate { hasNextDate = true; nextDate = nd }
    }

    private func save() {
        let r = record ?? DateRecord()
        r.date = date; r.place = place; r.topics = topics
        r.good = good; r.bad = bad; r.next = next
        r.nextDate = hasNextDate ? nextDate : nil
        r.rating = rating
        if record == nil { partner.dates.append(r) }
        partner.updatedAt = Date()
        dismiss()
    }
}

// MARK: - デート前カンペ

struct BriefView: View {
    @EnvironmentObject private var store: PurchaseStore
    @Query(sort: \MyTopic.order) private var myTopics: [MyTopic]
    let partner: Partner

    @State private var showGacha = false

    var body: some View {
        List {
            if let nd = partner.nextUpcoming {
                Section {
                    Label("\(mediumDate(nd))（\(daysUntilLabel(nd))） \(partner.lastDate?.next ?? "")",
                          systemImage: "pin.fill")
                        .foregroundStyle(.blue)
                }
            }
            if !partner.ng.isEmpty {
                Section("⚠️ NG・地雷（触れない）") {
                    Text(partner.ng).foregroundStyle(.red)
                }
            }
            if !partner.likes.isEmpty {
                Section("💚 好きなもの・趣味") { Text(partner.likes) }
            }
            if let last = partner.lastDate {
                Section("🕐 前回のデート（\(mediumDate(last.date))\(last.place.isEmpty ? "" : "・" + last.place)）") {
                    if !last.good.isEmpty { Text("👍 " + last.good) }
                    if !last.bad.isEmpty { Text("🤔 " + last.bad) }
                }
            }
            Section("💬 まだ話していない話題") {
                let untalked = untalkedTitles.prefix(5)
                if untalked.isEmpty {
                    Text("解放中の話題は全て話しました 🎉")
                } else {
                    ForEach(Array(untalked), id: \.self) { Text($0) }
                }
                Button {
                    showGacha = true
                } label: {
                    Label("話題ガチャで3つ引く", systemImage: "dice")
                }
            }
        }
        .navigationTitle("デート前カンペ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGacha) { GachaView(partner: partner) }
    }

    private var untalkedTitles: [String] {
        let talked = Set(partner.talked)
        var titles = TopicData.unlockedTopics(premium: store.premium)
            .filter { !talked.contains($0.id) }.map(\.title)
        titles += myTopics.filter { !talked.contains($0.key) }.map(\.text)
        return titles
    }
}
