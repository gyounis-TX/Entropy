import SwiftUI

/// Reusable inline reminder picker that can be embedded in any form.
struct ReminderPickerView: View {
    @Binding var isEnabled: Bool
    @Binding var triggerDate: Date
    @Binding var isRelative: Bool
    @Binding var relativeDays: Int
    @Binding var anchorDate: Date

    var body: some View {
        Toggle("Set Reminder", isOn: $isEnabled)

        if isEnabled {
            Picker("Type", selection: $isRelative) {
                Text("Specific Date").tag(false)
                Text("Relative").tag(true)
            }
            .pickerStyle(.segmented)

            if isRelative {
                Stepper("\(relativeDays) days before", value: $relativeDays, in: 1...365)
                DatePicker("Before", selection: $anchorDate, displayedComponents: .date)
            } else {
                DatePicker("Date & Time", selection: $triggerDate)
            }
        }
    }
}
