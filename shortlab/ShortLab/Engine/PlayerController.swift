import AVFoundation
import Combine

/// プレビュー再生の管理。
/// seek はコアレス(間引き)方式: スクラブ中に seek を連打すると
/// AVPlayer 内部キューが詰まりカクつく・完了ハンドラが乱れるため、
/// 「実行中の seek が終わるまで最新値だけ保持」する Apple 推奨パターンで実装。
@MainActor
final class PlayerController: ObservableObject {
    let player = AVPlayer()

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    // seek coalescing
    private var isSeekInProgress = false
    private var chaseTime: CMTime = .zero

    deinit {
        // deinit は nonisolated のため player への直接アクセスは避け、
        // observer 解除のみ MainActor 外で安全な形で行う
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func load(result: CompositionResult) {
        removeObservers()

        let item = AVPlayerItem(asset: result.composition)
        item.videoComposition = result.videoComposition
        player.replaceCurrentItem(with: item)

        duration = result.composition.duration.seconds
        currentTime = 0

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 10),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.currentTime = time.seconds
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isPlaying = false
                self?.seek(to: 0)
            }
        }
    }

    func unload() {
        removeObservers()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    func togglePlay() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if duration > 0, currentTime >= duration - 0.05 {
                seek(to: 0)
            }
            player.play()
            isPlaying = true
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    /// スクラブ対応のスムーズ seek(連打しても最新値のみ反映)
    func seek(to seconds: Double) {
        chaseTime = RenderSpec.time(min(max(0, seconds), duration))
        if !isSeekInProgress {
            performSeek()
        }
    }

    private func performSeek() {
        isSeekInProgress = true
        let target = chaseTime
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if CMTimeCompare(target, self.chaseTime) == 0 {
                    self.isSeekInProgress = false
                    self.currentTime = target.seconds
                } else {
                    self.performSeek() // スクラブ中に更新された最新値へ追随
                }
            }
        }
    }

    private func removeObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }
}
