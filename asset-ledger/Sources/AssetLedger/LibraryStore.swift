import Foundation
import AppKit
import Combine

/// 台帳の中核。フォルダ・素材の状態、永続化、スキャン、監視の統括を担う。
/// UI更新はメインスレッド、スキャン＆サムネ生成は直列バックグラウンドキューで行う。
final class LibraryStore: ObservableObject {

    @Published var folders: [WatchFolder] = []
    @Published var assets: [Asset] = []
    @Published var thumbnailSize: Int = 256 {
        didSet { if oldValue != thumbnailSize { saveSoon() } }
    }
    @Published var selectedAssetID: UUID?

    private var watchers: [UUID: FolderWatcher] = [:]
    private var rescanTimer: Timer?
    /// スキャン・サムネ生成用の直列キュー（同時実行しない）
    private let workQueue = DispatchQueue(label: "AssetLedger.work", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?
    private var rescanQueued = false

    /// メニューバーバッジ用: 未閲覧数
    var unviewedCount: Int {
        assets.filter { !$0.isViewed && !$0.isMissing }.count
    }

    /// 直近5件（メニューバーポップオーバー用）
    var recentAssets: [Asset] {
        Array(assets.sorted { $0.createdAt > $1.createdAt }.prefix(5))
    }

    /// 全タグ一覧（フィルタ用）
    var allTags: [String] {
        Array(Set(assets.flatMap(\.tags))).sorted()
    }

    init() {
        load()
        for folder in folders where folder.isActive {
            startWatching(folder)
        }
        // 起動時スキャン: アプリ停止中に増えたファイルはNEW扱い
        rescanAll(markNewAsViewed: false)
        // サブフォルダの変更やイベント取りこぼしを5秒間隔の再スキャンで回収
        rescanTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.rescanAll(markNewAsViewed: false)
        }
    }

    // MARK: - 永続化

    private func load() {
        guard let data = try? Data(contentsOf: LibraryPaths.libraryFile),
              let decoded = try? JSONDecoder().decode(LibraryData.self, from: data) else { return }
        folders = decoded.folders
        assets = decoded.assets
        thumbnailSize = decoded.thumbnailSize
        // セキュリティスコープ付きブックマークの解決（サンドボックス時のみ意味を持つ）
        for folder in folders {
            guard let bookmark = folder.bookmark else { continue }
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark,
                                  options: [.withSecurityScope],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &stale) {
                _ = url.startAccessingSecurityScopedResource()
            }
        }
    }

    /// 1秒デバウンスで保存（タグ入力等の連続更新でI/Oを叩きすぎない）
    func saveSoon() {
        saveWorkItem?.cancel()
        let data = LibraryData(folders: folders, assets: assets, thumbnailSize: thumbnailSize)
        let item = DispatchWorkItem {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(data).write(to: LibraryPaths.libraryFile, options: .atomic)
            } catch {
                NSLog("[AssetLedger] 保存失敗: \(error)")
            }
        }
        saveWorkItem = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1, execute: item)
    }

    // MARK: - フォルダ管理

    func addFolder(url: URL) {
        let path = url.path
        guard !folders.contains(where: { $0.path == path }) else { return }
        // サンドボックス時のためにブックマークを試みる（非サンドボックスでは失敗してもよい）
        let bookmark = try? url.bookmarkData(options: [.withSecurityScope],
                                             includingResourceValuesForKeys: nil,
                                             relativeTo: nil)
        let folder = WatchFolder(path: path, bookmark: bookmark, isActive: true)
        folders.append(folder)
        saveSoon()
        startWatching(folder)
        // 追加時点の既存ファイルは「閲覧済み」として取り込む（NEWは以後の新規検出のみ）
        scan(folder: folder, markNewAsViewed: true)
    }

    func removeFolder(_ folder: WatchFolder) {
        watchers[folder.id]?.stop()
        watchers[folder.id] = nil
        folders.removeAll { $0.id == folder.id }
        let removed = assets.filter { $0.folderID == folder.id }
        assets.removeAll { $0.folderID == folder.id }
        if let sel = selectedAssetID, removed.contains(where: { $0.id == sel }) {
            selectedAssetID = nil
        }
        saveSoon()
        // サムネも削除（アプリ管理領域の肥大防止）
        workQueue.async {
            for asset in removed {
                if let url = asset.thumbnailURL {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }

    func setFolderActive(_ folder: WatchFolder, _ active: Bool) {
        guard let i = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[i].isActive = active
        if active {
            startWatching(folders[i])
            scan(folder: folders[i], markNewAsViewed: false)
        } else {
            watchers[folder.id]?.stop()
            watchers[folder.id] = nil
        }
        saveSoon()
    }

    private func startWatching(_ folder: WatchFolder) {
        watchers[folder.id]?.stop()
        watchers[folder.id] = FolderWatcher(url: folder.url) { [weak self] in
            guard let self, let current = self.folders.first(where: { $0.id == folder.id }) else { return }
            self.scan(folder: current, markNewAsViewed: false)
        }
    }

    // MARK: - スキャン

    /// 全アクティブフォルダを再スキャン（多重投入はしない）
    func rescanAll(markNewAsViewed: Bool) {
        guard !rescanQueued else { return }
        rescanQueued = true
        let targets = folders.filter(\.isActive)
        workQueue.async { [weak self] in
            defer { DispatchQueue.main.async { self?.rescanQueued = false } }
            for folder in targets {
                self?.scanSync(folder: folder, markNewAsViewed: markNewAsViewed)
            }
        }
    }

    func scan(folder: WatchFolder, markNewAsViewed: Bool) {
        workQueue.async { [weak self] in
            self?.scanSync(folder: folder, markNewAsViewed: markNewAsViewed)
        }
    }

    /// workQueue上で実行。ファイル列挙→新規Asset登録→消失検出→サムネ生成
    private func scanSync(folder: WatchFolder, markNewAsViewed: Bool) {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .creationDateKey, .fileSizeKey]
        var foundPaths = Set<String>()
        var newAssets: [Asset] = []

        let knownPaths: Set<String> = DispatchQueue.main.sync {
            Set(assets.filter { $0.folderID == folder.id }.map(\.filePath))
        }

        if let enumerator = fm.enumerator(at: folder.url,
                                          includingPropertiesForKeys: keys,
                                          options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true,
                      AssetFileType.isSupported(url: fileURL) else { continue }
                let path = fileURL.path
                foundPaths.insert(path)
                guard !knownPaths.contains(path) else { continue }
                var asset = Asset(filePath: path,
                                  folderID: folder.id,
                                  fileType: .from(url: fileURL))
                asset.fileSize = Int64(values.fileSize ?? 0)
                asset.createdAt = values.creationDate ?? Date()
                asset.isViewed = markNewAsViewed
                newAssets.append(asset)
            }
        }

        // 登録と消失フラグ更新はメインスレッドで
        DispatchQueue.main.sync {
            if !newAssets.isEmpty {
                assets.append(contentsOf: newAssets)
            }
            var changed = !newAssets.isEmpty
            for i in assets.indices where assets[i].folderID == folder.id {
                let missing = !foundPaths.contains(assets[i].filePath)
                if assets[i].isMissing != missing {
                    assets[i].isMissing = missing
                    changed = true
                }
            }
            if changed { saveSoon() }
        }

        // サムネ生成（workQueue上でそのまま直列処理）
        let maxPixel = DispatchQueue.main.sync { thumbnailSize }
        for asset in newAssets {
            generateThumbnailSync(assetID: asset.id, url: asset.fileURL,
                                  type: asset.fileType, maxPixel: maxPixel)
        }
    }

    /// workQueue上で実行
    private func generateThumbnailSync(assetID: UUID, url: URL, type: AssetFileType, maxPixel: Int) {
        guard let result = ThumbnailGenerator.generate(for: url, type: type, maxPixel: maxPixel) else {
            DispatchQueue.main.async { [weak self] in
                self?.update(assetID) { $0.thumbnailFailed = true }
            }
            return
        }
        let fileName = "\(assetID.uuidString).jpg"
        let dest = LibraryPaths.thumbnailsDir.appendingPathComponent(fileName)
        do {
            try result.jpegData.write(to: dest, options: .atomic)
            DispatchQueue.main.async { [weak self] in
                self?.update(assetID) {
                    $0.thumbnailFileName = fileName
                    $0.thumbnailFailed = result.failed
                }
            }
        } catch {
            NSLog("[AssetLedger] サムネ保存失敗: \(error)")
        }
    }

    /// 設定変更後などに全サムネを再生成
    func regenerateAllThumbnails() {
        let snapshot = assets.filter { !$0.isMissing }
        let maxPixel = thumbnailSize
        workQueue.async { [weak self] in
            for asset in snapshot {
                self?.generateThumbnailSync(assetID: asset.id, url: asset.fileURL,
                                            type: asset.fileType, maxPixel: maxPixel)
            }
        }
    }

    // MARK: - 素材更新

    func update(_ id: UUID, _ mutate: (inout Asset) -> Void) {
        guard let i = assets.firstIndex(where: { $0.id == id }) else { return }
        mutate(&assets[i])
        saveSoon()
    }

    func markViewed(_ id: UUID) {
        guard let i = assets.firstIndex(where: { $0.id == id }), !assets[i].isViewed else { return }
        assets[i].isViewed = true
        saveSoon()
    }

    func toggleFavorite(_ id: UUID) {
        update(id) { $0.isFavorite.toggle() }
    }

    // MARK: - Finder連携

    func revealInFinder(_ asset: Asset) {
        NSWorkspace.shared.activateFileViewerSelecting([asset.fileURL])
    }

    func openWithDefaultApp(_ asset: Asset) {
        NSWorkspace.shared.open(asset.fileURL)
    }
}
