import UIKit

/// 触覚フィードバック。編集操作の「効いた感」と完了・失敗の通知に使う。
/// 押すだけで何も起きなかった(ガードで弾かれた)ときは鳴らさないこと —
/// 変化が無いのに手応えだけあると混乱のもとになる。
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
