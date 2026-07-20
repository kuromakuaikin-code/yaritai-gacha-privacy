import SwiftUI
import SwiftData

// MARK: - ポイ活残高 一覧

struct PointAccountListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PurchaseStore
    @Query private var accounts: [PointAccount]

    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var editing: PointAccount?
    @State private var updatingBalance: PointAccount?

    /// 期限が近い順（未設定は最後）→ サービス名の順で並べる
    private var sorted: [PointAccount] {
        accounts.sorted { a, b in
            switch (a.daysUntilExpiry, b.daysUntilExpiry) {
            case let (da?, db?): return da != db ? da < db : a.serviceName < b.serviceName
            case (nil, nil): return a.serviceName < b.serviceName
            case (nil, _): return false
            case (_, nil): return true
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if accounts.isEmpty {
                    ContentUnavailableView(
                        "登録がありません",
                        systemImage: "star.circle",
                        description: Text("右上の＋から、楽天ポイント・dポイントなどの残高を登録しましょう")
                    )
                } else {
                    List {
                        if !AppConfig.freeTrial, !store.isUnlimited, accounts.count > AppConfig.freeItemLimitPerModule {
                            Section {
                                Label("無料版は\(AppConfig.freeItemLimitPerModule)件まで表示中。プレミアムで全件表示できます", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(sorted) { account in
                            PointAccountRow(account: account, onUpdateBalance: { updatingBalance = account })
                                .contentShape(Rectangle())
                                .onTapGesture { editing = account }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("ポイ活残高管理")
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
                AddEditPointAccountView(account: nil)
            }
            .sheet(item: $editing) { account in
                AddEditPointAccountView(account: account)
            }
            .sheet(item: $updatingBalance) { account in
                UpdateBalanceView(account: account)
            }
            .alert("登録上限に達しました", isPresented: $showPaywall) {
                Button("設定でプレミアムを見る") {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("無料版はポイ活残高を\(AppConfig.freeItemLimitPerModule)件まで登録できます。設定タブからプレミアムで4つのモジュールすべて無制限に記録できます。")
            }
        }
    }

    private func addTapped() {
        if !AppConfig.freeTrial, !store.isUnlimited, accounts.count >= AppConfig.freeItemLimitPerModule {
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

struct PointAccountRow: View {
    let account: PointAccount
    var onUpdateBalance: () -> Void

    private var expiryText: String? {
        guard let days = account.daysUntilExpiry else { return nil }
        return daysLabel(days)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .foregroundStyle(Color.kurashiGold)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.serviceName.isEmpty ? "(名称未入力)" : account.serviceName)
                    .font(.subheadline.weight(.semibold))
                Text("更新日：\(mediumDate(account.lastUpdated))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let expiryText {
                    Text("有効期限：\(expiryText)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(deadlineColor(account.daysUntilExpiry ?? 999).opacity(0.15))
                        .foregroundStyle(account.isExpiringSoon ? deadlineColor(account.daysUntilExpiry ?? 999) : .secondary)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("\(account.currentBalance)pt")
                    .font(.subheadline.weight(.bold))
                Button("残高を更新", action: onUpdateBalance)
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .tint(Color.kurashiGold)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 残高の更新

struct UpdateBalanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var account: PointAccount
    @State private var balanceText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(account.serviceName) {
                    HStack {
                        Text("新しい残高")
                        Spacer()
                        TextField("0", text: $balanceText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("pt")
                    }
                } footer: {
                    Text("最新の残高で上書きします。更新日時は本日の日付になります。")
                }
            }
            .navigationTitle("残高を更新")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("更新") { save() }
                }
            }
            .onAppear {
                balanceText = String(account.currentBalance)
            }
        }
    }

    private func save() {
        account.currentBalance = Int(balanceText) ?? account.currentBalance
        account.lastUpdated = Date()
        dismiss()
    }
}

// MARK: - 追加・編集

struct AddEditPointAccountView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let account: PointAccount?

    @State private var serviceName = ""
    @State private var balanceText = ""
    @State private var hasExpiry = false
    @State private var expiryDate = Date()
    @State private var memo = ""

    private var isEditing: Bool { account != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("サービス") {
                    TextField("サービス名（例：楽天ポイント）", text: $serviceName)
                    HStack {
                        Text("現在の残高")
                        Spacer()
                        TextField("0", text: $balanceText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("pt")
                    }
                }

                Section("有効期限") {
                    Toggle("有効期限を設定する", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("期限日", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section("メモ") {
                    TextField("交換予定・付与条件など", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isEditing {
                    Section {
                        Button("この登録を削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "登録を編集" : "登録を追加")
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
        guard let account else { return }
        serviceName = account.serviceName
        balanceText = account.currentBalance > 0 ? String(account.currentBalance) : ""
        if let expiry = account.expiryDate {
            hasExpiry = true
            expiryDate = expiry
        }
        memo = account.memo
    }

    private func save() {
        let target = account ?? PointAccount()
        target.serviceName = serviceName
        target.currentBalance = Int(balanceText) ?? 0
        target.expiryDate = hasExpiry ? expiryDate : nil
        target.memo = memo
        if account == nil {
            target.lastUpdated = Date()
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let account {
            context.delete(account)
        }
        dismiss()
    }
}
