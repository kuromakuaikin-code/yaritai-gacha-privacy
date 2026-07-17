import SwiftUI
import SwiftData

/// 案件の新規作成・編集フォーム（project = nil なら新規）
struct ProjectEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let project: Project?

    @State private var name = ""
    @State private var siteAddress = ""
    @State private var clientName = ""
    @State private var hasPeriod = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var note = ""
    @State private var status: ProjectStatus = .inProgress

    private var isNew: Bool { project == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("案件名（必須）") {
                    TextField("例: ○○ビル 3F 電気工事", text: $name)
                }
                Section("現場情報") {
                    TextField("現場住所", text: $siteAddress)
                    TextField("発注者（元請け）", text: $clientName)
                }
                Section("工期") {
                    Toggle("工期を入力", isOn: $hasPeriod.animation())
                    if hasPeriod {
                        DatePicker("開始", selection: $startDate, displayedComponents: .date)
                        DatePicker("終了", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }
                Section("ステータス") {
                    Picker("ステータス", selection: $status) {
                        ForEach(ProjectStatus.allCases) { s in
                            Text(s.labelJP).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("メモ") {
                    TextField("メモ", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isNew ? "新しい案件" : "案件を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let project else { return }
        name = project.name
        siteAddress = project.siteAddress ?? ""
        clientName = project.clientName ?? ""
        if let start = project.startDate {
            hasPeriod = true
            startDate = start
            endDate = project.endDate ?? start
        }
        note = project.note ?? ""
        status = project.status
    }

    private func save() {
        let target = project ?? {
            let newProject = Project()
            modelContext.insert(newProject)
            return newProject
        }()
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.siteAddress = siteAddress.isEmpty ? nil : siteAddress
        target.clientName = clientName.isEmpty ? nil : clientName
        target.startDate = hasPeriod ? startDate : nil
        target.endDate = hasPeriod ? endDate : nil
        target.note = note.isEmpty ? nil : note
        target.status = status
        dismiss()
    }
}

#Preview {
    ProjectEditorView(project: nil)
        .modelContainer(PreviewData.container)
}
