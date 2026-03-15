import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NoteCategory.sortOrder) private var categories: [NoteCategory]
    @State private var categoryToDelete: NoteCategory?

    var body: some View {
        List {
            ForEach(categories) { category in
                HStack {
                    Image(systemName: category.icon ?? "folder.fill")
                        .foregroundStyle(colorFromName(category.color))
                    Text(category.name)
                    Spacer()
                    Text("\(category.noteCount) notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                if let first = offsets.first {
                    categoryToDelete = categories[first]
                }
            }
            .onMove { source, destination in
                var reordered = categories.map { $0 }
                reordered.move(fromOffsets: source, toOffset: destination)
                for (index, cat) in reordered.enumerated() {
                    cat.sortOrder = index
                }
            }
        }
        .navigationTitle("Manage Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .alert("Delete Category?", isPresented: Binding(
            get: { categoryToDelete != nil },
            set: { if !$0 { categoryToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let category = categoryToDelete {
                    for note in category.notes {
                        for reminder in note.reminders {
                            ReminderEngine.shared.cancel(reminder)
                        }
                    }
                    context.delete(category)
                    categoryToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                categoryToDelete = nil
            }
        } message: {
            if let category = categoryToDelete {
                Text("This will permanently delete \"\(category.name)\" and all \(category.noteCount) notes in it.")
            }
        }
    }

    private func colorFromName(_ name: String?) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        default: return .blue
        }
    }
}
