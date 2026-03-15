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
    case trip, note, vault, project, standalone
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
        !isCompleted && triggerDate < Date() && (snoozedUntil == nil || snoozedUntil! < Date())
    }

    var effectiveDate: Date {
        snoozedUntil ?? triggerDate
    }

    var isToday: Bool {
        !isCompleted && Calendar.current.isDateInToday(effectiveDate)
    }

    var isThisWeek: Bool {
        guard !isCompleted else { return false }
        let calendar = Calendar.current
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: Date())) else {
            return false
        }
        return !isOverdue && effectiveDate >= calendar.startOfDay(for: Date()) && effectiveDate < weekEnd
    }

    var sourceDescription: String {
        // Check actual relationships first; fall back to sourceType label
        // in case the relationship was cascade-deleted
        if let name = trip?.name { return name }
        if let title = note?.title { return title }
        if let label = vaultItem?.label { return label }
        if let name = project?.name { return name }

        switch sourceType {
        case .trip: return "Trip"
        case .note: return "Note"
        case .vault: return "Vault"
        case .project: return "Project"
        case .standalone: return "Reminder"
        }
    }
}
