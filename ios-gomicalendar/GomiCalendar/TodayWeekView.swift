import SwiftUI
import SwiftData

struct TodayWeekView: View {
    @Query(sort: \GarbageRule.createdAt) private var rules: [GarbageRule]

    private var today: Date { Date() }
    private var tomorrow: Date { Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today }

    private var todayRules: [GarbageRule] { rules.filter { $0.applies(on: today) } }
    private var tomorrowRules: [GarbageRule] { rules.filter { $0.applies(on: tomorrow) } }

    private var upcomingDays: [(date: Date, rules: [GarbageRule])] {
        (0..<7).compactMap { offset -> (date: Date, rules: [GarbageRule])? in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: today) else { return nil }
            return (date, rules.filter { $0.applies(on: date) })
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TodayCard(date: today, rules: todayRules)

                    if !rules.isEmpty {
                        TomorrowRow(rules: tomorrowRules)
                    }

                    if rules.isEmpty {
                        ContentUnavailableView(
                            "ルールが未登録です",
                            systemImage: "trash",
                            description: Text("「ルール設定」タブから、ごみの収集ルールを追加しましょう")
                        )
                        .padding(.top, 40)
                    } else {
                        WeekListSection(days: upcomingDays)
                    }
                }
                .padding(16)
            }
            .navigationTitle("今日・今週")
        }
    }
}

// MARK: - 今日のカード

struct TodayCard: View {
    let date: Date
    let rules: [GarbageRule]

    private var firstNote: String? {
        rules.first { !$0.note.isEmpty }?.note
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(shortDateLabel(date))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("今日出せるごみ")
                .font(.title3.weight(.bold))

            if rules.isEmpty {
                Text("登録されたルールに該当する収集はありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(rules) { rule in
                        CategoryChip(rule: rule)
                    }
                }

                if let firstNote {
                    Label(firstNote, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
    }
}

// MARK: - 明日は？

struct TomorrowRow: View {
    let rules: [GarbageRule]

    var body: some View {
        HStack(spacing: 8) {
            Text("明日は？")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if rules.isEmpty {
                Text("収集なし")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rules) { rule in
                    CategoryChip(rule: rule, compact: true)
                }
            }
            Spacer()
        }
    }
}

// MARK: - 今後7日間

struct WeekListSection: View {
    let days: [(date: Date, rules: [GarbageRule])]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今後7日間")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    DayRow(date: day.date, rules: day.rules)
                    if index < days.count - 1 {
                        Divider().padding(.leading, 76)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        }
    }
}

struct DayRow: View {
    let date: Date
    let rules: [GarbageRule]

    private var badge: String? {
        if Calendar.current.isDateInToday(date) { return "今日" }
        if Calendar.current.isDateInTomorrow(date) { return "明日" }
        return nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(shortDateLabel(date))
                    .font(.subheadline.weight(.semibold))
                if let badge {
                    Text(badge)
                        .font(.caption2)
                        .foregroundStyle(Color.gomiTint)
                }
            }
            .frame(width: 64, alignment: .leading)

            if rules.isEmpty {
                Text("収集なし")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(rules) { rule in
                        CategoryChip(rule: rule, compact: true)
                    }
                }
            }

            Spacer()
        }
        .padding(12)
    }
}

// MARK: - カテゴリチップ

struct CategoryChip: View {
    let rule: GarbageRule
    var compact: Bool = false

    var body: some View {
        Text(rule.categoryName.isEmpty ? "(名称未設定)" : rule.categoryName)
            .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(rule.color.opacity(0.18))
            .foregroundStyle(rule.color)
            .clipShape(Capsule())
    }
}
