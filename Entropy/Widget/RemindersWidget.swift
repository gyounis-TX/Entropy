import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Reminders Widget

/// Shows today's reminders across all sections.
struct RemindersWidget: Widget {
    let kind: String = "RemindersWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RemindersWidgetProvider()) { entry in
            RemindersWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Reminders")
        .description("See your reminders for today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ReminderWidgetEntry: TimelineEntry {
    let date: Date
    let reminders: [WidgetReminder]
    let overdueCount: Int
}

struct WidgetReminder: Identifiable {
    let id: String
    let title: String
    let time: Date
    let sourceIcon: String
    let isOverdue: Bool
}

struct RemindersWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReminderWidgetEntry {
        ReminderWidgetEntry(date: Date(), reminders: [
            WidgetReminder(id: "1", title: "Check in for flight", time: Date(), sourceIcon: "airplane", isOverdue: false),
            WidgetReminder(id: "2", title: "Review project PR", time: Date(), sourceIcon: "folder.fill", isOverdue: false)
        ], overdueCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReminderWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReminderWidgetEntry>) -> Void) {
        let entry = loadReminders()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800)))
        completion(timeline)
    }

    private func loadReminders() -> ReminderWidgetEntry {
        guard let container = SharedModelContainer.create() else {
            return ReminderWidgetEntry(date: Date(), reminders: [], overdueCount: 0)
        }

        let context = ModelContext(container)
        let now = Date()
        let calendar = Calendar.current
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now

        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { !$0.isCompleted && $0.triggerDate <= endOfDay },
            sortBy: [SortDescriptor(\.triggerDate)]
        )

        guard let reminders = try? context.fetch(descriptor) else {
            return ReminderWidgetEntry(date: now, reminders: [], overdueCount: 0)
        }

        let widgetReminders = reminders.map { reminder in
            WidgetReminder(
                id: reminder.id.uuidString,
                title: reminder.title,
                time: reminder.triggerDate,
                sourceIcon: sourceIcon(for: reminder.sourceType),
                isOverdue: reminder.triggerDate < now
            )
        }

        let overdueCount = reminders.filter { $0.triggerDate < now }.count

        return ReminderWidgetEntry(
            date: now,
            reminders: widgetReminders,
            overdueCount: overdueCount
        )
    }

    private func sourceIcon(for source: ReminderSource) -> String {
        switch source {
        case .trip: return "airplane"
        case .note: return "note.text"
        case .vault: return "lock.shield.fill"
        case .project: return "folder.fill"
        case .standalone: return "bell.fill"
        }
    }
}

struct RemindersWidgetView: View {
    let entry: ReminderWidgetEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        if entry.reminders.isEmpty {
            emptyView
        } else {
            reminderListView
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No reminders today")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var reminderListView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.blue)
                Text("Today")
                    .font(.headline)
                Spacer()
                if entry.overdueCount > 0 {
                    Text("\(entry.overdueCount) overdue")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            let maxItems = family == .systemSmall ? 3 : 5
            ForEach(entry.reminders.prefix(maxItems)) { reminder in
                HStack(spacing: 6) {
                    Image(systemName: reminder.sourceIcon)
                        .font(.caption2)
                        .foregroundStyle(reminder.isOverdue ? .red : .blue)
                        .frame(width: 14)
                    Text(reminder.title)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(reminder.time, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if entry.reminders.count > maxItems {
                Text("+\(entry.reminders.count - maxItems) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(4)
    }
}
