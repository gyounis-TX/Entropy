import Foundation
import UserNotifications
import SwiftData

final class ReminderEngine {
    static let shared = ReminderEngine()

    private let notificationCenter = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permissions

    func requestPermission() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }

    // MARK: - Scheduling

    func schedule(_ reminder: Reminder) async {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body ?? ""
        content.sound = .default
        content.userInfo = [
            "reminderID": reminder.id.uuidString,
            "sourceType": reminder.sourceType.rawValue
        ]

        let trigger = makeTrigger(for: reminder)
        let request = UNNotificationRequest(
            identifier: reminder.notificationID,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    func cancel(_ reminder: Reminder) {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [reminder.notificationID]
        )
    }

    func cancelAll(for sourceType: ReminderSource, sourceID: UUID) async {
        let requests = await notificationCenter.pendingNotificationRequests()
        let matching = requests.filter { req in
            req.content.userInfo["sourceType"] as? String == sourceType.rawValue &&
            req.content.userInfo["reminderID"] as? String != nil
        }
        // Filter by sourceID via the reminder IDs associated with this source
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: matching.map(\.identifier)
        )
    }

    func reschedule(_ reminder: Reminder) async {
        cancel(reminder)
        if !reminder.isCompleted {
            await schedule(reminder)
        }
    }

    func snooze(_ reminder: Reminder, until date: Date, context: ModelContext) async {
        reminder.snoozedUntil = date
        reminder.triggerDate = date
        try? context.save()
        await reschedule(reminder)
    }

    func complete(_ reminder: Reminder, context: ModelContext) {
        if case .recurring(let rule) = reminder.triggerType {
            // For recurring reminders, advance to the next occurrence instead of completing
            let nextDate = nextOccurrence(from: reminder.triggerDate, rule: rule)
            reminder.triggerDate = nextDate
            try? context.save()
            Task { await reschedule(reminder) }
        } else {
            reminder.isCompleted = true
            cancel(reminder)
            try? context.save()
        }
    }

    /// Calculate the next occurrence date for a recurring reminder.
    private func nextOccurrence(from date: Date, rule: RecurrenceRule) -> Date {
        let calendar = Calendar.current
        switch rule {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .custom(let intervalSeconds):
            return date.addingTimeInterval(intervalSeconds)
        }
    }

    // MARK: - Badge

    func updateBadgeCount(context: ModelContext) {
        let now = Date()
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { !$0.isCompleted && $0.triggerDate <= now }
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0
        Task { @MainActor in
            UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }

    // MARK: - Helpers

    func createRelativeReminder(
        title: String,
        daysBefore: Int,
        anchorDate: Date,
        sourceType: ReminderSource
    ) -> Reminder {
        let triggerDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: anchorDate) ?? anchorDate
        let interval = triggerDate.timeIntervalSince(anchorDate)
        return Reminder(
            title: title,
            triggerDate: triggerDate,
            triggerType: .relative(interval, anchorDate: anchorDate),
            sourceType: sourceType
        )
    }

    func createRecurringReminder(
        title: String,
        rule: RecurrenceRule,
        startDate: Date,
        sourceType: ReminderSource
    ) -> Reminder {
        Reminder(
            title: title,
            triggerDate: startDate,
            triggerType: .recurring(rule),
            sourceType: sourceType
        )
    }

    private func makeTrigger(for reminder: Reminder) -> UNNotificationTrigger {
        switch reminder.triggerType {
        case .absolute(let date):
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date
            )
            return UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        case .relative(_, anchorDate: _):
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: reminder.triggerDate
            )
            return UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        case .recurring(let rule):
            let comps = recurrenceComponents(for: rule, from: reminder.triggerDate)
            return UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        }
    }

    private func recurrenceComponents(for rule: RecurrenceRule, from date: Date) -> DateComponents {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.hour, .minute], from: date)

        switch rule {
        case .daily:
            break // hour + minute is enough for daily
        case .weekly(let weekday):
            comps.weekday = weekday
        case .monthly(let day):
            comps.day = day
        case .custom(let interval):
            // For custom intervals, fall back to a time-based trigger approach
            // but UNCalendarNotificationTrigger needs date components, so use daily
            _ = interval
            break
        }

        return comps
    }
}
