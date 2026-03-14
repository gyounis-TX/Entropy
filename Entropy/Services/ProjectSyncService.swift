import Foundation
import SwiftData

/// Manages project status tracking. Phase 1: manual updates only.
/// Phase 3 will add iCloud-based auto-sync with Mac companion agent.
@Observable
final class ProjectSyncService {

    /// Status payload format matching the Mac companion agent output.
    /// Used for both manual imports and future auto-sync.
    struct ProjectStatusPayload: Codable {
        let projectName: String
        let folderPath: String?
        let lastUpdated: Date
        let currentStatus: String
        let recentChanges: [String]
        let nextSteps: [String]
        let gitBranch: String?
        let lastCommitMessage: String?
        let lastCommitDate: Date?
    }

    // MARK: - Manual Project Management

    func createProject(name: String, description: String, context: ModelContext) -> Project {
        let project = Project(name: name, description: description)
        context.insert(project)
        try? context.save()
        return project
    }

    func updateStatus(_ project: Project, status: String, context: ModelContext) {
        project.currentStatus = status
        project.updatedAt = Date()

        // Auto-log the status change
        let note = ProjectNote(content: "Status updated: \(status)", source: .manual)
        note.project = project
        context.insert(note)
        try? context.save()
    }

    func addStep(_ project: Project, description: String, projectedCompletion: Date? = nil, context: ModelContext) {
        let sortOrder = project.nextSteps.count
        let step = ProjectStep(description: description, sortOrder: sortOrder)
        step.projectedCompletion = projectedCompletion
        step.project = project
        context.insert(step)
        try? context.save()
    }

    func completeStep(_ step: ProjectStep, context: ModelContext) {
        step.isCompleted = true
        if let project = step.project {
            project.updatedAt = Date()
            let note = ProjectNote(
                content: "Completed: \(step.stepDescription)",
                source: .manual
            )
            note.project = project
            context.insert(note)
        }
        try? context.save()
    }

    func addNote(_ project: Project, content: String, context: ModelContext) {
        let note = ProjectNote(content: content, source: .manual)
        note.project = project
        context.insert(note)
        project.updatedAt = Date()
        try? context.save()
    }

    // MARK: - Import from Payload (for future auto-sync compatibility)

    /// Imports a status payload into a project, creating steps and notes.
    /// This is the bridge point for Phase 3 auto-sync — the Mac companion agent
    /// will write .project-status.json files that get imported through this method.
    func importPayload(_ payload: ProjectStatusPayload, into project: Project, context: ModelContext) {
        project.currentStatus = payload.currentStatus
        project.updatedAt = payload.lastUpdated
        project.localFolderPath = payload.folderPath
        project.lastSyncDate = Date()

        // Add recent changes as auto-synced notes
        for change in payload.recentChanges {
            let note = ProjectNote(content: change, source: .autoSync)
            note.project = project
            context.insert(note)
        }

        // Merge next steps (don't duplicate existing ones)
        let existingDescriptions = Set(project.nextSteps.map(\.stepDescription))
        for (index, stepDesc) in payload.nextSteps.enumerated() {
            if !existingDescriptions.contains(stepDesc) {
                let step = ProjectStep(description: stepDesc, sortOrder: project.nextSteps.count + index)
                step.project = project
                context.insert(step)
            }
        }

        try? context.save()
    }

    // MARK: - Phase 3 Placeholder: iCloud Folder Watching

    /// In Phase 3, this will watch an iCloud Drive folder for .project-status.json files
    /// written by the Mac companion agent. For now, it's a no-op.
    func startWatchingForSyncFiles() {
        // Phase 3: Use NSMetadataQuery to watch for iCloud Drive changes
        // in a designated folder (e.g., ~/Library/Mobile Documents/.../Entropy/ProjectSync/)
        // When a .project-status.json file changes, parse and call importPayload()
    }
}
