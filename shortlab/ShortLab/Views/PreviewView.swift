import SwiftUI
import AVKit

/// 9:16 プレビュー。テキストオーバーレイは正規化座標で配置し、
/// 書き出し時の CATextLayer と同じ値を共有する。
struct PreviewView: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if viewModel.project.clips.isEmpty {
                    emptyState
                } else {
                    VideoPlayerLayerView(player: viewModel.playerController.player)
                }

                ForEach(viewModel.project.textOverlays) { overlay in
                    DraggableTextOverlay(
                        overlay: overlay,
                        containerSize: geo.size,
                        onMove: { newPos in
                            viewModel.updateOverlayPosition(id: overlay.id, relativePosition: newPos)
                        },
                        onDelete: {
                            viewModel.removeOverlay(id: overlay.id)
                        }
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .frame(maxHeight: 420)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.12))
        )
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "film")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("下の「+」から動画を追加")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// AVPlayerLayer を直接ホストする(VideoPlayer はコントロール類が邪魔なため)
struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    final class PlayerLayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

struct DraggableTextOverlay: View {
    let overlay: TextOverlayItem
    let containerSize: CGSize
    let onMove: (CGPoint) -> Void
    let onDelete: () -> Void

    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        // 1080 基準のフォントサイズをプレビュー幅に比例縮小
        let previewFontSize = overlay.fontSize * containerSize.width / RenderSpec.renderSize.width

        Text(overlay.text)
            .font(.system(size: previewFontSize, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
            .position(
                x: overlay.relativePosition.x * containerSize.width + dragOffset.width,
                y: overlay.relativePosition.y * containerSize.height + dragOffset.height
            )
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        let newX = overlay.relativePosition.x + value.translation.width / containerSize.width
                        let newY = overlay.relativePosition.y + value.translation.height / containerSize.height
                        onMove(CGPoint(x: newX, y: newY))
                    }
            )
            .onLongPressGesture {
                onDelete()
            }
    }
}
