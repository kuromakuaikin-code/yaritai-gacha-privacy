import SwiftUI
import SwiftData

enum ReportMode: String, Identifiable {
    case daily, completion
    var id: String { rawValue }

    var titleJP: String {
        switch self {
        case .daily: return "日報PDF"
        case .completion: return "完了報告PDF"
        }
    }
}

/// PDF-01: 日報 / 完了報告の写真選択 + PDF 生成
struct ReportBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscription
    @Query private var profiles: [CompanyProfile]

    let project: Project
    let mode: ReportMode

    @State private var reportDate = Date()
    @State private var checkedIds: Set<UUID> = []
    @State private var initialized = false
    @State private var isGenerating = false
    @State private var generatedURL: URL?
    @State private var errorMessage: String?
    @State private var showPaywall = false

    /// 対象候補の写真（daily: その日 / completion: 全写真）
    private var candidates: [SitePhoto] {
        switch mode {
        case .daily:
            return project.photos
                .filter { Calendar.current.isDate($0.takenAt, inSameDayAs: reportDate) }
                .sorted { $0.takenAt < $1.takenAt }
        case .completion:
            return project.photos.sorted { $0.takenAt < $1.takenAt }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if mode == .daily {
                    Section {
                        DatePicker("日付", selection: $reportDate, displayedComponents: .date)
                    }
                }

                if candidates.isEmpty {
                    ContentUnavailableView {
                        Label("対象の写真がありません", systemImage: "photo")
                    } description: {
                        Text(mode == .daily ? "選択した日に撮影した写真がありません" : "この案件にはまだ写真がありません")
                    }
                } else if mode == .completion {
                    ForEach(PhotoTag.allCases) { tag in
                        let tagPhotos = candidates.filter { $0.tag == tag }
                        if !tagPhotos.isEmpty {
                            Section(tag.labelJP) {
                                ForEach(tagPhotos) { photo in
                                    photoRow(photo)
                                }
                            }
                        }
                    }
                } else {
                    Section("写真（\(checkedIds.count)/\(candidates.count)枚 選択中）") {
                        ForEach(candidates) { photo in
                            photoRow(photo)
                        }
                    }
                }
            }
            .navigationTitle(mode.titleJP)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Button {
                        generate()
                    } label: {
                        if isGenerating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        } else {
                            Label("PDFを作成", systemImage: "doc.badge.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(checkedIds.isEmpty || isGenerating)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(.bar)
            }
            .onAppear {
                if !initialized {
                    checkedIds = Set(candidates.map(\.id)) // デフォルト全 ON
                    initialized = true
                }
            }
            .onChange(of: reportDate) {
                checkedIds = Set(candidates.map(\.id))
            }
            .sheet(item: $generatedURL) { url in
                PDFPreviewView(url: url)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert("PDFを作成できませんでした", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func photoRow(_ photo: SitePhoto) -> some View {
        Button {
            if checkedIds.contains(photo.id) {
                checkedIds.remove(photo.id)
            } else {
                checkedIds.insert(photo.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: checkedIds.contains(photo.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(checkedIds.contains(photo.id) ? Color.accentColor : Color.secondary)
                if let thumb = MediaStore.loadThumb(photo) {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 52, height: 52)
                        .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(photo.tag.labelJP)
                            .font(.caption.bold())
                        Text(DateFormats.time.string(from: photo.takenAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let caption = photo.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func generate() {
        // 課金ゲート（仕様 7 章: expired は PDF 生成不可）
        guard subscription.canUsePremiumFeatures else {
            showPaywall = true
            return
        }
        guard let profile = profiles.first else {
            errorMessage = "会社情報が未登録です。設定から登録してください。"
            return
        }
        let selectedPhotos = candidates.filter { checkedIds.contains($0.id) }
        guard !selectedPhotos.isEmpty else { return }

        isGenerating = true
        // 画像描画を含むため一拍置いて実行（UI のスピナー表示を反映させる）
        DispatchQueue.main.async {
            defer { isGenerating = false }
            do {
                let service = PDFReportService()
                switch mode {
                case .daily:
                    generatedURL = try service.makeDailyReport(project: project,
                                                               date: reportDate,
                                                               photos: selectedPhotos,
                                                               profile: profile)
                case .completion:
                    generatedURL = try service.makeCompletionReport(project: project,
                                                                    photos: selectedPhotos,
                                                                    profile: profile)
                }
            } catch {
                errorMessage = "生成中にエラーが発生しました。空き容量をご確認ください。"
            }
        }
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    ReportBuilderView(project: PreviewData.sampleProject, mode: .completion)
        .environment(SubscriptionManager())
        .modelContainer(PreviewData.container)
}
