import SwiftUI

// MARK: - お守りの作法ガイド

struct GuideView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(GuideData.entries) { entry in
                        GuideRow(entry: entry)
                    }
                } footer: {
                    Text("上記は一般的な目安です。神社・お寺によって考え方や受け付け方法が異なる場合があります。実際の返納・処分にあたっては、授与を受けた神社・お寺に確認することをおすすめします。")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("お守りの作法ガイド")
        }
    }
}

struct GuideRow: View {
    let entry: GuideEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(entry.title, systemImage: "sparkle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.omamoriGold)
            Text(entry.body)
                .font(.callout)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
    }
}
