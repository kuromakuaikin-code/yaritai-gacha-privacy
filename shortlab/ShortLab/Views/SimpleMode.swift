import SwiftUI
import PhotosUI
import Photos

// かんたんモード。多機能編集アプリで挫折する層(シニア・非クリエイター)向けに、
// 「えらぶ → ととのえる → ほぞん」の3画面一本道だけを見せる。
// エンジン層(EditorViewModel/CompositionEngine/ExportManager)はしっかり編集と完全共有で、
// このファイルはUIの絞り込みだけを担当する。
// 用語ルール: カタカナ専門語は使わない(トリム→切る、書き出し→ほぞん、BGM→音楽)。

struct SimpleModeView: View {
    @ObservedObject var viewModel: EditorViewModel
    var onOpenFullEditor: () -> Void

    enum Step: Int, CaseIterable {
        case pick = 0, adjust, save

        var title: String {
            switch self {
            case .pick: return "えらぶ"
            case .adjust: return "ととのえる"
            case .save: return "ほぞん"
            }
        }
    }

    @State private var step: Step = .pick
    @State private var showFullEditorConfirm = false
    @State private var showRestartConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            stepIndicator
                .padding(.vertical, 12)
            Divider()

            switch step {
            case .pick:
                SimplePickStep(viewModel: viewModel) { step = .adjust }
            case .adjust:
                SimpleAdjustStep(
                    viewModel: viewModel,
                    player: viewModel.playerController,
                    onBack: { step = .pick },
                    onNext: {
                        viewModel.playerController.pause()
                        step = .save
                    }
                )
            case .save:
                SimpleSaveStep(
                    viewModel: viewModel,
                    exporter: viewModel.exportManager,
                    onBack: { step = .adjust },
                    onRestart: { showRestartConfirm = true }
                )
            }
        }
        .background(Color(.systemBackground))
        .confirmationDialog(
            "しっかり編集モードにきりかえますか?\n(いまの動画はそのまま引きつがれます)",
            isPresented: $showFullEditorConfirm,
            titleVisibility: .visible
        ) {
            Button("きりかえる") { onOpenFullEditor() }
            Button("やめる", role: .cancel) {}
        }
        .confirmationDialog(
            "いまの動画を消して、さいしょからやりなおしますか?",
            isPresented: $showRestartConfirm,
            titleVisibility: .visible
        ) {
            Button("やりなおす", role: .destructive) { restart() }
            Button("やめる", role: .cancel) {}
        }
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            Text("かんたん動画")
                .font(.title3.bold())
            Spacer()
            // シニアが誤タップしないよう小さめ・端に配置
            Button("しっかり編集") { showFullEditorConfirm = true }
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                HStack(spacing: 6) {
                    Text("\(s.rawValue + 1)")
                        .font(.headline.bold())
                        .frame(width: 30, height: 30)
                        .background(s == step ? Color.blue : Color.gray.opacity(0.25), in: Circle())
                        .foregroundStyle(s == step ? Color.white : Color.secondary)
                    Text(s.title)
                        .font(s == step ? .headline.bold() : .subheadline)
                        .foregroundStyle(s == step ? Color.primary : Color.secondary)
                }
                if s != .save {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: 20)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func restart() {
        viewModel.playerController.pause()
        viewModel.exportManager.reset()
        viewModel.project = EditorProject()
        viewModel.selectedClipID = nil
        step = .pick
    }
}

// MARK: - 画面1: えらぶ

private struct SimplePickStep: View {
    @ObservedObject var viewModel: EditorViewModel
    var onNext: () -> Void

    @State private var pickerItems: [PhotosPickerItem] = []

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.project.clips.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "film")
                                .font(.system(size: 52))
                                .foregroundStyle(.secondary)
                            Text("さいしょに、動画をえらびましょう")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 48)
                    }

                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 10,
                        matching: .videos
                    ) {
                        // PhotosPicker はカスタム ButtonStyle が効かないためラベル側で装飾
                        BigButtonLabel(title: viewModel.project.clips.isEmpty ? "動画をえらぶ" : "動画をふやす",
                                       systemImage: "plus.circle.fill")
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }

                    if viewModel.isImporting {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("読みこんでいます…")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !viewModel.project.clips.isEmpty {
                        VStack(spacing: 10) {
                            Text("この順番でつながります")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(Array(viewModel.project.clips.enumerated()), id: \.element.id) { index, clip in
                                clipRow(index: index, clip: clip)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }

            Button {
                onNext()
            } label: {
                BigButtonLabel(title: "つぎへ", systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(BigPrimaryButtonStyle())
            .disabled(viewModel.project.clips.isEmpty)
            .opacity(viewModel.project.clips.isEmpty ? 0.4 : 1)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await viewModel.importClips(items: items)
                pickerItems = []
            }
        }
    }

    private func clipRow(index: Int, clip: VideoClip) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.headline.bold())
                .frame(width: 34, height: 34)
                .background(Color.blue.opacity(0.15), in: Circle())
                .foregroundStyle(.blue)
            Text("\(clip.timelineDuration, specifier: "%.0f")秒の動画")
                .font(.headline)
            Spacer()
            Button {
                viewModel.moveClip(id: clip.id, direction: -1)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .disabled(index == 0)
            .opacity(index == 0 ? 0.3 : 1)
            Button {
                viewModel.moveClip(id: clip.id, direction: 1)
            } label: {
                Image(systemName: "arrow.down")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .disabled(index == viewModel.project.clips.count - 1)
            .opacity(index == viewModel.project.clips.count - 1 ? 0.3 : 1)
            Button(role: .destructive) {
                viewModel.deleteClip(id: clip.id)
            } label: {
                Image(systemName: "trash")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - 画面2: ととのえる

private struct SimpleAdjustStep: View {
    @ObservedObject var viewModel: EditorViewModel
    // PlayerController の @Published は viewModel 経由では再描画されないため直接監視する
    @ObservedObject var player: PlayerController
    var onBack: () -> Void
    var onNext: () -> Void

    @State private var activeSheet: Sheet?

    enum Sheet: Identifiable {
        case text, music
        var id: Self { self }
    }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(spacing: 12) {
                    PreviewView(viewModel: viewModel)
                        .frame(maxHeight: 320)

                    playbackControls

                    VStack(spacing: 10) {
                        Text("いらない部分を切るには、切りたい場面で止めてボタンを押します")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 10) {
                            Button {
                                player.pause()
                                viewModel.cutBefore(timelineSeconds: player.currentTime)
                            } label: {
                                BigButtonLabel(title: "ここより前を切る", systemImage: "scissors")
                            }
                            .buttonStyle(BigSecondaryButtonStyle())
                            Button {
                                player.pause()
                                viewModel.cutAfter(timelineSeconds: player.currentTime)
                            } label: {
                                BigButtonLabel(title: "ここより後ろを切る", systemImage: "scissors")
                            }
                            .buttonStyle(BigSecondaryButtonStyle())
                        }
                        if viewModel.canUndo {
                            Button {
                                viewModel.undo()
                            } label: {
                                Label("もとにもどす", systemImage: "arrow.uturn.backward")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 2)
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            activeSheet = .text
                        } label: {
                            BigButtonLabel(title: "文字を入れる", systemImage: "textformat")
                        }
                        .buttonStyle(BigSecondaryButtonStyle())
                        Button {
                            activeSheet = .music
                        } label: {
                            BigButtonLabel(
                                title: viewModel.project.music == nil ? "音楽をつける" : "音楽をかえる",
                                systemImage: "music.note"
                            )
                        }
                        .buttonStyle(BigSecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            HStack(spacing: 12) {
                Button {
                    player.pause()
                    onBack()
                } label: {
                    BigButtonLabel(title: "もどる", systemImage: "arrow.left")
                }
                .buttonStyle(BigSecondaryButtonStyle())
                .frame(maxWidth: 140)
                Button {
                    onNext()
                } label: {
                    BigButtonLabel(title: "つぎへ", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(BigPrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .text: SimpleTextSheet(viewModel: viewModel)
            case .music: SimpleMusicSheet(viewModel: viewModel)
            }
        }
    }

    private var playbackControls: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                Button {
                    player.togglePlay()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.blue)
                }
                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ),
                    in: 0...max(player.duration, 0.01)
                )
                .tint(.blue)
                Text(timeString(player.currentTime))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 画面3: ほぞん

private struct SimpleSaveStep: View {
    @ObservedObject var viewModel: EditorViewModel
    // ExportManager の @Published も直接監視する(SimpleAdjustStep の player と同じ理由)
    @ObservedObject var exporter: ExportManager
    var onBack: () -> Void
    var onRestart: () -> Void

    @StateObject private var photoSaver = PhotoSaver()
    @State private var shareURL: URL?

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            switch exporter.state {
            case .idle:
                idleContent
            case .exporting(let progress):
                exportingContent(progress: progress)
            case .finished(let url):
                finishedContent(url: url)
            case .failed(let message):
                failedContent(message: message)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    exporter.reset()
                    photoSaver.reset()
                    onBack()
                } label: {
                    BigButtonLabel(title: "もどる", systemImage: "arrow.left")
                }
                .buttonStyle(BigSecondaryButtonStyle())
                .frame(maxWidth: 140)
                .disabled(isExporting)
                .opacity(isExporting ? 0.4 : 1)

                Button {
                    onRestart()
                } label: {
                    BigButtonLabel(title: "さいしょから", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(BigSecondaryButtonStyle())
                .disabled(isExporting)
                .opacity(isExporting ? 0.4 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .sheet(item: Binding(
            get: { shareURL.map { SimpleShareItem(url: $0) } },
            set: { if $0 == nil { shareURL = nil } }
        )) { item in
            ShareSheet(url: item.url)
        }
    }

    private var isExporting: Bool {
        if case .exporting = exporter.state { return true }
        return false
    }

    private var idleContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.and.arrow.down.on.square.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
            Text("できあがり: \(Int(viewModel.project.totalDuration.rounded()))秒の動画")
                .font(.title3.bold())
            // TODO: StoreKit 導入後は課金状態と連動(しっかり編集の ExportSheet と共通化)
            Text("無料版は、右下に小さく「ShortLab」のマークが入ります")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    await exporter.export(project: viewModel.project, showWatermark: true)
                }
            } label: {
                BigButtonLabel(title: "動画を作る", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(BigPrimaryButtonStyle())
        }
    }

    private func exportingContent(progress: Float) -> some View {
        VStack(spacing: 14) {
            ProgressView(value: progress)
                .tint(.blue)
            Text("\(Int(progress * 100))%")
                .font(.system(size: 44, weight: .bold).monospacedDigit())
            Text("動画を作っています。\nこのまま少しお待ちください")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func finishedContent(url: URL) -> some View {
        VStack(spacing: 14) {
            switch photoSaver.state {
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                Text("写真に ほぞんしました")
                    .font(.title2.bold())
                Text("「写真」アプリからいつでも見られます")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            default:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("動画ができました!")
                    .font(.title2.bold())
            }

            if photoSaver.state != .saved {
                Button {
                    photoSaver.save(url: url)
                } label: {
                    BigButtonLabel(title: photoSaver.state == .saving ? "ほぞん中…" : "写真に ほぞんする",
                                   systemImage: "square.and.arrow.down")
                }
                .buttonStyle(BigPrimaryButtonStyle())
                .disabled(photoSaver.state == .saving)
            }

            Button {
                shareURL = url
            } label: {
                BigButtonLabel(title: "LINEなどで送る", systemImage: "paperplane.fill")
            }
            .buttonStyle(BigSecondaryButtonStyle())
        }
    }

    private func failedContent(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("うまくいきませんでした")
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                exporter.reset()
            } label: {
                BigButtonLabel(title: "やりなおす", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(BigPrimaryButtonStyle())
        }
    }
}

// MARK: - 文字入れシート(位置は上・まんなか・下の3択、スタイル固定)

private struct SimpleTextSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var position: TextPosition = .bottom

    enum TextPosition: String, CaseIterable, Identifiable {
        case top = "上", middle = "まんなか", bottom = "下"
        var id: Self { self }

        var point: CGPoint {
            switch self {
            case .top: return CGPoint(x: 0.5, y: 0.15)
            case .middle: return CGPoint(x: 0.5, y: 0.5)
            case .bottom: return CGPoint(x: 0.5, y: 0.8)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("入れたい文字") {
                    TextField("たとえば: 運動会", text: $text)
                        .font(.title3)
                }
                Section("文字の場所") {
                    Picker("場所", selection: $position) {
                        ForEach(TextPosition.allCases) { pos in
                            Text(pos.rawValue).tag(pos)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if !viewModel.project.textOverlays.isEmpty {
                    Section("入っている文字") {
                        ForEach(viewModel.project.textOverlays) { overlay in
                            HStack {
                                Text(overlay.text)
                                    .font(.headline)
                                Spacer()
                                Button("けす", role: .destructive) {
                                    viewModel.removeOverlay(id: overlay.id)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("文字を入れる")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("とじる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("入れる") {
                        viewModel.addTextOverlay(text: text, fontSize: 96, position: position.point)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 音楽シート(なし+バンドル曲の択一)

private struct SimpleMusicSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    viewModel.setMusic(nil)
                    dismiss()
                } label: {
                    row(name: "音楽なし", icon: "speaker.slash",
                        isSelected: viewModel.project.music == nil)
                }
                ForEach(BGMLibrary.tracks()) { track in
                    Button {
                        viewModel.setMusic(track)
                        dismiss()
                    } label: {
                        row(name: track.name, icon: "music.note",
                            isSelected: viewModel.project.music?.name == track.name)
                    }
                }
                if BGMLibrary.tracks().isEmpty {
                    Text("音楽ファイルが未追加です(README参照)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("音楽をつける")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("とじる") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func row(name: String, icon: String, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 30)
            Text(name)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 写真アプリへの保存

/// 書き出し済みファイルをフォトライブラリへ追加する。
/// Info.plist の NSPhotoLibraryAddUsageDescription が必要(README参照)。
@MainActor
private final class PhotoSaver: ObservableObject {
    enum SaveState: Equatable {
        case idle, saving, saved
        case failed(String)
    }

    @Published private(set) var state: SaveState = .idle

    func save(url: URL) {
        guard state != .saving else { return }
        state = .saving
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { success, error in
            Task { @MainActor in
                if success {
                    self.state = .saved
                } else {
                    self.state = .failed(error?.localizedDescription ?? "ほぞんできませんでした。設定アプリで写真へのアクセスを許可してください")
                }
            }
        }
    }

    func reset() {
        state = .idle
    }
}

private struct SimpleShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - 共通の大ボタン

private struct BigButtonLabel: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3)
            }
            Text(title)
                .font(.headline.bold())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 60)
    }
}

private struct BigPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct BigSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.blue)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
