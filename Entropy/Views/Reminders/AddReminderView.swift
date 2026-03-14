import SwiftUI

struct AddReminderView: View {
    let sourceType: ReminderSource
    let onSave: (Reminder) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var body = ""
    @State private var triggerMode: TriggerMode = .absolute
    @State private var absoluteDate = Date()
    @State private var relativeDays = 7
    @State private var anchorDate = Date()
    @State private var recurrence: RecurrenceOption = .none

    enum TriggerMode: String, CaseIterable {
        case absolute = "Specific Date"
        case relative = "Relative"
        case recurring = "Recurring"
    }

    enum RecurrenceOption: String, CaseIterable {
        case none = "None"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
    }

    var body: some View {
        Form {
            Section("Reminder") {
                TextField("Title", text: $title)
                TextField("Details (optional)", text: $body)
            }

            Section("When") {
                Picker("Trigger", selection: $triggerMode) {
                    ForEach(TriggerMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch triggerMode {
                case .absolute:
                    DatePicker("Date & Time", selection: $absoluteDate)

                case .relative:
                    Stepper("**\(relativeDays)** days before", value: $relativeDays, in: 1...365)
                    DatePicker("Anchor Date", selection: $anchorDate, displayedComponents: .date)
                    let computed = Calendar.current.date(byAdding: .day, value: -relativeDays, to: anchorDate)
                    if let date = computed {
                        LabeledContent("Will fire") {
                            Text(date, style: .date)
                                .foregroundStyle(.blue)
                        }
                    }

                case .recurring:
                    Picker("Repeat", selection: $recurrence) {
                        ForEach(RecurrenceOption.allCases, id: \.self) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    DatePicker("Starting", selection: $absoluteDate)
                }
            }
        }
        .navigationTitle("Add Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let reminder = buildReminder()
                    onSave(reminder)
                    Task { await ReminderEngine.shared.schedule(reminder) }
                    dismiss()
                }
                .disabled(title.isEmpty)
            }
        }
    }

    private func buildReminder() -> Reminder {
        let triggerDate: Date
        let triggerType: ReminderTriggerType

        switch triggerMode {
        case .absolute:
            triggerDate = absoluteDate
            triggerType = .absolute(absoluteDate)

        case .relative:
            let interval = TimeInterval(-relativeDays * 86400)
            triggerDate = anchorDate.addingTimeInterval(interval)
            triggerType = .relative(interval, anchorDate: anchorDate)

        case .recurring:
            triggerDate = absoluteDate
            let rule: RecurrenceRule = switch recurrence {
            case .daily: .daily
            case .weekly: .weekly(weekday: Calendar.current.component(.weekday, from: absoluteDate))
            case .monthly: .monthly(day: Calendar.current.component(.day, from: absoluteDate))
            case .none: .daily
            }
            triggerType = .recurring(rule)
        }

        let reminder = Reminder(
            title: title,
            triggerDate: triggerDate,
            triggerType: triggerType,
            sourceType: sourceType
        )
        if !body.isEmpty {
            reminder.body = body
        }
        return reminder
    }
}
