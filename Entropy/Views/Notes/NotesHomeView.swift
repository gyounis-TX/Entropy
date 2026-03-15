import SwiftUI
import SwiftData

struct NotesHomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \NoteCategory.sortOrder) private var categories: [NoteCategory]
    @State private var showingAddCategory = false
    @State private var showingManageCategories = false
    @State private var showingNewNoteForCategory: NoteCategory?
    @State private var deepLinkedNote: Note?
    @State private var searchText = ""
    @State private var hasSeeded = false

    var body: some View {
        Group {
            if categories.isEmpty && !hasSeeded {
                emptyState
            } else {
                categoryGrid
            }
        }
        .navigationTitle("Notes")
        .searchable(text: $searchText, prompt: "Search notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Category", systemImage: "folder.badge.plus") {
                        showingAddCategory = true
                    }
                    Button("Manage Categories", systemImage: "slider.horizontal.3") {
                        showingManageCategories = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            seedDefaultsIfNeeded()
            handleDeepLink()
        }
        .onChange(of: appState.deepLinkAction) { handleDeepLink() }
        .sheet(item: $showingNewNoteForCategory) { category in
            NavigationStack {
                NewNoteSheet(category: category)
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            NavigationStack {
                AddCategorySheet(sortOrder: categories.count)
            }
        }
        .sheet(isPresented: $showingManageCategories) {
            NavigationStack {
                CategoryManagementView()
            }
        }
        .sheet(item: $deepLinkedNote) { note in
            NavigationStack {
                NoteEditorView(note: note)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Notes", systemImage: "note.text")
        } description: {
            Text("Create categories to organize your notes.")
        } actions: {
            Button("Get Started") { seedDefaultsIfNeeded() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var filteredCategories: [NoteCategory] {
        if searchText.isEmpty { return categories }
        return categories.filter { category in
            category.name.localizedCaseInsensitiveContains(searchText) ||
            category.notes.contains { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.body.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var categoryGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(filteredCategories) { category in
                    NavigationLink(value: category) {
                        CategoryCard(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: NoteCategory.self) { category in
            CategoryView(category: category)
        }
    }

    private func handleDeepLink() {
        guard let action = appState.deepLinkAction else { return }
        switch action {
        case .createNote(let categoryID):
            appState.consumeDeepLink()
            if let categoryID,
               let category = categories.first(where: { $0.id.uuidString == categoryID }) {
                showingNewNoteForCategory = category
            } else if let first = categories.first {
                showingNewNoteForCategory = first
            } else {
                showingAddCategory = true
            }
        case .viewNote(let id):
            appState.consumeDeepLink()
            guard let uuid = UUID(uuidString: id) else { return }
            let descriptor = FetchDescriptor<Note>(
                predicate: #Predicate { $0.id == uuid }
            )
            if let note = try? context.fetch(descriptor).first {
                deepLinkedNote = note
            }
        default:
            break
        }
    }

    private func seedDefaultsIfNeeded() {
        hasSeeded = true
        let defaults = NoteCategory.defaultCategories
        for cat in defaults {
            let name = cat.name
            let descriptor = FetchDescriptor<NoteCategory>(
                predicate: #Predicate { $0.name == name }
            )
            let existing = (try? context.fetchCount(descriptor)) ?? 0
            if existing == 0 {
                context.insert(cat)
            }
        }
    }
}

struct CategoryCard: View {
    let category: NoteCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon ?? "folder.fill")
                    .font(.title2)
                    .foregroundStyle(colorFromName(category.color))
                Spacer()
                Text("\(category.noteCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(category.name)
                .font(.headline)
                .lineLimit(1)
        }
        .padding()
        .background(colorFromName(category.color).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

struct AddCategorySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let sortOrder: Int

    @State private var name = ""
    @State private var selectedColor = "blue"
    @State private var selectedIcon = "folder.fill"

    private let colors = ["blue", "green", "orange", "red", "purple", "pink", "yellow"]
    private let icons = ["folder.fill", "briefcase.fill", "building.2.fill", "house.fill",
                          "book.fill", "star.fill", "heart.fill", "flag.fill"]

    var body: some View {
        Form {
            TextField("Category Name", text: $name)

            Section("Color") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(colorFromName(color))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                            .font(.caption)
                                    }
                                }
                                .onTapGesture { selectedColor = color }
                        }
                    }
                }
            }

            Section("Icon") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(width: 40, height: 40)
                                .background(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture { selectedIcon = icon }
                        }
                    }
                }
            }
        }
        .navigationTitle("New Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    let cat = NoteCategory(name: name, icon: selectedIcon, color: selectedColor, sortOrder: sortOrder)
                    context.insert(cat)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
        }
    }

    private func colorFromName(_ name: String) -> Color {
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
