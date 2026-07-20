import SwiftUI
import AVFoundation

// MARK: - 音楽選択画面
//
// 著作権の関係で、利用者のミュージックライブラリからの選曲はできない仕様とする。
// 開発者があらかじめ用意した著作権フリー（ロイヤリティフリー）のBGMファイルから選ぶだけにする。
// ⚠️ 実際の音源ファイル（bgm_happy1.m4a など）はこのリポジトリに含まれていない。
// README.md の「音源ファイルを追加してください」を参照し、開発者がリリース前に追加すること。
struct MusicPickerView: View {
    @EnvironmentObject private var project: VideoProject
    @State private var previewPlayer: AVAudioPlayer?
    @State private var playingID: String?
    @State private var previewUnavailable = false

    var body: some View {
        VStack(spacing: 20) {
            Text("おんがくを えらぼう")
                .font(.system(size: 22, weight: .heavy, design: .rounded))

            Toggle("おんがくを つける", isOn: $project.music.enabled)
                .padding(.horizontal)
                .tint(.pink)

            if project.music.enabled {
                VStack(spacing: 10) {
                    ForEach(BGMTrack.all) { track in
                        HStack {
                            Button {
                                project.music.trackID = track.id
                            } label: {
                                HStack {
                                    Image(systemName: project.music.trackID == track.id ? "largecircle.fill.circle" : "circle")
                                    Text(track.title)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                togglePreview(track)
                            } label: {
                                Image(systemName: playingID == track.id ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title2)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal)

                if previewUnavailable {
                    Text("この曲の音源ファイルがまだバンドルに追加されていません（開発者向けメッセージ）。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("おおきさ").font(.headline)
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: $project.music.volume, in: 0...1)
                            .tint(.pink)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            Button {
                previewPlayer?.stop()
                project.path.append(FlowStep.export)
            } label: {
                Text("どうがを つくる ▶️")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
        .navigationTitle("おんがく")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { previewPlayer?.stop() }
    }

    private func togglePreview(_ track: BGMTrack) {
        if playingID == track.id {
            previewPlayer?.stop()
            playingID = nil
            return
        }
        previewUnavailable = false
        let (name, ext) = splitFilename(track.id)
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            // 開発者がまだ音源ファイルを追加していない場合はここに来る
            previewUnavailable = true
            playingID = nil
            return
        }
        previewPlayer = player
        previewPlayer?.play()
        playingID = track.id
    }

    private func splitFilename(_ filename: String) -> (name: String, ext: String?) {
        guard let dotIndex = filename.lastIndex(of: ".") else { return (filename, nil) }
        let name = String(filename[filename.startIndex..<dotIndex])
        let ext = String(filename[filename.index(after: dotIndex)...])
        return (name, ext)
    }
}
