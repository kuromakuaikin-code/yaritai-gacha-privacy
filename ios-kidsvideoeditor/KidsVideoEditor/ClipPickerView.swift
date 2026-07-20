import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

// MARK: - PhotosPicker で受け取った動画を端末内にコピーするための Transferable

struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedMovie(url: destination)
        }
    }
}

// MARK: - サムネイル生成

enum VideoThumbnailer {
    static func generate(for url: URL) async -> (image: UIImage?, duration: Double) {
        let asset = AVURLAsset(url: url)
        let durationSeconds: Double
        if let loadedDuration = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(loadedDuration)
            durationSeconds = seconds.isFinite && seconds > 0 ? seconds : 0
        } else {
            durationSeconds = 0
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        let midpoint = min(0.5, durationSeconds / 2)
        let time = CMTime(seconds: midpoint, preferredTimescale: 600)

        var image: UIImage?
        if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
            image = UIImage(cgImage: cgImage)
        }
        return (image, durationSeconds)
    }
}

// MARK: - クリップ選択画面

struct ClipPickerView: View {
    @EnvironmentObject private var project: VideoProject
    @EnvironmentObject private var store: PurchaseStore

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoading = false
    @State private var limitMessage: String?

    private var canAddMoreClips: Bool {
        store.premium || project.clips.count < AppConfig.freeClipLimit
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("どうがを えらんでね")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .padding(.top, 8)

            if project.clips.isEmpty {
                Spacer()
                Text("🎞️").font(.system(size: 70))
                Text("したの ボタンから どうがを えらぼう")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(project.clips.enumerated()), id: \.element.id) { index, clip in
                            ClipCard(clip: clip, index: index, total: project.clips.count)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 210)

                Text("あわせて \(formattedTotal) びょう（さいだい 5ふん）")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                ProgressView("よみこみちゅう…")
            }

            if let limitMessage {
                Text(limitMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: store.premium ? nil : max(1, AppConfig.freeClipLimit - project.clips.count),
                matching: .videos,
                photoLibrary: .shared()
            ) {
                Text("📹 どうがを えらぶ")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(canAddMoreClips ? Color.pink : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .disabled(!canAddMoreClips)
            .padding(.horizontal)

            if !store.premium {
                Text("むりょう版は どうが \(AppConfig.freeClipLimit)本まで。プレミアムで むせいげんに！")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                project.path.append(FlowStep.caption)
            } label: {
                Text("つぎへ ▶️")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(project.clips.isEmpty ? Color.gray : Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .disabled(project.clips.isEmpty)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .navigationTitle("どうがを えらぶ")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await loadPicked(newItems) }
        }
    }

    private var formattedTotal: String {
        String(format: "%.0f", project.totalTrimmedDuration)
    }

    private func loadPicked(_ items: [PhotosPickerItem]) async {
        isLoading = true
        limitMessage = nil
        for item in items {
            guard canAddMoreClips else {
                limitMessage = "むりょう版は どうが \(AppConfig.freeClipLimit)本までです。"
                break
            }
            guard let movie = try? await item.loadTransferable(type: PickedMovie.self) else { continue }
            let (image, duration) = await VideoThumbnailer.generate(for: movie.url)
            guard duration > 0 else { continue }
            if project.totalTrimmedDuration + duration > AppConfig.maxTotalDurationSeconds {
                limitMessage = "あわせて 5ふんまでしか つくれません。"
                break
            }
            let clip = VideoClip(assetURL: movie.url, duration: duration, thumbnail: image)
            project.clips.append(clip)
        }
        pickerItems = []
        isLoading = false
    }
}

// MARK: - クリップカード（サムネイル・順番入れ替え・削除）

private struct ClipCard: View {
    let clip: VideoClip
    let index: Int
    let total: Int
    @EnvironmentObject private var project: VideoProject

    var body: some View {
        VStack(spacing: 6) {
            Button {
                project.path.append(FlowStep.trim(clip.id))
            } label: {
                ZStack {
                    if let thumbnail = clip.thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.pink.opacity(0.4), lineWidth: 2))
            }
            .buttonStyle(.plain)

            Text("\(index + 1)ばんめ")
                .font(.caption.bold())
            Text(String(format: "%.1fびょう", clip.trimmedDuration))
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    moveLeft()
                } label: {
                    Image(systemName: "arrow.left.circle.fill").font(.title2)
                }
                .disabled(index == 0)

                Button(role: .destructive) {
                    delete()
                } label: {
                    Image(systemName: "trash.circle.fill").font(.title2)
                }

                Button {
                    moveRight()
                } label: {
                    Image(systemName: "arrow.right.circle.fill").font(.title2)
                }
                .disabled(index == total - 1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.pink)
        }
        .frame(width: 140)
    }

    private func moveLeft() {
        guard index > 0, project.clips.indices.contains(index) else { return }
        project.clips.swapAt(index, index - 1)
    }

    private func moveRight() {
        guard index < project.clips.count - 1, project.clips.indices.contains(index) else { return }
        project.clips.swapAt(index, index + 1)
    }

    private func delete() {
        project.clips.removeAll { $0.id == clip.id }
    }
}
