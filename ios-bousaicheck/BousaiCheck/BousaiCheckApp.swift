import SwiftUI
import SwiftData

// MARK: - ブランドカラー（防災アンバー）

extension Color {
    static let bousaiAmber = Color(red: 0xC9 / 255.0, green: 0x96 / 255.0, blue: 0x0C / 255.0)
}

@main
struct BousaiCheckApp: App {
    @StateObject private var store = PurchaseStore()
    @AppStorage("passcodeHash") private var passcodeHash = ""
    @State private var locked = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .overlay {
                    if locked {
                        LockView(isLocked: $locked)
                    }
                }
                .onAppear {
                    if !passcodeHash.isEmpty { locked = true }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background, !passcodeHash.isEmpty {
                        locked = true
                    }
                }
        }
        .modelContainer(for: [ChecklistItem.self, EmergencyContact.self])
    }
}

struct RootTabView: View {
    @EnvironmentObject private var store: PurchaseStore
    @Environment(\.modelContext) private var context
    @Query private var checklistItems: [ChecklistItem]

    var body: some View {
        TabView {
            ChecklistView()
                .tabItem { Label("チェックリスト", systemImage: "checklist") }
            ContactListView()
                .tabItem { Label("連絡先カード", systemImage: "person.crop.rectangle.stack.fill") }
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
        }
        .tint(Color.bousaiAmber)
        .safeAreaInset(edge: .bottom) {
            if AppConfig.adsEnabled && !store.isAdFree {
                AdBannerView()
            }
        }
        .onAppear(perform: seedPresetItemsIfNeeded)
    }

    /// 初回起動時のみ、標準の防災グッズチェックリストを投入する（冪等：既に1件でもあれば何もしない）
    private func seedPresetItemsIfNeeded() {
        guard checklistItems.isEmpty else { return }
        for preset in PresetChecklistData.items {
            let item = ChecklistItem()
            item.name = preset.name
            item.category = preset.category
            item.isChecked = false
            item.isPreset = true
            item.order = preset.order
            context.insert(item)
        }
    }
}

// MARK: - パスコードロック

struct LockView: View {
    @Binding var isLocked: Bool
    @AppStorage("passcodeHash") private var passcodeHash = ""
    @State private var input = ""
    @State private var shake = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("🔒").font(.system(size: 44))
                Text("パスコードを入力").font(.headline)
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .strokeBorder(Color.bousaiAmber, lineWidth: 2)
                            .background(Circle().fill(i < input.count ? Color.bousaiAmber : Color.clear))
                            .frame(width: 16, height: 16)
                    }
                }
                .offset(x: shake ? -10 : 0)
                .animation(shake ? .default.repeatCount(3, autoreverses: true).speed(6) : .default, value: shake)

                keypad
            }
        }
    }

    private var keypad: some View {
        let keys = ["1","2","3","4","5","6","7","8","9","","0","⌫"]
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(76)), count: 3), spacing: 14) {
            ForEach(keys, id: \.self) { key in
                if key.isEmpty {
                    Color.clear.frame(height: 64)
                } else {
                    Button {
                        tap(key)
                    } label: {
                        Text(key)
                            .font(.title2.weight(.semibold))
                            .frame(width: 68, height: 64)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func tap(_ key: String) {
        if key == "⌫" {
            if !input.isEmpty { input.removeLast() }
            return
        }
        guard input.count < 4 else { return }
        input += key
        if input.count == 4 {
            if Passcode.hash(input) == passcodeHash {
                isLocked = false
            } else {
                input = ""
                shake = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shake = false }
            }
        }
    }
}

// MARK: - 広告枠（AdMob組み込みポイント）

struct AdBannerView: View {
    // 本実装時は Google-Mobile-Ads-SDK を追加し、
    // ここを GADBannerView の UIViewRepresentable に置き換える。
    // ATT（AppTrackingTransparency）対応または非パーソナライズ配信を選択すること。
    var body: some View {
        HStack(spacing: 8) {
            Text("広告")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.4)))
            Text("ここに広告が表示されます（サンプル枠）")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(.bar)
    }
}
