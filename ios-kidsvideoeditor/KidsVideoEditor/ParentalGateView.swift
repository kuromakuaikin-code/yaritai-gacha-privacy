import SwiftUI

/// 子どもだけでは通過できないよう、簡単な計算問題に答えさせる保護者ゲート。
/// プレミアム購入・外部リンク（プライバシーポリシー／利用規約）・共有シートの前に必ず表示する。
struct ParentalGateView: View {
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @State private var a = 2
    @State private var b = 2
    @State private var choices: [Int] = []
    @State private var wrongShake = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("🧑‍🤝‍🧑").font(.system(size: 44))

                Text("おうちの人と いっしょに みてね")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                Text("この けいさんの こたえは どれ？")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))

                Text("\(a) + \(b) = ?")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 16) {
                    ForEach(choices, id: \.self) { choice in
                        Button {
                            handleTap(choice)
                        } label: {
                            Text("\(choice)")
                                .font(.title.bold())
                                .frame(width: 72, height: 72)
                                .background(Color.white)
                                .foregroundStyle(.black)
                                .clipShape(Circle())
                        }
                    }
                }
                .offset(x: wrongShake ? -8 : 0)
                .animation(.default, value: wrongShake)

                Button("やめる") { onCancel() }
                    .foregroundStyle(.white)
                    .padding(.top, 8)
            }
            .padding(32)
        }
        .onAppear { reroll() }
    }

    private func handleTap(_ choice: Int) {
        if choice == a + b {
            onSuccess()
        } else {
            wrongShake = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                wrongShake = false
                reroll()
            }
        }
    }

    private func reroll() {
        a = Int.random(in: 2...9)
        b = Int.random(in: 2...9)
        let correct = a + b
        var wrongs = Set<Int>()
        while wrongs.count < 2 {
            let candidate = correct + Int.random(in: -6...6)
            if candidate != correct && candidate > 0 {
                wrongs.insert(candidate)
            }
        }
        choices = ([correct] + Array(wrongs)).shuffled()
    }
}

// MARK: - どこからでも使える保護者ゲート用の View 拡張

private struct ParentalGateModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onSuccess: () -> Void

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isPresented) {
            ParentalGateView(
                onSuccess: {
                    isPresented = false
                    onSuccess()
                },
                onCancel: {
                    isPresented = false
                }
            )
        }
    }
}

extension View {
    /// isPresented が true になったら保護者ゲートを全画面表示し、
    /// 正解した場合のみ onSuccess を実行する。
    func parentalGate(isPresented: Binding<Bool>, onSuccess: @escaping () -> Void) -> some View {
        modifier(ParentalGateModifier(isPresented: isPresented, onSuccess: onSuccess))
    }
}
