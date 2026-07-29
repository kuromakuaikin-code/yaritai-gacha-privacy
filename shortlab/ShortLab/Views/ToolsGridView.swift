import SwiftUI

struct ToolsGridView: View {
    @ObservedObject var viewModel: EditorViewModel
    let onOpenSheet: (EditorView.EditorSheet) -> Void

    private var hasSelection: Bool { viewModel.selectedClip != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ツール")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                toolButton("トリム", icon: "scissors", color: .orange, enabled: hasSelection) {
                    onOpenSheet(.trim)
                }
                toolButton("テキスト", icon: "textformat", color: .cyan, enabled: true) {
                    onOpenSheet(.text)
                }
                toolButton("速度", icon: "gauge.with.needle", color: .pink, enabled: hasSelection) {
                    onOpenSheet(.speed)
                }
                toolButton("音楽", icon: "music.note", color: .green, enabled: true) {
                    onOpenSheet(.music)
                }
                toolButton("分割", icon: "square.split.2x1", color: .yellow, enabled: hasSelection) {
                    viewModel.splitSelectedClipAtPlayhead()
                }
                toolButton("元に戻す", icon: "arrow.uturn.backward", color: .gray, enabled: viewModel.canUndo) {
                    viewModel.undo()
                }
            }
            .padding(.horizontal, 20)

            if !hasSelection && !viewModel.project.clips.isEmpty {
                Text("クリップをタップで選択するとトリム・速度・分割が使えます")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
        }
    }

    private func toolButton(
        _ title: String, icon: String, color: Color, enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(0.1))
            )
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}
