import SwiftUI
import SwiftData

struct AddTripView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var status: TripStatus = .planning

    var body: some View {
        Form {
            Section("Trip Details") {
                TextField("Trip Name", text: $name)
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
            }

            Section("Status") {
                Picker("Status", selection: $status) {
                    ForEach(TripStatus.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .onChange(of: startDate) { _, newStart in
            if endDate < newStart {
                endDate = newStart
            }
        }
        .navigationTitle("New Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    let trip = Trip(name: name, startDate: startDate, endDate: endDate, status: status)
                    context.insert(trip)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
        }
    }
}
