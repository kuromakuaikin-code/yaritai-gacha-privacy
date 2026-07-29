import SwiftUI
import AVKit

// MARK: - テキスト追加

struct TextSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var fontSize: CGFloat = 72

    var body: some View {
        NavigationStack {
            Form {
                Section("テキスト") {
                    TextField("夏の思い出", text: $text)
                }
                Section("文字サイズ") {
                    Slider(value: $fontSize, in: 40...140, step: 4) {
                        Text("サイズ")
                    }
                    Text(text.isEmpty ? "プレビュー" : text)
                        .font(.system(size: fontSize * 0.35, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
                Section {
                    Text("追加後はプレビュー上をドラッグで移動、長押しで削除できます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("テキストを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        viewModel.addTextOverlay(text: text, fontSize: fontSize)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 速度変更

struct SpeedSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    private let options: [(Double, String)] = [
        (0.5, "0.5x(スロー)"),
        (1.0, "1.0x(通常)"),
        (1.5, "1.5x(少し速い)"),
        (2.0, "2.0x(早送り)")
    ]

    var body: some View {
        NavigationStack {
            List(options, id: \.0) { speed, label in
                Button {
                    if let clip = viewModel.selectedClip {
                        viewModel.setSpeed(id: clip.id, speed: speed)
                    }
                    dismiss()
                } label: {
                    HStack {
                        Text(label).foregroundStyle(.primary)
                        Spacer()
                        if viewModel.selectedClip?.speed == speed {
                            Image(systemName: "checkmark").foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("再生速度")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - トリム

struct TrimSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var start: Double = 0
    @State private var end: Double = 1

    var body: some View {
        NavigationStack {
            Form {
                if let clip = viewModel.selectedClip {
                    Section("開始位置: \(start, specifier: "%.1f")秒") {
                        Slider(value: $start, in: 0...max(clip.assetDuration - 0.2, 0.1))
                    }
                    Section("終了位置: \(end, specifier: "%.1f")秒") {
                        Slider(value: $end, in: 0.2...clip.assetDuration)
                    }
                    Section {
                        Text("切り出し後の長さ: \(max(0, end - start), specifier: "%.1f")秒")
                            .font(.subheadline.monospacedDigit())
                    }
                } else {
                    Text("クリップが選択されていません")
                }
            }
            .navigationTitle("トリム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("適用") {
                        if let clip = viewModel.selectedClip {
                            viewModel.setTrim(id: clip.id, start: start, end: end)
                        }
                        dismiss()
                    }
                    .disabled(end - start < 0.2)
                }
            }
            .onAppear {
                if let clip = viewModel.selectedClip {
                    start = clip.trimStart
                    end = clip.trimEnd
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 音楽選択

/// バンドル内のフリーBGM。Resources/BGM/ に mp3 を置いてここに登録する。
/// しっかり編集(MusicSheet)とかんたんモード(SimpleMusicSheet)で共有。
/// TODO: フリー素材(魔王魂・DOVA-SYNDROME等、商用可・クレジット条件確認)を追加
enum BGMLibrary {
    static func tracks() -> [MusicTrack] {
        ["summer_bgm", "lofi_chill", "upbeat_pop", "acoustic_morning"].compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return nil }
            let display: [String: String] = [
                "summer_bgm": "夏のBGM",
                "lofi_chill": "Lo-fi チル",
                "upbeat_pop": "アップビート",
                "acoustic_morning": "アコースティック"
            ]
            return MusicTrack(name: display[name] ?? name, url: url)
        }
    }
}

struct MusicSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    private var bundledTracks: [MusicTrack] { BGMLibrary.tracks() }

    var body: some View {
        NavigationStack {
            List {
                if bundledTracks.isEmpty {
                    Section {
                        Text("BGMファイルが未追加です。Resources/BGM/ に mp3 を配置してください(README参照)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(bundledTracks) { track in
                    Button {
                        viewModel.setMusic(track)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "music.note")
                                .foregroundStyle(.green)
                            Text(track.name).foregroundStyle(.primary)
                            Spacer()
                            if viewModel.project.music?.name == track.name {
                                Image(systemName: "checkmark").foregroundStyle(.green)
                            }
                        }
                    }
                }
                if viewModel.project.music != nil {
                    Button(role: .destructive) {
                        viewModel.setMusic(nil)
                        dismiss()
                    } label: {
                        Label("BGMを外す", systemImage: "xmark.circle")
                    }
                }
            }
            .navigationTitle("音楽")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 書き出し

struct ExportSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    /// ExportManager の @Published は viewModel 経由では再描画されないため直接 observe する
    @ObservedObject var exporter: ExportManager
    @Environment(\.dismiss) private var dismiss

    /// TODO: StoreKit 導入後は課金状態と連動させる
    @State private var isPremium = false
    @State private var shareURL: URL?

    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
        self.exporter = viewModel.exportManager
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
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
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("書き出し")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        if case .exporting = exporter.state {
                            exporter.cancel()
                        }
                        exporter.reset()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isExporting)
        .sheet(item: Binding(
            get: { shareURL.map { ShareItem(url: $0) } },
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
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("1080p・\(Int(viewModel.project.totalDuration.rounded()))秒")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !isPremium {
                Label("無料版は透かしが入ります", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task {
                    await exporter.export(
                        project: viewModel.project,
                        showWatermark: !isPremium
                    )
                }
            } label: {
                Text("書き出す")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.black)
            }
        }
    }

    private func exportingContent(progress: Float) -> some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
                .tint(.green)
            Text("\(Int(progress * 100))%")
                .font(.title2.monospacedDigit().bold())
            Button("キャンセル", role: .destructive) {
                exporter.cancel()
            }
        }
    }

    private func finishedContent(url: URL) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("完了!")
                .font(.headline)
            Button {
                shareURL = url
            } label: {
                Label("保存・共有", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.black)
            }
        }
    }

    private func failedContent(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Button("やり直す") {
                exporter.reset()
            }
        }
    }
}

private struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
