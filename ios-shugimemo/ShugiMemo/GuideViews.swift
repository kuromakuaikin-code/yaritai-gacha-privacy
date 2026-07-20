import SwiftUI

// MARK: - 相場ガイド

struct GuideView: View {
    @State private var selectedKind: EventKind = .wedding

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("行事", selection: $selectedKind) {
                    ForEach(EventKind.allCases) { k in
                        Text(k.label).tag(k)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)

                List {
                    Section {
                        ForEach(MarketRateData.rates(for: selectedKind)) { rate in
                            RateRow(rate: rate)
                        }
                    } footer: {
                        Text("金額はあくまで一般的な目安です。地域の慣習・年齢・付き合いの深さによって変わります。迷ったときは家族や地域の年長者に確認するのが確実です。")
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("相場ガイド")
        }
    }
}

struct RateRow: View {
    let rate: MarketRate

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: rate.eventKind.icon)
                .foregroundStyle(rate.eventKind.color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(rate.relation.label)
                    .font(.subheadline.weight(.semibold))
                if !rate.note.isEmpty {
                    Text(rate.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(rate.rangeLabel)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.indigo)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }
}
