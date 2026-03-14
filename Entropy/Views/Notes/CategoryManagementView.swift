import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NoteCategory.sortOrder) private var categories: [NoteCategory]

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
                let toDelete = offsets.map { categories[$0] }
                for item in toDelete {
                    context.delete(item)
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
    }

    private func colorFromName(_ name: String?) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        default: return .blue
        }
    }
}
