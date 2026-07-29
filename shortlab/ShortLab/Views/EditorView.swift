import SwiftUI
import PhotosUI

struct EditorView: View {
    @ObservedObject var viewModel: EditorViewModel
    /// かんたんモードへ戻る(RootView から注入。nil なら戻るボタン非表示)
    var onClose: (() -> Void)?

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var activeSheet: EditorSheet?

    enum EditorSheet: Identifiable {
        case text, speed, music, trim, export
        var id: Self { self }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            PreviewView(viewModel: viewModel)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            PlaybackBar(
                player: viewModel.playerController,
                totalDuration: viewModel.project.totalDuration,
                disabled: viewModel.project.clips.isEmpty
            )
            TimelineView(viewModel: viewModel, pickerItems: $pickerItems)
                .padding(.top, 12)
            ToolsGridView(
                viewModel: viewModel,
                onOpenSheet: { activeSheet = $0 }
            )
            .padding(.top, 16)
            Spacer(minLength: 0)
            statusBar
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.06))
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await viewModel.importClips(items: items)
                pickerItems = []
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .text: TextSheet(viewModel: viewModel)
            case .speed: SpeedSheet(viewModel: viewModel)
            case .music: MusicSheet(viewModel: viewModel)
            case .trim: TrimSheet(viewModel: viewModel)
            case .export: ExportSheet(viewModel: viewModel)
            }
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
            if let onClose {
                Button {
                    viewModel.playerController.pause()
                    onClose()
                } label: {
                    Label("かんたん", systemImage: "chevron.left")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
                .padding(.trailing, 4)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("ShortLab")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Text("かんたん動画編集")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
            Spacer()
            Button {
                viewModel.playerController.pause()
                activeSheet = .export
            } label: {
                Label("書き出し", systemImage: "square.and.arrow.up")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green, in: Capsule())
                    .foregroundStyle(.black)
            }
            .disabled(viewModel.project.clips.isEmpty)
            .opacity(viewModel.project.clips.isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.09, green: 0.09, blue: 0.09))
    }

    private var statusBar: some View {
        HStack {
            Text("クリップ: \(viewModel.project.clips.count)")
            Spacer()
            Text("合計: \(timeString(viewModel.project.totalDuration))")
        }
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.09, green: 0.09, blue: 0.09))
    }

}

/// 再生バー。PlayerController の @Published は viewModel 経由の参照では
/// 再描画が走らないため、専用ビューで直接 observe する。
private struct PlaybackBar: View {
    @ObservedObject var player: PlayerController
    let totalDuration: Double
    let disabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                player.togglePlay()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
            .disabled(disabled)

            Text(timeString(player.currentTime))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.duration, 0.01)
            )
            .tint(.green)
            .disabled(disabled)

            Text(timeString(totalDuration))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}

func timeString(_ seconds: Double) -> String {
    let total = Int(seconds.rounded())
    return String(format: "%02d:%02d", total / 60, total % 60)
}

#Preview {
    EditorView(viewModel: EditorViewModel())
        .preferredColorScheme(.dark)
}
