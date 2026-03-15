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
    @State private var frontImageData: Data?
    @State private var backImageData: Data?

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
                    .onChange(of: hasExpiration) {
                        if hasExpiration && expirationDate == nil {
                            expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
                        }
                    }
                if hasExpiration {
                    DatePicker("Expires", selection: Binding(
                        get: { expirationDate ?? Date() },
                        set: { expirationDate = $0 }
                    ), displayedComponents: .date)
                }
            }

            Section("Document Photos") {
                DocumentImagePicker(
                    frontImage: $frontImageData,
                    backImage: $backImageData
                )
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
                    item.imagesFront = frontImageData
                    item.imagesBack = backImageData
                    context.insert(item)

                    // Auto-create expiration reminder if applicable
                    if let exp = item.expirationDate {
                        let reminder = ReminderEngine.shared.createRelativeReminder(
                            title: "\(label) expires soon",
                            daysBefore: 90,
                            anchorDate: exp,
                            sourceType: .vault
                        )
                        // Clamp trigger date to today if expiration is less than 90 days away
                        if reminder.triggerDate < Date() {
                            reminder.triggerDate = Date()
                        }
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
