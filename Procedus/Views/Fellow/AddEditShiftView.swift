// AddEditShiftView.swift
// Procedus - Unified
// Manual entry form for adding or editing duty hours shifts

import SwiftUI
import SwiftData

struct AddEditShiftView: View {
    let userId: UUID?
    let programId: UUID?
    let editingShift: DutyHoursShift?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var shiftDate: Date = Date()
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var hasEndTime: Bool = false
    @State private var shiftType: DutyHoursShiftType = .regular
    @State private var location: DutyHoursShiftLocation = .inHouse
    @State private var breakMinutes: Int = 0
    @State private var notes: String = ""
    @State private var wasCalledIn: Bool = false
    @State private var calledInTime: Date = Date()

    @State private var showingDeleteConfirmation = false

    private var isEditing: Bool { editingShift != nil }

    private var calculatedDuration: Double {
        guard hasEndTime else { return 0 }
        let duration = endTime.timeIntervalSince(startTime)
        let hours = max(0, duration / 3600.0)
        return hours - (Double(breakMinutes) / 60.0)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Date & Time Section
                Section {
                    DatePicker("Date", selection: $shiftDate, displayedComponents: .date)

                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)

                    Toggle("Shift Ended", isOn: $hasEndTime)

                    if hasEndTime {
                        DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Date & Time")
                }

                // Shift Type Section
                Section {
                    Picker("Shift Type", selection: $shiftType) {
                        ForEach(DutyHoursShiftType.allCases) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }

                    Picker("Location", selection: $location) {
                        ForEach(DutyHoursShiftLocation.allCases) { loc in
                            Label(loc.displayName, systemImage: loc.iconName)
                                .tag(loc)
                        }
                    }
                } header: {
                    Text("Shift Details")
                }

                // At-Home Call Section (only for at-home call type)
                if shiftType == .atHomeCall {
                    Section {
                        Toggle("Was Called In", isOn: $wasCalledIn)

                        if wasCalledIn {
                            DatePicker("Called In At", selection: $calledInTime, displayedComponents: .hourAndMinute)
                        }
                    } header: {
                        Text("At-Home Call Details")
                    }
                }

                // Breaks Section
                Section {
                    Stepper("Break Time: \(breakMinutes) minutes", value: $breakMinutes, in: 0...480, step: 15)
                } header: {
                    Text("Breaks")
                } footer: {
                    Text("Total break time taken during this shift")
                }

                // Notes Section
                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                }

                // Summary Section
                if hasEndTime {
                    Section {
                        HStack {
                            Text("Total Duration")
                            Spacer()
                            Text(String(format: "%.1f hours", calculatedDuration))
                                .fontWeight(.semibold)
                                .foregroundStyle(calculatedDuration > 24 ? .red : .primary)
                        }

                        if calculatedDuration > 24 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text("Exceeds 24-hour ACGME limit")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    } header: {
                        Text("Summary")
                    }
                }

                // Delete Section (only when editing)
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete Shift", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Shift" : "Add Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveShift()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadExistingData()
            }
            .alert("Delete Shift?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteShift()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    // MARK: - Load Existing Data

    private func loadExistingData() {
        guard let shift = editingShift else { return }

        shiftDate = shift.shiftDate
        startTime = shift.startTime
        shiftType = shift.shiftType
        location = shift.location
        breakMinutes = shift.breakMinutes
        notes = shift.notes ?? ""
        wasCalledIn = shift.wasCalledIn
        calledInTime = shift.calledInAt ?? Date()

        if let end = shift.endTime {
            hasEndTime = true
            endTime = end
        } else {
            hasEndTime = false
        }
    }

    // MARK: - Save Shift

    private func saveShift() {
        if let existing = editingShift {
            // Update existing shift
            existing.shiftDate = shiftDate
            existing.startTime = combineDateAndTime(date: shiftDate, time: startTime)
            existing.endTime = hasEndTime ? combineDateAndTime(date: shiftDate, time: endTime) : nil
            existing.shiftType = shiftType
            existing.location = location
            existing.breakMinutes = breakMinutes
            existing.notes = notes.isEmpty ? nil : notes
            existing.wasCalledIn = wasCalledIn
            existing.calledInAt = wasCalledIn ? calledInTime : nil
            existing.isActiveShift = !hasEndTime

            if hasEndTime {
                existing.totalHours = calculatedDuration + (Double(breakMinutes) / 60.0)
                existing.effectiveHours = calculatedDuration
            }

            existing.updatedAt = Date()
        } else {
            // Create new shift
            guard let userId = userId else {
                dismiss()
                return
            }

            let shift = DutyHoursShift(
                userId: userId,
                programId: programId,
                shiftDate: shiftDate,
                startTime: combineDateAndTime(date: shiftDate, time: startTime),
                shiftType: shiftType,
                location: location
            )

            shift.breakMinutes = breakMinutes
            shift.notes = notes.isEmpty ? nil : notes
            shift.wasCalledIn = wasCalledIn
            shift.calledInAt = wasCalledIn ? calledInTime : nil
            shift.isActiveShift = !hasEndTime

            if hasEndTime {
                shift.endTime = combineDateAndTime(date: shiftDate, time: endTime)
                shift.totalHours = calculatedDuration + (Double(breakMinutes) / 60.0)
                shift.effectiveHours = calculatedDuration
            }

            modelContext.insert(shift)
        }

        try? modelContext.save()
        dismiss()
    }

    // MARK: - Delete Shift

    private func deleteShift() {
        guard let shift = editingShift else { return }
        modelContext.delete(shift)
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Helper

    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current

        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? date
    }
}

#Preview {
    AddEditShiftView(userId: UUID(), programId: nil, editingShift: nil)
        .modelContainer(for: [DutyHoursShift.self], inMemory: true)
}
