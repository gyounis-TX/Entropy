import SwiftUI
import SwiftData

struct CategoryView: View {
    @Bindable var category: NoteCategory
    @Environment(\.modelContext) private var context
    @State private var showingAddNote = false
    @State private var searchText = ""

    enum SortOption: String, CaseIterable {
        case dateNewest = "Newest"
        case dateOldest = "Oldest"
        case title = "Title"
    }

    @State private var sortOption: SortOption = .dateNewest

    private var sortedNotes: [Note] {
        let notes = category.notes
        let pinnedNotes = notes.filter(\.isPinned)
        let unpinnedNotes = notes.filter { !$0.isPinned }

        let sortedUnpinned: [Note]
        switch sortOption {
        case .dateNewest: sortedUnpinned = unpinnedNotes.sorted { $0.updatedAt > $1.updatedAt }
        case .dateOldest: sortedUnpinned = unpinnedNotes.sorted { $0.updatedAt < $1.updatedAt }
        case .title: sortedUnpinned = unpinnedNotes.sorted { $0.title < $1.title }
        }

        return pinnedNotes.sorted(by: { $0.updatedAt > $1.updatedAt }) + sortedUnpinned
    }

    private var filteredNotes: [Note] {
        if searchText.isEmpty { return sortedNotes }
        return sortedNotes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.body.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            ForEach(filteredNotes) { note in
                NavigationLink(value: note) {
                    NoteRow(note: note)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        note.isPinned.toggle()
                    } label: {
                        Label(note.isPinned ? "Unpin" : "Pin",
                              systemImage: note.isPinned ? "pin.slash" : "pin")
                    }
                    .tint(.orange)
                }
            }
            .onDelete { offsets in
                let notesToDelete = offsets.map { filteredNotes[$0] }
                for note in notesToDelete {
                    context.delete(note)
                }
            }
        }
        .navigationTitle(category.name)
        .searchable(text: $searchText, prompt: "Search in \(category.name)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Note", systemImage: "plus") {
                    showingAddNote = true
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu("Sort", systemImage: "arrow.up.arrow.down") {
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: Note.self) { note in
            NoteEditorView(note: note)
        }
        .sheet(isPresented: $showingAddNote) {
            NavigationStack {
                NewNoteSheet(category: category)
            }
        }
    }
}

struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            if !note.body.isEmpty {
                Text(note.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Text(note.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if !note.reminders.isEmpty {
                    Label("\(note.reminders.count)", systemImage: "bell.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }

                if !note.tags.isEmpty {
                    Text(note.tags.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct NewNoteSheet: View {
    let category: NoteCategory
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""

    var body: some View {
        Form {
            TextField("Note Title", text: $title)
        }
        .navigationTitle("New Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    let note = Note(title: title)
                    note.category = category
                    context.insert(note)
                    dismiss()
                }
                .disabled(title.isEmpty)
            }
        }
    }
}
