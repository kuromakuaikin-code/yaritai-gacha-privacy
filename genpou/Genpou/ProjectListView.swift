import SwiftUI
import SwiftData

/// HOME-01: 案件一覧
struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    @State private var searchText = ""
    @State private var showEditor = false
    @State private var projectToDelete: Project?

    private var filteredProjects: [Project] {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return projects }
        return projects.filter {
            $0.name.localizedCaseInsensitiveContains(keyword)
                || ($0.clientName ?? "").localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        Group {
            if projects.isEmpty {
                ContentUnavailableView {
                    Label("案件がありません", systemImage: "folder.badge.plus")
                } description: {
                    Text("右上の＋から最初の案件を作成しましょう")
                }
            } else {
                List {
                    ForEach(filteredProjects) { project in
                        NavigationLink(value: project.id) {
                            ProjectRow(project: project)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                projectToDelete = project
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "案件名・発注者で検索")
            }
        }
        .navigationTitle("案件")
        .navigationDestination(for: UUID.self) { projectId in
            if let project = projects.first(where: { $0.id == projectId }) {
                ProjectDetailView(project: project)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("案件を追加")
            }
        }
        .sheet(isPresented: $showEditor) {
            ProjectEditorView(project: nil)
        }
        .alert("案件を削除しますか？", isPresented: Binding(
            get: { projectToDelete != nil },
            set: { if !$0 { projectToDelete = nil } }
        )) {
            Button("削除", role: .destructive) {
                if let project = projectToDelete {
                    delete(project)
                }
                projectToDelete = nil
            }
            Button("キャンセル", role: .cancel) {
                projectToDelete = nil
            }
        } message: {
            Text("「\(projectToDelete?.name ?? "")」の写真もすべて削除されます。この操作は取り消せません。")
        }
    }

    private func delete(_ project: Project) {
        MediaStore.deletePhotosDir(projectId: project.id)
        modelContext.delete(project) // SitePhoto は cascade で削除
    }
}

private struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.name)
                .font(.headline)
            HStack(spacing: 12) {
                Text(project.status.labelJP)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(project.status == .completed ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                    .foregroundStyle(project.status == .completed ? Color.green : Color.blue)
                    .clipShape(Capsule())
                Label("\(project.photos.count)枚", systemImage: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(project.lastActivityAt, format: .dateTime.year().month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ProjectListView()
    }
    .environment(SubscriptionManager())
    .modelContainer(PreviewData.container)
}
