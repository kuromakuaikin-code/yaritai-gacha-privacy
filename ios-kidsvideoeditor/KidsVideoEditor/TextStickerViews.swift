import SwiftUI

// MARK: - テキストキャプション編集画面

struct CaptionEditorView: View {
    @EnvironmentObject private var project: VideoProject
    @EnvironmentObject private var store: PurchaseStore

    private let maxLength = 30

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("もじを いれよう")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))

                TextField("ここに もじを かいてね（なくてもOK）", text: $project.caption.text)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .padding(.horizontal)
                    .onChange(of: project.caption.text) { _, newValue in
                        if newValue.count > maxLength {
                            project.caption.text = String(newValue.prefix(maxLength))
                        }
                    }

                Text("\(project.caption.text.count)/\(maxLength)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("いろと フォント")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(CaptionStyleData.all) { style in
                            let locked = !style.isFree && !store.premium
                            Button {
                                guard !locked else { return }
                                project.caption.styleID = style.id
                            } label: {
                                VStack(spacing: 4) {
                                    Text("あいう")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(style.color)
                                    Text(style.name).font(.caption2)
                                    if locked {
                                        Image(systemName: "lock.fill").font(.caption2)
                                    }
                                }
                                .frame(width: 76, height: 76)
                                .background(project.caption.styleID == style.id ? style.color.opacity(0.2) : Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(project.caption.styleID == style.id ? style.color : .clear, lineWidth: 3)
                                )
                                .opacity(locked ? 0.5 : 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                if !store.premium {
                    Text("むりょう版は \(AppConfig.freeStyleCount)しゅるいまで。プレミアムで ぜんぶ つかえる！")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("いち（もじの ばしょ）")
                    .font(.headline)

                Picker("いち", selection: $project.caption.position) {
                    ForEach(CaptionPosition.allCases) { pos in
                        Text(pos.label).tag(pos)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Button {
                    project.path.append(FlowStep.stickers)
                } label: {
                    Text("つぎへ ▶️")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .padding(.top, 8)
        }
        .navigationTitle("テキスト")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let currentStyle = CaptionStyleData.all.first(where: { $0.id == project.caption.styleID })
            if let currentStyle, !currentStyle.isFree, !store.premium {
                project.caption.styleID = CaptionStyleData.all.first(where: { $0.isFree })?.id ?? 0
            }
        }
    }
}

// MARK: - ステッカー（絵文字）選択画面

struct StickerPickerView: View {
    @EnvironmentObject private var project: VideoProject
    @EnvironmentObject private var store: PurchaseStore

    @State private var selectedEmoji: String?
    @State private var showPositionPicker = false

    private var availableEmoji: [String] {
        store.premium ? StickerData.allEmoji : StickerData.freeEmoji
    }

    private var canAddMore: Bool {
        store.premium || project.stickers.count < AppConfig.freeMaxPlacedStickers
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("シールを つけよう")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(StickerData.allEmoji, id: \.self) { emoji in
                        let locked = !availableEmoji.contains(emoji)
                        Button {
                            guard !locked, canAddMore else { return }
                            selectedEmoji = emoji
                            showPositionPicker = true
                        } label: {
                            Text(emoji)
                                .font(.system(size: 34))
                                .frame(width: 56, height: 56)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .opacity(locked ? 0.35 : 1)
                                .overlay {
                                    if locked {
                                        Image(systemName: "lock.fill").font(.caption)
                                    }
                                }
                        }
                        .disabled(locked || !canAddMore)
                    }
                }
                .padding(.horizontal)

                if !store.premium {
                    Text("むりょう版は \(StickerData.freeEmoji.count)しゅるい・さいだい \(AppConfig.freeMaxPlacedStickers)こまで。プレミアムで ぜんぶ つかえる！")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if !project.stickers.isEmpty {
                    Text("つけた シール")
                        .font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(project.stickers) { sticker in
                                VStack(spacing: 4) {
                                    Text(sticker.emoji).font(.system(size: 28))
                                    Text(sticker.position.label).font(.caption2).foregroundStyle(.secondary)
                                    Button(role: .destructive) {
                                        project.stickers.removeAll { $0.id == sticker.id }
                                    } label: {
                                        Image(systemName: "trash.circle.fill")
                                    }
                                }
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Button {
                    project.path.append(FlowStep.music)
                } label: {
                    Text("つぎへ ▶️")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .padding(.top, 8)
        }
        .navigationTitle("シール")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("どこに つける？", isPresented: $showPositionPicker, titleVisibility: .visible) {
            ForEach(StickerPosition.allCases) { pos in
                Button(pos.label) {
                    if let emoji = selectedEmoji {
                        project.stickers.append(PlacedSticker(emoji: emoji, position: pos))
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }
}
