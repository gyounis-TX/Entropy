import Foundation
import SwiftData

enum ProjectStatus: String, Codable, CaseIterable {
    case active, paused, completed, archived

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }

    var icon: String {
        switch self {
        case .active: return "bolt.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .archived: return "archivebox.fill"
        }
    }

    var color: String {
        switch self {
        case .active: return "green"
        case .paused: return "orange"
        case .completed: return "blue"
        case .archived: return "gray"
        }
    }
}

enum NoteSource: String, Codable {
    case manual, autoSync
}

@Model
final class Project {
    var id: UUID
    var name: String
    var projectDescription: String
    var status: ProjectStatus
    var createdAt: Date
    var updatedAt: Date
    var icon: String?
    var color: String?
    var currentStatus: String
    var localFolderPath: String?
    var lastSyncDate: Date?
    var tags: [String]

    @Relationship(deleteRule: .cascade, inverse: \ProjectStep.project)
    var nextSteps: [ProjectStep]

    @Relationship(deleteRule: .cascade, inverse: \ProjectNote.project)
    var notes: [ProjectNote]

    @Relationship(deleteRule: .cascade, inverse: \Reminder.project)
    var reminders: [Reminder]

    init(name: String, description: String = "", status: ProjectStatus = .active) {
        self.id = UUID()
        self.name = name
        self.projectDescription = description
        self.status = status
        self.createdAt = Date()
        self.updatedAt = Date()
        self.currentStatus = ""
        self.tags = []
        self.nextSteps = []
        self.notes = []
        self.reminders = []
    }

    var completedStepCount: Int {
        nextSteps.filter(\.isCompleted).count
    }

    var totalStepCount: Int {
        nextSteps.count
    }

    var progressPercentage: Double {
        guard totalStepCount > 0 else { return 0 }
        return Double(completedStepCount) / Double(totalStepCount)
    }
}

@Model
final class ProjectStep {
    var id: UUID
    var stepDescription: String
    var isCompleted: Bool
    var projectedCompletion: Date?
    var sortOrder: Int

    @Relationship var project: Project?
    @Relationship var reminder: Reminder?

    init(description: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.stepDescription = description
        self.isCompleted = false
        self.sortOrder = sortOrder
    }
}

@Model
final class ProjectNote {
    var id: UUID
    var content: String
    var timestamp: Date
    var source: NoteSource

    @Relationship var project: Project?

    init(content: String, source: NoteSource = .manual) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.source = source
    }
}
