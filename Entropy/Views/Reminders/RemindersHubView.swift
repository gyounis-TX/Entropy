import SwiftUI
import SwiftData

struct RemindersHubView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Reminder.triggerDate) private var allReminders: [Reminder]
    @State private var showingAddReminder = false
    @State private var filterCompleted = false
    @State private var highlightedReminderID: UUID?

    private var activeReminders: [Reminder] {
        allReminders.filter { !$0.isCompleted }
    }

    private var completedReminders: [Reminder] {
        allReminders.filter(\.isCompleted)
    }

    private var overdueReminders: [Reminder] {
        activeReminders.filter(\.isOverdue)
    }

    private var todayReminders: [Reminder] {
        activeReminders.filter { $0.isToday && !$0.isOverdue }
    }

    private var thisWeekReminders: [Reminder] {
        activeReminders.filter { $0.isThisWeek && !$0.isToday && !$0.isOverdue }
    }

    private var laterReminders: [Reminder] {
        activeReminders.filter { !$0.isThisWeek && !$0.isOverdue }
    }

    var body: some View {
        Group {
            if activeReminders.isEmpty && (!filterCompleted || completedReminders.isEmpty) {
                emptyState
            } else {
                reminderList
            }
        }
        .navigationTitle("Reminders")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New", systemImage: "plus") {
                    showingAddReminder = true
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Toggle(isOn: $filterCompleted) {
                    Label("Show Completed", systemImage: "checkmark.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddReminder) {
            NavigationStack {
                AddReminderView(sourceType: .standalone, onSave: { reminder in
                    context.insert(reminder)
                })
            }
        }
        .onAppear { handleDeepLink() }
        .onChange(of: appState.deepLinkAction) { handleDeepLink() }
    }

    private func handleDeepLink() {
        guard case .viewReminder(let id) = appState.deepLinkAction else { return }
        appState.consumeDeepLink()
        guard let uuid = UUID(uuidString: id) else { return }
        // Scroll to the reminder by setting the highlighted ID
        highlightedReminderID = uuid
        // If the reminder is completed and we're not showing completed, toggle the filter
        if let reminder = allReminders.first(where: { $0.id == uuid }), reminder.isCompleted {
            filterCompleted = true
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Reminders", systemImage: "bell.slash")
        } description: {
            Text("Reminders from trips, notes, vault, and projects will appear here.")
        }
    }

    private var reminderList: some View {
        ScrollViewReader { proxy in
            List {
                if !overdueReminders.isEmpty {
                    Section {
                        ForEach(overdueReminders) { reminder in
                            ReminderRow(reminder: reminder)
                                .id(reminder.id)
                        }
                    } header: {
                        Label("Overdue", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if !todayReminders.isEmpty {
                    Section("Today") {
                        ForEach(todayReminders) { reminder in
                            ReminderRow(reminder: reminder)
                                .id(reminder.id)
                        }
                    }
                }

                if !thisWeekReminders.isEmpty {
                    Section("This Week") {
                        ForEach(thisWeekReminders) { reminder in
                            ReminderRow(reminder: reminder)
                                .id(reminder.id)
                        }
                    }
                }

                if !laterReminders.isEmpty {
                    Section("Later") {
                        ForEach(laterReminders) { reminder in
                            ReminderRow(reminder: reminder)
                                .id(reminder.id)
                        }
                    }
                }

                if filterCompleted && !completedReminders.isEmpty {
                    Section {
                        ForEach(completedReminders) { reminder in
                            ReminderRow(reminder: reminder)
                                .id(reminder.id)
                        }
                    } header: {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .onChange(of: highlightedReminderID) {
                if let id = highlightedReminderID {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                    // Clear after scrolling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        highlightedReminderID = nil
                    }
                }
            }
        }
    }
}

struct ReminderRow: View {
    @Bindable var reminder: Reminder
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack {
            Button {
                ReminderEngine.shared.complete(reminder, context: context)
            } label: {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(reminder.isCompleted ? .green : reminder.isOverdue ? .red : .blue)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.subheadline)
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    Label(reminder.sourceDescription, systemImage: sourceIcon(reminder.sourceType))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(reminder.triggerDate, style: .date)
                        .font(.caption2)
                        .foregroundStyle(reminder.isOverdue ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
                }
            }

            Spacer()

            Menu {
                Button("Snooze 1 Hour") {
                    let date = Date().addingTimeInterval(3600)
                    Task { await ReminderEngine.shared.snooze(reminder, until: date, context: context) }
                }
                Button("Snooze 1 Day") {
                    let date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    Task { await ReminderEngine.shared.snooze(reminder, until: date, context: context) }
                }
                Button("Complete") {
                    ReminderEngine.shared.complete(reminder, context: context)
                }
                Divider()
                Button("Delete", role: .destructive) {
                    ReminderEngine.shared.cancel(reminder)
                    context.delete(reminder)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sourceIcon(_ source: ReminderSource) -> String {
        switch source {
        case .trip: return "airplane"
        case .note: return "note.text"
        case .vault: return "lock.shield.fill"
        case .project: return "folder.fill"
        case .standalone: return "bell.fill"
        }
    }
}
