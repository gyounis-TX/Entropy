import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context
    @State private var showingAddReminder = false
    @State private var showingTagEditor = false
    @FocusState private var bodyFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                TextField("Title", text: $note.title)
                    .font(.title)
                    .fontWeight(.bold)

                // Tags
                if !note.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(note.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Reminders
                if !note.reminders.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(note.reminders) { reminder in
                            HStack {
                                Image(systemName: reminder.isCompleted ? "bell.slash" : "bell.fill")
                                    .font(.caption)
                                    .foregroundStyle(reminder.isOverdue ? .red : .blue)
                                Text(reminder.title)
                                    .font(.caption)
                                Spacer()
                                Text(reminder.triggerDate, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }

                Divider()

                // Body editor
                TextEditor(text: $note.body)
                    .focused($bodyFocused)
                    .frame(minHeight: 300)
                    .scrollContentBackground(.hidden)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Tag", systemImage: "tag") {
                    showingTagEditor = true
                }
                Button("Remind", systemImage: "bell.badge.fill") {
                    showingAddReminder = true
                }
                Menu {
                    Button(note.isPinned ? "Unpin" : "Pin",
                           systemImage: note.isPinned ? "pin.slash" : "pin") {
                        note.isPinned.toggle()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onChange(of: note.body) {
            note.updatedAt = Date()
        }
        .onChange(of: note.title) {
            note.updatedAt = Date()
        }
        .sheet(isPresented: $showingAddReminder) {
            NavigationStack {
                AddReminderView(sourceType: .note, onSave: { reminder in
                    reminder.note = note
                    context.insert(reminder)
                })
            }
        }
        .alert("Add Tag", isPresented: $showingTagEditor) {
            TagInputAlert(tags: $note.tags)
        }
    }
}

struct TagInputAlert: View {
    @Binding var tags: [String]
    @State private var newTag = ""

    var body: some View {
        TextField("Tag name", text: $newTag)
        Button("Add") {
            let trimmed = newTag.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !tags.contains(trimmed) {
                tags.append(trimmed)
            }
            newTag = ""
        }
        Button("Cancel", role: .cancel) {}
    }
}
