import SwiftUI
import SwiftData

/// PRJ-01: 案件詳細（写真グリッド + PDF 出力の起点）
struct ProjectDetailView: View {
    @Environment(SubscriptionManager.self) private var subscription

    let project: Project

    @State private var selectedTag: PhotoTag?
    @State private var showEditor = false
    @State private var showPhotoAdd = false
    @State private var showPaywall = false
    @State private var selectedPhoto: SitePhoto?
    @State private var reportMode: ReportMode?

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    private var filteredPhotos: [SitePhoto] {
        let sorted = project.photos.sorted { $0.takenAt > $1.takenAt }
        guard let selectedTag else { return sorted }
        return sorted.filter { $0.tag == selectedTag }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                tagChips
                photoGrid
            }
            .padding(.bottom, 90)
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("編集") { showEditor = true }
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(isPresented: $showEditor) {
            ProjectEditorView(project: project)
        }
        .sheet(isPresented: $showPhotoAdd) {
            PhotoAddView(project: project)
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailSheet(photo: photo)
        }
        .sheet(item: $reportMode) { mode in
            ReportBuilderView(project: project, mode: mode)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - パーツ

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(project.status.labelJP)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(project.status == .completed ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                    .foregroundStyle(project.status == .completed ? Color.green : Color.blue)
                    .clipShape(Capsule())
                Spacer()
                Text("写真 \(project.photos.count)枚")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let siteAddress = project.siteAddress {
                Label(siteAddress, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
            }
            if let clientName = project.clientName {
                Label(clientName, systemImage: "building.2")
                    .font(.subheadline)
            }
            if let start = project.startDate {
                let endText = project.endDate.map { DateFormats.dateJP.string(from: $0) } ?? ""
                Label("\(DateFormats.dateJP.string(from: start)) 〜 \(endText)", systemImage: "calendar")
                    .font(.subheadline)
            }
            if let note = project.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var tagChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "すべて", tag: nil)
                ForEach(PhotoTag.allCases) { tag in
                    chip(label: tag.labelJP, tag: tag)
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(label: String, tag: PhotoTag?) -> some View {
        let isSelected = selectedTag == tag
        return Button {
            selectedTag = tag
        } label: {
            Text(label)
                .font(.subheadline.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var photoGrid: some View {
        if filteredPhotos.isEmpty {
            ContentUnavailableView {
                Label("写真がありません", systemImage: "camera")
            } description: {
                Text("下の「写真を追加」から撮影またはアルバムから選択できます")
            }
            .padding(.top, 40)
        } else {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(filteredPhotos) { photo in
                    Button {
                        selectedPhoto = photo
                    } label: {
                        PhotoThumbnail(photo: photo)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                gated { showPhotoAdd = true }
            } label: {
                Label("写真を追加", systemImage: "camera.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)

            Button {
                gated { reportMode = .daily }
            } label: {
                Label("日報PDF", systemImage: "doc.text")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)

            Button {
                gated { reportMode = .completion }
            } label: {
                Label("完了報告", systemImage: "checkmark.seal")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// 課金ゲート: expired なら Paywall を表示
    private func gated(_ action: () -> Void) {
        if subscription.canUsePremiumFeatures {
            action()
        } else {
            showPaywall = true
        }
    }
}

/// グリッド用サムネイル
struct PhotoThumbnail: View {
    let photo: SitePhoto

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image = MediaStore.loadThumb(photo) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.secondarySystemBackground)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: geo.size.width, height: geo.size.width)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                Text(photo.tag.labelJP)
                    .font(.caption2.bold())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.55))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// 日付フォーマッタ（共用）
enum DateFormats {
    static let dateJP: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let fileDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}

#Preview {
    NavigationStack {
        ProjectDetailView(project: PreviewData.sampleProject)
    }
    .environment(SubscriptionManager())
    .modelContainer(PreviewData.container)
}
