import SwiftUI
import AVKit
import AVFoundation

struct TrimView: View {
    let clipID: UUID
    @EnvironmentObject private var project: VideoProject
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    private var index: Int? {
        project.clips.firstIndex(where: { $0.id == clipID })
    }

    var body: some View {
        Group {
            if let index {
                content(for: index)
            } else {
                Text("クリップが みつかりません")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("きりとる")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(for index: Int) -> some View {
        let clip = project.clips[index]
        let maxDuration = max(0.1, clip.duration)

        VStack(spacing: 20) {
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.1))
                    .frame(height: 260)
                    .padding(.horizontal)
                    .overlay(ProgressView())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("はじまり： \(formatted(project.clips[index].trimStart)) びょう")
                    .font(.headline)
                Slider(
                    value: Binding(
                        get: { project.clips[index].trimStart },
                        set: { newValue in
                            let upperBound = project.clips[index].trimEnd - 0.5
                            project.clips[index].trimStart = max(0, min(newValue, max(0, upperBound)))
                        }
                    ),
                    in: 0...maxDuration
                )
                .tint(.pink)

                Text("おわり： \(formatted(project.clips[index].trimEnd)) びょう")
                    .font(.headline)
                Slider(
                    value: Binding(
                        get: { project.clips[index].trimEnd },
                        set: { newValue in
                            let lowerBound = project.clips[index].trimStart + 0.5
                            project.clips[index].trimEnd = min(maxDuration, max(newValue, lowerBound))
                        }
                    ),
                    in: 0...maxDuration
                )
                .tint(.orange)
            }
            .padding(.horizontal)

            Text("つかう ながさ： \(formatted(project.clips[index].trimEnd - project.clips[index].trimStart)) びょう")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("これで OK！")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.pink)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .padding(.top, 12)
        .onAppear {
            player = AVPlayer(url: clip.assetURL)
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func formatted(_ seconds: Double) -> String {
        String(format: "%.1f", seconds)
    }
}
