import SwiftUI
import SwiftData

// MARK: - お相手一覧

enum PartnerSort: String, CaseIterable, Identifiable {
    case updated, upcoming, lastDate, rating
    var id: String { rawValue }
    var label: String {
        switch self {
        case .updated:  return "更新順"
        case .upcoming: return "予定が近い順"
        case .lastDate: return "デート日順"
        case .rating:   return "評価順"
        }
    }
}

struct PartnerListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query private var partners: [Partner]

    @State private var search = ""
    @State private var filter: PartnerStatus?
    @State private var sort: PartnerSort = .updated
    @State private var showForm = false
    @State private var showPaywall = false

    private var filtered: [Partner] {
        var list = partners
        if let filter { list = list.filter { $0.status == filter } }
        if !search.isEmpty {
            list = list.filter {
                ($0.name + $0.job + $0.metVia + $0.memo).localizedCaseInsensitiveContains(search)
            }
        }
        switch sort {
        case .updated:
            return list.sorted { $0.updatedAt > $1.updatedAt }
        case .upcoming:
            return list.sorted {
                ($0.nextUpcoming ?? .distantFuture) < ($1.nextUpcoming ?? .distantFuture)
            }
        case .lastDate:
            return list.sorted {
                ($0.lastDate?.date ?? .distantPast) > ($1.lastDate?.date ?? .distantPast)
            }
        case .rating:
            return list.sorted { $0.avgRating > $1.avgRating }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if partners.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("婚活デートメモ")
            .searchable(text: $search, prompt: "名前・職業・出会いで検索")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("並び替え", selection: $sort) {
                            ForEach(PartnerSort.allCases) { s in
                                Text(s.label).tag(s)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if !store.premium && partners.count >= AppConfig.freePartnerLimit {
                            showPaywall = true
                        } else {
                            showForm = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showForm) { PartnerFormView(partner: nil) }
            .sheet(isPresented: $showPaywall) {
                PaywallView(message: "無料版で登録できるお相手は\(AppConfig.freePartnerLimit)人までです。プレミアムで無制限になります。")
            }
        }
    }

    private var list: some View {
        List {
            Section {
                statusFilter
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            ForEach(filtered) { p in
                NavigationLink(value: p) {
                    PartnerRow(partner: p)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: Partner.self) { p in
            PartnerDetailView(partner: p)
        }
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView("条件に合うお相手が見つかりません",
                                       systemImage: "magnifyingglass")
            }
        }
    }

    private var statusFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, label: "すべて", color: .pink)
                ForEach(PartnerStatus.allCases) { s in
                    chip(s, label: s.label, color: s.color)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
    }

    private func chip(_ status: PartnerStatus?, label: String, color: Color) -> some View {
        let on = filter == status
        return Button(label) { filter = status }
            .font(.footnote.weight(.bold))
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(on ? color.opacity(0.15) : Color(.secondarySystemBackground))
            .foregroundStyle(on ? color : .secondary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(on ? color : .clear, lineWidth: 1))
            .buttonStyle(.plain)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("お相手がまだ登録されていません", systemImage: "heart")
        } description: {
            Text("右上の「＋」から追加しましょう。")
        } actions: {
            Button("サンプルデータを入れてみる") {
                context.insert(SampleData.makePartner())
            }
            .buttonStyle(.bordered)
        }
    }
}

struct PartnerRow: View {
    let partner: Partner

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                AvatarView(name: partner.name)
                VStack(alignment: .leading, spacing: 1) {
                    Text(partner.name).font(.headline)
                    Text(meta).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(partner.status.label)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(partner.status.color.opacity(0.15))
                    .foregroundStyle(partner.status.color)
                    .clipShape(Capsule())
            }
            HStack(spacing: 10) {
                Text("💬 \(partner.dates.count)回")
                if let last = partner.lastDate {
                    Text("📅 \(mediumDate(last.date))")
                }
                if partner.avgRating > 0 {
                    Text(String(repeating: "★", count: partner.avgRating))
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let nd = partner.nextUpcoming {
                Text("📌 次回：\(mediumDate(nd))（\(daysUntilLabel(nd))） \(partner.lastDate?.next ?? "")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            } else if let next = partner.lastDate?.next, !next.isEmpty {
                Text("📌 次回：\(next)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private var meta: String {
        [partner.age.isEmpty ? nil : "\(partner.age)歳",
         partner.job.isEmpty ? nil : partner.job,
         partner.metVia.isEmpty ? nil : partner.metVia]
            .compactMap { $0 }.joined(separator: "・")
    }
}

struct AvatarView: View {
    let name: String

    private static let palette: [Color] = [.pink, .blue, .green, .orange, .purple, .teal]

    var body: some View {
        let color = Self.palette[abs(name.hashValue) % Self.palette.count]
        Text(String(name.prefix(1)))
            .font(.headline)
            .frame(width: 44, height: 44)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Circle())
    }
}

// MARK: - お相手フォーム

struct PartnerFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let partner: Partner?

    @State private var name = ""
    @State private var age = ""
    @State private var job = ""
    @State private var metVia = ""
    @State private var likes = ""
    @State private var ng = ""
    @State private var memo = ""
    @State private var status: PartnerStatus = .active
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("名前・ニックネーム（必須）", text: $name)
                    TextField("年齢", text: $age).keyboardType(.numberPad)
                    TextField("職業", text: $job)
                    TextField("出会い（例：婚活アプリ、相談所）", text: $metVia)
                }
                Section("ステータス") {
                    Picker("ステータス", selection: $status) {
                        ForEach(PartnerStatus.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("メモ") {
                    TextField("好きなもの・趣味", text: $likes, axis: .vertical)
                    TextField("NG・地雷（触れない話題など）", text: $ng, axis: .vertical)
                    TextField("メモ", text: $memo, axis: .vertical)
                }
                if partner != nil {
                    Section {
                        Button("このお相手を削除", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                }
            }
            .navigationTitle(partner == nil ? "お相手を追加" : "プロフィールを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
            .confirmationDialog("記録ごと削除します。よろしいですか？",
                                isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("削除する", role: .destructive) {
                    if let partner { context.delete(partner) }
                    dismiss()
                }
            }
        }
    }

    private func load() {
        guard let p = partner else { return }
        name = p.name; age = p.age; job = p.job; metVia = p.metVia
        likes = p.likes; ng = p.ng; memo = p.memo; status = p.status
    }

    private func save() {
        let p = partner ?? Partner()
        p.name = name.trimmingCharacters(in: .whitespaces)
        p.age = age; p.job = job; p.metVia = metVia
        p.likes = likes; p.ng = ng; p.memo = memo
        p.status = status
        p.updatedAt = Date()
        if partner == nil { context.insert(p) }
        dismiss()
    }
}
