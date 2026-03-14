import Foundation
import SwiftData

enum ReminderTriggerType: Codable {
    case absolute(Date)
    case relative(TimeInterval, anchorDate: Date)
    case recurring(RecurrenceRule)
}

enum RecurrenceRule: Codable {
    case daily
    case weekly(weekday: Int)
    case monthly(day: Int)
    case custom(intervalSeconds: TimeInterval)
}

enum ReminderSource: String, Codable {
    case trip, note, vault, project
}

@Model
final class Reminder {
    var id: UUID
    var title: String
    var body: String?
    var triggerDate: Date
    var triggerType: ReminderTriggerType
    var isCompleted: Bool
    var sourceType: ReminderSource
    var notificationID: String
    var createdAt: Date
    var snoozedUntil: Date?

    @Relationship var trip: Trip?
    @Relationship var note: Note?
    @Relationship var vaultItem: VaultItem?
    @Relationship var project: Project?
    @Relationship var tripTodo: TripTodo?
    @Relationship var projectStep: ProjectStep?

    init(title: String, triggerDate: Date, triggerType: ReminderTriggerType, sourceType: ReminderSource) {
        self.id = UUID()
        self.title = title
        self.triggerDate = triggerDate
        self.triggerType = triggerType
        self.isCompleted = false
        self.sourceType = sourceType
        self.notificationID = UUID().uuidString
        self.createdAt = Date()
    }

    var isOverdue: Bool {
        !isCompleted && triggerDate < Date()
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(triggerDate)
    }

    var isThisWeek: Bool {
        let calendar = Calendar.current
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: Date())) else {
            return false
        }
        return triggerDate >= calendar.startOfDay(for: Date()) && triggerDate < weekEnd
    }

    var sourceDescription: String {
        switch sourceType {
        case .trip: return trip?.name ?? "Trip"
        case .note: return note?.title ?? "Note"
        case .vault: return vaultItem?.label ?? "Vault"
        case .project: return project?.name ?? "Project"
        }
    }
}
