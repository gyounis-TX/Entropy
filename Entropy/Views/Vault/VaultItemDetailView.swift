import SwiftUI
import SwiftData

struct VaultItemDetailView: View {
    @Bindable var item: VaultItem
    @Environment(\.modelContext) private var context
    @State private var showingAddReminder = false

    var body: some View {
        List {
            // Images
            Section("Document Images") {
                if let frontData = item.imagesFront, let uiImage = UIImage(data: frontData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if let backData = item.imagesBack, let uiImage = UIImage(data: backData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if item.imagesFront == nil && item.imagesBack == nil {
                    Label("No images — tap to add photos", systemImage: "camera.fill")
                        .foregroundStyle(.secondary)
                }
            }

            // Details
            Section("Details") {
                LabeledContent("Type") { Text(item.type.displayName) }
                LabeledContent("Label") {
                    TextField("Label", text: $item.label)
                        .multilineTextAlignment(.trailing)
                }
                if let exp = item.expirationDate {
                    LabeledContent("Expires") {
                        Text(exp, style: .date)
                            .foregroundStyle(item.isExpired ? .red : item.isExpiringSoon ? .orange : .primary)
                    }
                }
            }

            // Custom fields
            Section("Fields") {
                ForEach(item.fields.sorted(by: { $0.sortOrder < $1.sortOrder })) { field in
                    LabeledContent(field.key) {
                        Text(field.value)
                            .textSelection(.enabled)
                    }
                }

                Button("Add Field", systemImage: "plus") {
                    let field = VaultField(key: "New Field", value: "", sortOrder: item.fields.count)
                    field.vaultItem = item
                    context.insert(field)
                }
            }

            // Notes
            Section("Notes") {
                TextEditor(text: $item.notes)
                    .frame(minHeight: 60)
            }

            // Reminders
            Section("Reminders") {
                ForEach(item.reminders) { reminder in
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(.blue)
                        Text(reminder.title)
                        Spacer()
                        Text(reminder.triggerDate, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Add Reminder", systemImage: "bell.badge.fill") {
                    showingAddReminder = true
                }
            }
        }
        .navigationTitle(item.label)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: item.label) { item.updatedAt = Date() }
        .onChange(of: item.notes) { item.updatedAt = Date() }
        .sheet(isPresented: $showingAddReminder) {
            NavigationStack {
                AddReminderView(sourceType: .vault, onSave: { reminder in
                    reminder.vaultItem = item
                    context.insert(reminder)
                })
            }
        }
    }
}
