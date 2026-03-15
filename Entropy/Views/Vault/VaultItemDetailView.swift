import SwiftUI
import SwiftData
import UIKit

struct VaultItemDetailView: View {
    @Bindable var item: VaultItem
    @Environment(\.modelContext) private var context
    @State private var showingAddReminder = false
    @State private var isEditingPhotos = false

    var body: some View {
        List {
            // Images
            Section("Document Images") {
                if isEditingPhotos {
                    DocumentImagePicker(
                        frontImage: $item.imagesFront,
                        backImage: $item.imagesBack
                    )
                } else {
                    if let frontData = item.imagesFront, let uiImage = UIImage(data: frontData) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Front").font(.caption).foregroundStyle(.secondary)
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    if let backData = item.imagesBack, let uiImage = UIImage(data: backData) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Back").font(.caption).foregroundStyle(.secondary)
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    if item.imagesFront == nil && item.imagesBack == nil {
                        Button {
                            isEditingPhotos = true
                        } label: {
                            Label("Add document photos", systemImage: "doc.viewfinder")
                        }
                    }
                }

                Button(isEditingPhotos ? "Done Editing" : "Edit Photos") {
                    isEditingPhotos.toggle()
                }
                .font(.caption)
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
                    VaultFieldRow(field: field)
                }
                .onDelete { offsets in
                    let sorted = item.fields.sorted(by: { $0.sortOrder < $1.sortOrder })
                    for index in offsets {
                        context.delete(sorted[index])
                    }
                }

                Button("Add Field", systemImage: "plus") {
                    let field = VaultField(key: "New Field", value: "", sortOrder: item.fields.count)
                    field.vaultItem = item
                    context.insert(field)
                }
            }

            // Expiration
            if item.expirationDate != nil {
                Section("Expiration") {
                    DatePicker("Expires", selection: Binding(
                        get: { item.expirationDate ?? Date() },
                        set: { item.expirationDate = $0 }
                    ), displayedComponents: .date)
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
        .onChange(of: item.imagesFront) { item.updatedAt = Date() }
        .onChange(of: item.imagesBack) { item.updatedAt = Date() }
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

struct VaultFieldRow: View {
    @Bindable var field: VaultField

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Field Name", text: $field.key)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Value", text: $field.value)
                .textSelection(.enabled)
        }
    }
}
