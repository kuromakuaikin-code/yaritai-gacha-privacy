import SwiftUI
import PhotosUI

struct TimelineView: View {
    @ObservedObject var viewModel: EditorViewModel
    @Binding var pickerItems: [PhotosPickerItem]

    private let clipColors: [Color] = [.green, .blue, .purple, .orange, .pink, .teal]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("タイムライン")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.isImporting {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(viewModel.project.clips.enumerated()), id: \.element.id) { index, clip in
                        clipCell(clip: clip, color: clipColors[index % clipColors.count])
                    }

                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 10,
                        matching: .videos
                    ) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.title3.bold())
                            Text("追加")
                                .font(.caption2)
                        }
                        .foregroundStyle(.green)
                        .frame(width: 64, height: 64)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.green.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 76)
        }
    }

    private func clipCell(clip: VideoClip, color: Color) -> some View {
        let isSelected = viewModel.selectedClipID == clip.id
        // 1秒 = 10pt、最小 56pt で視認性確保
        let width = max(56, clip.timelineDuration * 10)

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "film.fill")
                    .font(.caption2)
                if clip.speed != 1.0 {
                    Text("\(clip.speed, specifier: "%.1f")x")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .background(color.opacity(0.4), in: Capsule())
                }
            }
            Text("\(clip.timelineDuration, specifier: "%.1f")秒")
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .frame(width: width, height: 64, alignment: .leading)
        .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.green : color.opacity(0.6),
                              lineWidth: isSelected ? 2 : 1)
        )
        .foregroundStyle(.white)
        .onTapGesture {
            viewModel.selectedClipID = isSelected ? nil : clip.id
        }
        .contextMenu {
            Button {
                viewModel.moveClip(id: clip.id, direction: -1)
            } label: {
                Label("左へ移動", systemImage: "arrow.left")
            }
            Button {
                viewModel.moveClip(id: clip.id, direction: 1)
            } label: {
                Label("右へ移動", systemImage: "arrow.right")
            }
            Button(role: .destructive) {
                viewModel.deleteClip(id: clip.id)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }
}
