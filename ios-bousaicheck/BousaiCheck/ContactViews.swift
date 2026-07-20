import SwiftUI
import SwiftData

// MARK: - 家族の連絡先カード一覧

struct ContactListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \EmergencyContact.name) private var contacts: [EmergencyContact]

    @State private var showAdd = false
    @State private var editing: EmergencyContact?

    var body: some View {
        NavigationStack {
            Group {
                if contacts.isEmpty {
                    ContentUnavailableView(
                        "連絡先がありません",
                        systemImage: "person.crop.rectangle.stack",
                        description: Text("右上の＋から、家族の連絡先や避難時の集合場所を登録しましょう")
                    )
                } else {
                    List {
                        ForEach(contacts) { contact in
                            Button {
                                editing = contact
                            } label: {
                                ContactCard(contact: contact)
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("家族の連絡先カード")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddEditContactView(contact: nil)
            }
            .sheet(item: $editing) { contact in
                AddEditContactView(contact: contact)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(contacts[index])
        }
    }
}

struct ContactCard: View {
    let contact: EmergencyContact

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundStyle(Color.bousaiAmber)
                Text(contact.name.isEmpty ? "(名前未入力)" : contact.name)
                    .font(.headline)
                Spacer()
                if !contact.relationship.isEmpty {
                    Text(contact.relationship)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !contact.phone.isEmpty {
                Label(contact.phone, systemImage: "phone.fill")
                    .font(.subheadline)
            }

            if !contact.meetingPoint.isEmpty {
                Label(contact.meetingPoint, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !contact.memo.isEmpty {
                Text(contact.memo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.vertical, 4)
    }
}

// MARK: - 追加・編集

struct AddEditContactView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let contact: EmergencyContact?

    @State private var name = ""
    @State private var relationship = ""
    @State private var phone = ""
    @State private var meetingPoint = ""
    @State private var memo = ""

    private var isEditing: Bool { contact != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("お名前", text: $name)
                    TextField("続柄・関係（例：長女、祖母など）", text: $relationship)
                    TextField("電話番号", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section("避難時の集合場所") {
                    TextField("例：〇〇小学校の体育館前、△△公園の時計台など", text: $meetingPoint, axis: .vertical)
                        .lineLimit(2...5)
                } footer: {
                    Text("自宅で会えない場合の一次集合場所・二次集合場所などを記録しておくと安心です。")
                }

                Section("メモ") {
                    TextField("持病・アレルギー・その他共有しておきたいことなど", text: $memo, axis: .vertical)
                        .lineLimit(2...5)
                }

                if isEditing {
                    Section {
                        Button("この連絡先を削除", role: .destructive) {
                            deleteAndDismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "連絡先を編集" : "連絡先を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let contact else { return }
        name = contact.name
        relationship = contact.relationship
        phone = contact.phone
        meetingPoint = contact.meetingPoint
        memo = contact.memo
    }

    private func save() {
        let target = contact ?? EmergencyContact()
        target.name = name
        target.relationship = relationship
        target.phone = phone
        target.meetingPoint = meetingPoint
        target.memo = memo
        if contact == nil {
            context.insert(target)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let contact {
            context.delete(contact)
        }
        dismiss()
    }
}
