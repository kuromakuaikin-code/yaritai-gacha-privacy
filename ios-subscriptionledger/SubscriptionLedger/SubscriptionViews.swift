import SwiftUI
import SwiftData

// MARK: - 一覧

struct SubscriptionListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query private var subscriptions: [Subscription]

    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: Subscription?

    /// 契約中を先に、それぞれ次回更新日が近い順
    private var sorted: [Subscription] {
        subscriptions.sorted { a, b in
            if a.isActive != b.isActive { return a.isActive && !b.isActive }
            if a.isActive {
                return a.nextRenewalDate < b.nextRenewalDate
            }
            return a.serviceName < b.serviceName
        }
    }

    private var activeSubscriptions: [Subscription] { subscriptions.filter { $0.isActive } }

    private var totalMonthly: Double {
        activeSubscriptions.reduce(0) { $0 + $1.monthlyEquivalent }
    }

    var body: some View {
        NavigationStack {
            Group {
                if subscriptions.isEmpty {
                    ContentUnavailableView(
                        "サブスクがまだ登録されていません",
                        systemImage: "list.bullet.rectangle",
                        description: Text("右上の＋から、契約中のサブスクリプションを追加しましょう")
                    )
                } else {
                    List {
                        Section {
                            SummaryCard(totalMonthly: totalMonthly, activeCount: activeSubscriptions.count)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }

                        if !AppConfig.freeTrial, !store.isUnlimited, subscriptions.count > AppConfig.freeSubscriptionLimit {
                            Section {
                                Label("無料版は\(AppConfig.freeSubscriptionLimit)件まで表示中。プレミアムで全件表示できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section("登録中のサブスク") {
                            ForEach(sorted) { sub in
                                Button {
                                    editing = sub
                                } label: {
                                    SubscriptionRow(subscription: sub)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete(perform: delete)
                        }
                    }
                }
            }
            .navigationTitle("サブスク管理帳")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addTapped()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddEditSubscriptionView(subscription: nil)
            }
            .sheet(item: $editing) { sub in
                AddEditSubscriptionView(subscription: sub)
            }
            .alert("登録件数の上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版は\(AppConfig.freeSubscriptionLimit)件まで登録できます。設定タブからプレミアムで無制限に登録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, subscriptions.count >= AppConfig.freeSubscriptionLimit {
            showPaywall = true
        } else {
            showAdd = true
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sorted[index])
        }
    }
}

struct SummaryCard: View {
    let totalMonthly: Double
    let activeCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("月換算の合計")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(yen(totalMonthly))
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.brand)
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("契約中 \(activeCount)件")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.brand.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 4)
    }
}

struct SubscriptionRow: View {
    let subscription: Subscription

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: subscription.category.icon)
                .foregroundStyle(subscription.isActive ? subscription.category.color : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(subscription.serviceName.isEmpty ? subscription.category.label : subscription.serviceName)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(subscription.category.label)
                    Text("・").foregroundStyle(.tertiary)
                    Text(subscription.billingCycle.label)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !subscription.isActive {
                    Text("解約・休止中")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(yen(subscription.amount))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(subscription.isActive ? .primary : .secondary)
                if subscription.isActive {
                    Text("次回 \(mediumDate(subscription.nextRenewalDate))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(subscription.isActive ? 1.0 : 0.55)
    }
}

// MARK: - 追加・編集

struct AddEditSubscriptionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let subscription: Subscription?

    @State private var serviceName = ""
    @State private var category: SubscriptionCategory = .video
    @State private var billingCycle: BillingCycle = .monthly
    @State private var amountText = ""
    @State private var billingDay = 1
    @State private var billingMonth = Calendar.current.component(.month, from: Date())
    @State private var startDate = Date()
    @State private var isActive = true
    @State private var memo = ""

    private var isEditing: Bool { subscription != nil }
    private var amount: Int { Int(amountText) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("サービス") {
                    TextField("サービス名（例：〇〇動画配信）", text: $serviceName)
                    Picker("カテゴリー", selection: $category) {
                        ForEach(SubscriptionCategory.allCases) { c in
                            Label(c.label, systemImage: c.icon).tag(c)
                        }
                    }
                }

                Section("料金・支払い") {
                    Picker("支払いサイクル", selection: $billingCycle) {
                        ForEach(BillingCycle.allCases) { c in
                            Text(c.label).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("金額")
                        Spacer()
                        TextField("0", text: $amountText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("円")
                    }

                    if billingCycle == .yearly {
                        Picker("支払い月", selection: $billingMonth) {
                            ForEach(1...12, id: \.self) { m in
                                Text("\(m)月").tag(m)
                            }
                        }
                    }

                    Picker("支払い日", selection: $billingDay) {
                        ForEach(1...31, id: \.self) { d in
                            Text("\(d)日").tag(d)
                        }
                    }

                    DatePicker("契約開始日", selection: $startDate, displayedComponents: .date)
                }

                Section("状態") {
                    Toggle("契約中", isOn: $isActive)
                } footer: {
                    Text("解約・休止中にすると一覧の下部に表示され、集計にも含まれません。削除せずに履歴として残せます。")
                }

                Section("メモ") {
                    TextField("プラン内容・共有メンバーなど", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isEditing {
                    Section {
                        Button("このサブスクを削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "サブスクを編集" : "サブスクを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(serviceName.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let subscription else { return }
        serviceName = subscription.serviceName
        category = subscription.category
        billingCycle = subscription.billingCycle
        amountText = subscription.amount > 0 ? String(subscription.amount) : ""
        billingDay = subscription.billingDay
        billingMonth = subscription.billingMonth
        startDate = subscription.startDate
        isActive = subscription.isActive
        memo = subscription.memo
    }

    private func save() {
        let target = subscription ?? Subscription()
        target.serviceName = serviceName
        target.category = category
        target.billingCycle = billingCycle
        target.amount = amount
        target.billingDay = billingDay
        target.billingMonth = billingMonth
        target.startDate = startDate
        target.isActive = isActive
        target.memo = memo
        if subscription == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let subscription {
            context.delete(subscription)
        }
        dismiss()
    }
}
