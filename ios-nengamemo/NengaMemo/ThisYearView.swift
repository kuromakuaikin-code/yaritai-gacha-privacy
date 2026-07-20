import SwiftUI
import SwiftData

// MARK: - 今年の記録（チェックリスト）

struct ThisYearView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Contact.name) private var contacts: [Contact]
    @Query private var allLogs: [GiftLog]

    @State private var selectedYear = currentYear()
    @State private var searchText = ""

    private var filteredContacts: [Contact] {
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var logsThisYear: [GiftLog] {
        allLogs.filter { $0.year == selectedYear }
    }

    /// 年賀状を送付済みの件数（集計用の主要指標）
    private var sentCount: Int {
        contacts.filter { contact in
            logsThisYear.contains { $0.contact === contact && $0.occasion == .nengajo && $0.sent }
        }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if contacts.isEmpty {
                    ContentUnavailableView(
                        "宛先がありません",
                        systemImage: "checklist",
                        description: Text("まず「宛先一覧」タブから宛先を登録してください")
                    )
                } else {
                    List {
                        Section {
                            HStack {
                                Text("送付済み（年賀状）")
                                Spacer()
                                Text("\(sentCount) / 全\(contacts.count)件")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.nengaRed)
                            }
                            Stepper("対象年：\(selectedYear)年", value: $selectedYear, in: 2000...2100)
                        }

                        Section {
                            ForEach(filteredContacts) { contact in
                                ContactYearRow(
                                    contact: contact,
                                    year: selectedYear,
                                    logs: logsThisYear.filter { $0.contact === contact }
                                )
                            }
                        } footer: {
                            Text("年賀状・お中元・お歳暮それぞれについて「送った」「もらった」をタップすると記録されます。宛先をタップすると詳しい履歴を編集できます。")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "名前で検索")
            .navigationTitle("今年の記録")
        }
    }
}

// MARK: - 宛先1件分のチェック行

private struct ContactYearRow: View {
    let contact: Contact
    let year: Int
    let logs: [GiftLog]

    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name.isEmpty ? "(名前未入力)" : contact.name)
                    .font(.subheadline.weight(.semibold))
                if !contact.relationship.isEmpty {
                    Text(contact.relationship)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                occasionRow(.nengajo)
                occasionRow(.ochugen)
                occasionRow(.oseibo)
            }
        }
        .padding(.vertical, 4)
    }

    private func occasionRow(_ occasion: Occasion) -> some View {
        HStack(spacing: 8) {
            Label(occasion.label, systemImage: occasion.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(occasion.color)
                .frame(width: 84, alignment: .leading)

            CheckChip(label: "送った", isOn: log(for: occasion)?.sent ?? false) {
                toggle(occasion, keyPath: \.sent)
            }
            CheckChip(label: "もらった", isOn: log(for: occasion)?.received ?? false) {
                toggle(occasion, keyPath: \.received)
            }
            Spacer()
        }
    }

    private func log(for occasion: Occasion) -> GiftLog? {
        logs.first { $0.occasion == occasion }
    }

    private func toggle(_ occasion: Occasion, keyPath: ReferenceWritableKeyPath<GiftLog, Bool>) {
        if let existing = log(for: occasion) {
            existing[keyPath: keyPath].toggle()
        } else {
            let newLog = GiftLog(occasion: occasion, year: year, contact: contact)
            newLog[keyPath: keyPath] = true
            context.insert(newLog)
        }
    }
}

private struct CheckChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: isOn ? "checkmark.square.fill" : "square")
                .font(.caption)
                .foregroundStyle(isOn ? Color.nengaRed : .secondary)
        }
        .buttonStyle(.plain)
    }
}
