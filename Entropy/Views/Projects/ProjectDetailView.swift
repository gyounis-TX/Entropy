import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var context
    @State private var selectedTab: ProjectTab = .status
    @State private var showingAddReminder = false
    @State private var newStepText = ""
    @State private var newNoteText = ""
    @State private var newTagText = ""
    @State private var lastSavedStatus: String = ""

    enum ProjectTab: String, CaseIterable {
        case status = "Status"
        case steps = "Next Steps"
        case notes = "Notes"
        case settings = "Settings"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(ProjectTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch selectedTab {
            case .status:
                ScrollView { statusTab }
            case .steps:
                stepsTab
            case .notes:
                notesTab
            case .settings:
                ScrollView { settingsTab }
            }
        }
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Status", selection: $project.status) {
                        ForEach(ProjectStatus.allCases, id: \.self) { s in
                            Label(s.displayName, systemImage: s.icon).tag(s)
                        }
                    }
                    Button("Add Reminder", systemImage: "bell.badge.fill") {
                        showingAddReminder = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear { lastSavedStatus = project.currentStatus }
        .onDisappear {
            if project.currentStatus != lastSavedStatus {
                project.updatedAt = Date()
            }
        }
        .onChange(of: project.status) { project.updatedAt = Date() }
        .onChange(of: project.name) { project.updatedAt = Date() }
        .onChange(of: project.projectDescription) { project.updatedAt = Date() }
        .sheet(isPresented: $showingAddReminder) {
            NavigationStack {
                AddReminderView(sourceType: .project, onSave: { reminder in
                    reminder.project = project
                    context.insert(reminder)
                })
            }
        }
    }

    // MARK: - Status Tab ("Where was I?")

    private var statusTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // "Where was I?" header
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Current Status", systemImage: "location.fill")
                        .font(.headline)
                    TextEditor(text: $project.currentStatus)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Quick overview
            GroupBox("Overview") {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Status") {
                        ProjectStatusBadge(status: project.status)
                    }
                    if project.totalStepCount > 0 {
                        LabeledContent("Progress") {
                            Text("\(project.completedStepCount)/\(project.totalStepCount)")
                        }
                        ProgressView(value: project.progressPercentage)
                    }
                    LabeledContent("Last Updated") {
                        Text(project.updatedAt, style: .relative)
                    }
                    if let syncDate = project.lastSyncDate {
                        LabeledContent("Last Synced") {
                            Text(syncDate, style: .relative)
                        }
                    }
                }
            }

            // Next immediate step
            if let nextStep = project.nextSteps.first(where: { !$0.isCompleted }) {
                GroupBox("Up Next") {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.blue)
                        Text(nextStep.stepDescription)
                        Spacer()
                        if let date = nextStep.projectedCompletion {
                            Text(date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Steps Tab

    private var stepsTab: some View {
        List {
            let sortedSteps = project.nextSteps.sorted { $0.sortOrder < $1.sortOrder }
            ForEach(sortedSteps) { step in
                ProjectStepRow(step: step, onToggle: {
                    project.updatedAt = Date()
                })
                .contextMenu {
                    Button("Delete Step", role: .destructive) {
                        context.delete(step)
                        project.updatedAt = Date()
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        context.delete(step)
                        project.updatedAt = Date()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            // Add new step
            HStack {
                TextField("Add a step...", text: $newStepText)
                    .textFieldStyle(.roundedBorder)
                Button("Add", systemImage: "plus.circle.fill") {
                    guard !newStepText.isEmpty else { return }
                    let step = ProjectStep(description: newStepText, sortOrder: (project.nextSteps.map(\.sortOrder).max() ?? -1) + 1)
                    step.project = project
                    context.insert(step)
                    project.updatedAt = Date()
                    newStepText = ""
                }
                .disabled(newStepText.isEmpty)
            }
        }
    }

    // MARK: - Notes Tab

    private var notesTab: some View {
        List {
            let sortedNotes = project.notes.sorted { $0.timestamp > $1.timestamp }
            ForEach(sortedNotes) { note in
                ProjectNoteRow(note: note)
                    .contextMenu {
                        Button("Delete Note", role: .destructive) {
                            context.delete(note)
                            project.updatedAt = Date()
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            context.delete(note)
                            project.updatedAt = Date()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }

            // Add new note
            Section {
                TextEditor(text: $newNoteText)
                    .frame(minHeight: 60)

                Button("Add Note") {
                    guard !newNoteText.isEmpty else { return }
                    let note = ProjectNote(content: newNoteText)
                    note.project = project
                    context.insert(note)
                    project.updatedAt = Date()
                    newNoteText = ""
                }
                .buttonStyle(.bordered)
                .disabled(newNoteText.isEmpty)
            }
        }
    }

    // MARK: - Settings Tab

    private var settingsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Project Info") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name", text: $project.name)
                    TextField("Description", text: $project.projectDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
            }

            GroupBox("Tags") {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(project.tags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text("#\(tag)")
                                        .font(.caption)
                                    Button {
                                        project.tags.removeAll { $0 == tag }
                                        project.updatedAt = Date()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
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
                    HStack {
                        TextField("Add tag...", text: $newTagText)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        Button("Add", systemImage: "plus.circle.fill") {
                            let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty && !project.tags.contains(trimmed) {
                                project.tags.append(trimmed)
                                project.updatedAt = Date()
                            }
                            newTagText = ""
                        }
                        .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Text("Tags help organize and filter projects.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let folderPath = project.localFolderPath {
                GroupBox("Auto-Sync (Phase 3)") {
                    LabeledContent("Folder") {
                        Text(folderPath)
                            .font(.caption)
                            .fontDesign(.monospaced)
                    }
                }
            }
        }
        .padding()
    }
}

struct ProjectStepRow: View {
    @Bindable var step: ProjectStep
    var onToggle: (() -> Void)?

    var body: some View {
        HStack(alignment: .top) {
            Button {
                step.isCompleted.toggle()
                onToggle?()
            } label: {
                Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(step.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.stepDescription)
                    .strikethrough(step.isCompleted)
                    .foregroundStyle(step.isCompleted ? .secondary : .primary)
                if let date = step.projectedCompletion {
                    Text("Target: \(date, style: .date)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

struct ProjectNoteRow: View {
    let note: ProjectNote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if note.source == .autoSync {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                Text(note.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(note.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(note.content)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}
