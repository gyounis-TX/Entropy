import SwiftUI
import SwiftData
import PhotosUI

struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context
    @State private var showingAddReminder = false
    @State private var showingTagEditor = false
    @State private var isPreviewMode = false
    @State private var selectedPhoto: PhotosPickerItem?
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
                                HStack(spacing: 4) {
                                    Text("#\(tag)")
                                        .font(.caption)
                                    Button {
                                        note.tags.removeAll { $0 == tag }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.plain)
                                }
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

                // Attachments
                if !note.attachments.isEmpty {
                    AttachmentViewer(attachments: note.attachments) { attachment in
                        context.delete(attachment)
                    }
                }

                // Edit/Preview toggle
                Picker("Mode", selection: $isPreviewMode) {
                    Label("Edit", systemImage: "pencil").tag(false)
                    Label("Preview", systemImage: "eye").tag(true)
                }
                .pickerStyle(.segmented)

                Divider()

                // Body — markdown editor or preview
                if isPreviewMode {
                    if note.body.isEmpty {
                        Text("Nothing to preview")
                            .foregroundStyle(.tertiary)
                            .italic()
                    } else {
                        MarkdownPreview(markdown: note.body)
                    }
                } else {
                    MarkdownEditorView(text: $note.body, isFocused: $bodyFocused)
                        .frame(minHeight: 300)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "paperclip")
                }
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
        .onChange(of: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            let capturedItem = item
            Task {
                if let data = try? await capturedItem.loadTransferable(type: Data.self) {
                    guard selectedPhoto == capturedItem else { return }
                    let attachment = Attachment(
                        fileName: "Photo \(Date().formatted(date: .abbreviated, time: .shortened))",
                        data: data,
                        mimeType: "image/jpeg"
                    )
                    attachment.note = note
                    context.insert(attachment)
                }
                selectedPhoto = nil
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
