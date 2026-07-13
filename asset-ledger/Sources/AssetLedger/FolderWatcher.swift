import Foundation

/// DispatchSourceによるフォルダ監視。
/// フォルダ直下への書き込み・リネーム・削除イベントで onChange を呼ぶ。
/// サブフォルダ内の変更はイベントが飛ばないため、LibraryStore側の
/// 定期再スキャン（5秒間隔）が取りこぼしを回収する。
final class FolderWatcher {
    let url: URL
    private var source: DispatchSourceFileSystemObject?
    private let onChange: () -> Void

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        start()
    }

    private func start() {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("[AssetLedger] フォルダ監視を開始できません: \(url.path)")
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            self?.onChange()
        }
        src.setCancelHandler {
            close(fd)
        }
        src.resume()
        source = src
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
