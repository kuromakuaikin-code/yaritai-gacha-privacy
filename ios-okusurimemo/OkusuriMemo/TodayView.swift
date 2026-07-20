import SwiftUI
import SwiftData

// MARK: - 今日の服薬

struct TodayIntakeView: View {
    @Query(sort: \Medication.name) private var medications: [Medication]
    @Query private var allLogs: [IntakeLog]

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private var activeMedications: [Medication] {
        medications.filter { $0.isActive }
    }

    private var todayLogs: [IntakeLog] {
        allLogs.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private func medications(for slot: TimingSlot) -> [Medication] {
        activeMedications
            .filter { $0.timing.contains(slot) }
            .sorted { (($0.member?.name ?? ""), $0.name) < (($1.member?.name ?? ""), $1.name) }
    }

    private func log(for medication: Medication, slot: TimingSlot) -> IntakeLog? {
        todayLogs.first {
            $0.medication?.persistentModelID == medication.persistentModelID && $0.timingRaw == slot.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if activeMedications.isEmpty {
                    ContentUnavailableView(
                        "本日のお薬はありません",
                        systemImage: "pills",
                        description: Text("「お薬一覧」タブから、ご家族とお薬を登録しましょう")
                    )
                } else {
                    List {
                        ForEach(TimingSlot.allCases) { slot in
                            let meds = medications(for: slot)
                            if !meds.isEmpty {
                                Section {
                                    ForEach(meds) { med in
                                        IntakeRow(medication: med, slot: slot, date: today, log: log(for: med, slot: slot))
                                    }
                                } header: {
                                    Label(slot.label, systemImage: slot.icon)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("今日の服薬")
        }
    }
}

private struct IntakeRow: View {
    @Environment(\.modelContext) private var context
    let medication: Medication
    let slot: TimingSlot
    let date: Date
    let log: IntakeLog?

    private var taken: Bool { log?.taken ?? false }

    var body: some View {
        Button {
            toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(taken ? Color.appTint : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(medication.member?.name ?? "家族未設定") ・ \(medication.name)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .strikethrough(taken, color: .secondary)
                    Text(medication.dosage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle() {
        if let log {
            log.taken.toggle()
        } else {
            let newLog = IntakeLog()
            newLog.date = date
            newLog.timing = slot
            newLog.taken = true
            newLog.medication = medication
            context.insert(newLog)
        }
    }
}
