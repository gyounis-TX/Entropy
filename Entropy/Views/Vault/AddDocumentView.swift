import SwiftUI
import SwiftData

struct AddDocumentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var label = ""
    @State private var type: VaultItemType = .passport
    @State private var expirationDate: Date?
    @State private var hasExpiration = false
    @State private var notes = ""

    var body: some View {
        Form {
            Section("Document Type") {
                Picker("Type", selection: $type) {
                    ForEach(VaultItemType.allCases, id: \.self) { t in
                        Label(t.displayName, systemImage: t.icon).tag(t)
                    }
                }
            }

            Section("Details") {
                TextField("Label (e.g., \"George Passport\")", text: $label)

                Toggle("Has Expiration Date", isOn: $hasExpiration)
                if hasExpiration {
                    DatePicker("Expires", selection: Binding(
                        get: { expirationDate ?? Date() },
                        set: { expirationDate = $0 }
                    ), displayedComponents: .date)
                }
            }

            Section("Photos") {
                Label("Camera and photo picker will be available on device", systemImage: "camera.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 60)
            }
        }
        .navigationTitle("Add Document")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let item = VaultItem(type: type, label: label)
                    item.expirationDate = hasExpiration ? expirationDate : nil
                    item.notes = notes
                    context.insert(item)

                    // Auto-create expiration reminder if applicable
                    if let exp = item.expirationDate {
                        let reminder = ReminderEngine.shared.createRelativeReminder(
                            title: "\(label) expires soon",
                            daysBefore: 90,
                            anchorDate: exp,
                            sourceType: .vault
                        )
                        reminder.vaultItem = item
                        context.insert(reminder)
                        Task { await ReminderEngine.shared.schedule(reminder) }
                    }

                    dismiss()
                }
                .disabled(label.isEmpty)
            }
        }
    }
}
