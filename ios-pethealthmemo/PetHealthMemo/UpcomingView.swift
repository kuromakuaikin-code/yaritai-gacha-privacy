import SwiftUI
import SwiftData

// MARK: - 次回予定

struct UpcomingView: View {
    @Environment(\.modelContext) private var context
    @Query private var allRecords: [HealthRecord]

    private var upcoming: [HealthRecord] {
        allRecords
            .filter { $0.nextDueDate != nil }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if upcoming.isEmpty {
                    ContentUnavailableView(
                        "予定はありません",
                        systemImage: "calendar.badge.clock",
                        description: Text("記録の追加・編集画面で「次回予定日」を設定すると、ここに一覧表示されます")
                    )
                } else {
                    List {
                        Section {
                            ForEach(upcoming) { record in
                                UpcomingRow(record: record)
                            }
                        } footer: {
                            Text("行をタップすると「対応済み」として次回予定日をクリアできます")
                        }
                    }
                }
            }
            .navigationTitle("次回予定")
        }
    }
}

private struct UpcomingRow: View {
    @Bindable var record: HealthRecord

    var body: some View {
        Button {
            record.nextDueDate = nil
        } label: {
            HStack(spacing: 12) {
                Image(systemName: record.kind.icon)
                    .foregroundStyle(record.kind.color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(record.pet?.name.isEmpty == false ? record.pet!.name : "(ペット未設定)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(record.kind.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let due = record.nextDueDate {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(mediumDate(due))
                            .font(.subheadline.weight(.semibold))
                        Text(daysUntilLabel(due))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isOverdue(due) ? .red : AppConfig.tintColor)
                    }
                }

                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
