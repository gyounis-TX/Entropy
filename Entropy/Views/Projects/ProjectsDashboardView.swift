import SwiftUI
import SwiftData

struct ProjectsDashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]
    @State private var showingAddProject = false
    @State private var filterStatus: ProjectStatus? = nil
    @State private var projectToDelete: Project?
    @State private var deepLinkedProject: Project?

    private var filteredProjects: [Project] {
        guard let filter = filterStatus else { return projects }
        return projects.filter { $0.status == filter }
    }

    var body: some View {
        Group {
            if projects.isEmpty {
                emptyState
            } else if filteredProjects.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "magnifyingglass")
                } description: {
                    Text("No projects match the selected filter.")
                } actions: {
                    Button("Clear Filter") { filterStatus = nil }
                        .buttonStyle(.bordered)
                }
            } else {
                projectList
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Project", systemImage: "plus") {
                    showingAddProject = true
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu("Filter", systemImage: "line.3.horizontal.decrease") {
                    Button("All") { filterStatus = nil }
                    Divider()
                    ForEach(ProjectStatus.allCases, id: \.self) { status in
                        Button {
                            filterStatus = status
                        } label: {
                            Label(status.displayName, systemImage: status.icon)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddProject) {
            NavigationStack {
                AddProjectView()
            }
        }
        .alert("Delete Project?", isPresented: Binding(
            get: { projectToDelete != nil },
            set: { if !$0 { projectToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let project = projectToDelete {
                    context.delete(project)
                    projectToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                projectToDelete = nil
            }
        } message: {
            if let project = projectToDelete {
                Text("This will permanently delete \"\(project.name)\" and all its steps, notes, and reminders.")
            }
        }
        .onAppear { handleDeepLink() }
        .onChange(of: appState.deepLinkAction) { handleDeepLink() }
        .sheet(item: $deepLinkedProject) { project in
            NavigationStack {
                ProjectDetailView(project: project)
            }
        }
    }

    private func handleDeepLink() {
        guard case .viewProject(let id) = appState.deepLinkAction else { return }
        appState.consumeDeepLink()
        guard let uuid = UUID(uuidString: id) else { return }
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == uuid }
        )
        if let project = try? context.fetch(descriptor).first {
            deepLinkedProject = project
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Projects", systemImage: "folder.badge.plus")
        } description: {
            Text("Track your projects, their status, and next steps. Never lose context again.")
        } actions: {
            Button("Create Project") { showingAddProject = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var projectList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredProjects) { project in
                    NavigationLink(value: project) {
                        ProjectCard(project: project)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete Project", systemImage: "trash", role: .destructive) {
                            projectToDelete = project
                        }
                    }
                }
            }
            .padding()
        }
        .navigationDestination(for: Project.self) { project in
            ProjectDetailView(project: project)
        }
    }
}

struct ProjectCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: project.icon ?? "folder.fill")
                    .foregroundStyle(colorFromName(project.color))
                Text(project.name)
                    .font(.headline)
                Spacer()
                ProjectStatusBadge(status: project.status)
            }

            // Current status
            if !project.currentStatus.isEmpty {
                Text(project.currentStatus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Progress bar
            if project.totalStepCount > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: project.progressPercentage)
                        .tint(colorFromName(project.color))
                    Text("\(project.completedStepCount)/\(project.totalStepCount) steps complete")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Next step preview
            if let nextStep = project.nextSteps.first(where: { !$0.isCompleted }) {
                HStack {
                    Image(systemName: "arrow.right.circle")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("Next: \(nextStep.stepDescription)")
                        .font(.caption)
                        .lineLimit(1)
                }
            }

            // Last updated
            HStack {
                Text("Updated \(project.updatedAt, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                if project.lastSyncDate != nil {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func colorFromName(_ name: String?) -> Color {
        switch name {
        case "green": return .green
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        case "red": return .red
        default: return .blue
        }
    }
}

struct ProjectStatusBadge: View {
    let status: ProjectStatus

    var body: some View {
        let color: Color = switch status {
        case .active: .green
        case .paused: .orange
        case .completed: .blue
        case .archived: .gray
        }

        Label(status.displayName, systemImage: status.icon)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
