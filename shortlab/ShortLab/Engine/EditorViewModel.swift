import SwiftUI
import PhotosUI
import AVFoundation

/// 編集画面の状態と操作。
/// 編集操作のたびにスナップショットを積む簡易 undo を実装(MVPは10段まで)。
@MainActor
final class EditorViewModel: ObservableObject {

    @Published var project = EditorProject() {
        didSet { rebuildTask() }
    }
    @Published var selectedClipID: UUID?
    @Published var isImporting = false
    @Published var errorMessage: String?

    let playerController = PlayerController()
    let exportManager = ExportManager()

    private var undoStack: [EditorProject] = []
    private let undoLimit = 10
    private var rebuildWorkItem: Task<Void, Never>?

    var selectedClip: VideoClip? {
        guard let selectedClipID else { return nil }
        return project.clips.first { $0.id == selectedClipID }
    }

    // MARK: - Undo

    private func pushUndo() {
        undoStack.append(project)
        if undoStack.count > undoLimit {
            undoStack.removeFirst()
        }
    }

    var canUndo: Bool { !undoStack.isEmpty }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        project = previous
        if let selectedClipID, !project.clips.contains(where: { $0.id == selectedClipID }) {
            self.selectedClipID = nil
        }
    }

    // MARK: - Import

    /// PhotosPicker の選択結果をアプリ管理ディレクトリへコピーして追加。
    /// tmp の transferable URL は寿命が不定のため必ずコピーする。
    func importClips(items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isImporting = true
        defer { isImporting = false }

        var imported: [VideoClip] = []
        for item in items {
            do {
                guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                    continue
                }
                let asset = AVURLAsset(url: movie.url)
                let duration = try await asset.load(.duration).seconds
                guard duration > 0.1 else { continue }
                imported.append(VideoClip(url: movie.url, assetDuration: duration))
            } catch {
                errorMessage = "読み込みに失敗しました: \(error.localizedDescription)"
            }
        }

        guard !imported.isEmpty else { return }
        pushUndo()
        project.clips.append(contentsOf: imported)
    }

    // MARK: - Edit operations

    func deleteClip(id: UUID) {
        guard let index = project.clips.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        let removed = project.clips.remove(at: index)
        // 分割由来のクリップは同一ファイルを共有するため、最後の参照のときだけ消す
        if !project.clips.contains(where: { $0.url == removed.url }) {
            try? FileManager.default.removeItem(at: removed.url)
        }
        if selectedClipID == id { selectedClipID = nil }
    }

    func moveClip(id: UUID, direction: Int) {
        guard let index = project.clips.firstIndex(where: { $0.id == id }) else { return }
        let target = index + direction
        guard project.clips.indices.contains(target) else { return }
        pushUndo()
        project.clips.swapAt(index, target)
    }

    func setTrim(id: UUID, start: Double, end: Double) {
        guard let index = project.clips.firstIndex(where: { $0.id == id }) else { return }
        var clip = project.clips[index]
        let clampedStart = max(0, min(start, clip.assetDuration - 0.1))
        let clampedEnd = max(clampedStart + 0.1, min(end, clip.assetDuration))
        guard clampedStart != clip.trimStart || clampedEnd != clip.trimEnd else { return }
        pushUndo()
        clip.trimStart = clampedStart
        clip.trimEnd = clampedEnd
        project.clips[index] = clip
    }

    func setSpeed(id: UUID, speed: Double) {
        guard let index = project.clips.firstIndex(where: { $0.id == id }) else { return }
        guard project.clips[index].speed != speed else { return }
        pushUndo()
        project.clips[index].speed = speed
    }

    /// タイムライン秒 → (クリップindex, そのクリップの素材内秒) 変換
    private func locate(timelineSeconds: Double) -> (index: Int, assetSeconds: Double)? {
        var start: Double = 0
        for (index, clip) in project.clips.enumerated() {
            let end = start + clip.timelineDuration
            if timelineSeconds < end {
                let offsetInClip = (timelineSeconds - start) * clip.speed
                return (index, clip.trimStart + offsetInClip)
            }
            start = end
        }
        return nil
    }

    /// かんたんモード「この場面より前を切る」。
    /// 指定位置より前のクリップを外し、位置を含むクリップの trimStart を詰める。
    /// 外したクリップのファイルは消さない(分割で同一URLを共有するクリップがあり得るため)。
    func cutBefore(timelineSeconds: Double) {
        guard let (index, assetSeconds) = locate(timelineSeconds: timelineSeconds) else { return }
        var clip = project.clips[index]
        // 切った後に0.2秒以上残ること・実際に何かが切れることを保証
        guard assetSeconds < clip.trimEnd - 0.2 else { return }
        guard index > 0 || assetSeconds > clip.trimStart + 0.05 else { return }
        pushUndo()
        clip.trimStart = max(clip.trimStart, assetSeconds)
        var remaining = Array(project.clips[index...])
        remaining[0] = clip
        project.clips = remaining
        if let selectedClipID, !project.clips.contains(where: { $0.id == selectedClipID }) {
            self.selectedClipID = nil
        }
        // ユーザーが選んだ場面が新しい先頭になる
        playerController.seek(to: 0)
    }

    /// かんたんモード「この場面より後ろを切る」
    func cutAfter(timelineSeconds: Double) {
        guard let (index, assetSeconds) = locate(timelineSeconds: timelineSeconds) else { return }
        var clip = project.clips[index]
        guard assetSeconds > clip.trimStart + 0.2 else { return }
        guard index < project.clips.count - 1 || assetSeconds < clip.trimEnd - 0.05 else { return }
        pushUndo()
        clip.trimEnd = min(clip.trimEnd, assetSeconds)
        var remaining = Array(project.clips[...index])
        remaining[remaining.count - 1] = clip
        project.clips = remaining
        if let selectedClipID, !project.clips.contains(where: { $0.id == selectedClipID }) {
            self.selectedClipID = nil
        }
    }

    /// 現在の再生位置で選択クリップを2つに分割
    func splitSelectedClipAtPlayhead() {
        guard let clip = selectedClip else { return }

        // 再生ヘッド位置(タイムライン秒)を、選択クリップ内の素材秒へ変換
        var clipStartOnTimeline: Double = 0
        for c in project.clips {
            if c.id == clip.id { break }
            clipStartOnTimeline += c.timelineDuration
        }
        let playhead = playerController.currentTime
        let offsetInClip = (playhead - clipStartOnTimeline) * clip.speed
        let splitPoint = clip.trimStart + offsetInClip

        // 端0.2秒未満での分割は無効(ゼロ長クリップ防止)
        guard splitPoint > clip.trimStart + 0.2,
              splitPoint < clip.trimEnd - 0.2,
              let index = project.clips.firstIndex(where: { $0.id == clip.id })
        else { return }

        pushUndo()
        var first = clip
        first.trimEnd = splitPoint
        var second = VideoClip(url: clip.url, assetDuration: clip.assetDuration)
        second.trimStart = splitPoint
        second.trimEnd = clip.trimEnd
        second.speed = clip.speed
        project.clips[index] = first
        project.clips.insert(second, at: index + 1)
    }

    func addTextOverlay(text: String, fontSize: CGFloat,
                        position: CGPoint = CGPoint(x: 0.5, y: 0.4)) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        pushUndo()
        project.textOverlays.append(
            TextOverlayItem(text: text, relativePosition: position, fontSize: fontSize)
        )
    }

    func updateOverlayPosition(id: UUID, relativePosition: CGPoint) {
        guard let index = project.textOverlays.firstIndex(where: { $0.id == id }) else { return }
        // ドラッグ中の高頻度更新は undo に積まない
        project.textOverlays[index].relativePosition = CGPoint(
            x: min(max(relativePosition.x, 0.05), 0.95),
            y: min(max(relativePosition.y, 0.05), 0.95)
        )
    }

    func removeOverlay(id: UUID) {
        pushUndo()
        project.textOverlays.removeAll { $0.id == id }
    }

    func setMusic(_ track: MusicTrack?) {
        pushUndo()
        project.music = track
    }

    // MARK: - Preview rebuild

    /// project 変更のたびにプレビュー用コンポジションを再構築。
    /// 連続編集(スライダー操作等)で再構築が殺到しないよう 150ms デバウンス。
    private func rebuildTask() {
        rebuildWorkItem?.cancel()
        rebuildWorkItem = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.rebuildPreview()
        }
    }

    private func rebuildPreview() async {
        guard !project.clips.isEmpty else {
            playerController.unload()
            return
        }
        do {
            let result = try await CompositionEngine.build(project: project)
            let wasPlaying = playerController.isPlaying
            let position = playerController.currentTime
            playerController.load(result: result)
            playerController.seek(to: min(position, project.totalDuration))
            if wasPlaying { playerController.togglePlay() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// PhotosPicker からの動画受け取り。
/// received URL は一時領域のため、アプリの Documents 配下へ即コピーして寿命を確保する。
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let dir = URL.documentsDirectory.appendingPathComponent("clips", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent("\(UUID().uuidString).\(received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedMovie(url: dest)
        }
    }
}
