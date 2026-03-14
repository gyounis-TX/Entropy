import WidgetKit
import SwiftUI

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
            WidgetReminder(id: "2", title: "Review Procedus PR", time: Date(), sourceIcon: "folder.fill", isOverdue: false)
        ], overdueCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReminderWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReminderWidgetEntry>) -> Void) {
        // In production: read from shared SwiftData container
        let entry = ReminderWidgetEntry(date: Date(), reminders: [], overdueCount: 0)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800)))
        completion(timeline)
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
