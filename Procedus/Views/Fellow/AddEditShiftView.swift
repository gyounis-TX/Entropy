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
    @Environment(AppState.self) private var appState

    @Query private var programs: [Program]
    @Query private var users: [User]
    @Query(sort: \DutyHoursShift.shiftDate, order: .reverse) private var allShifts: [DutyHoursShift]
    @Query(sort: \DutyHoursEntry.weekBucket, order: .reverse) private var allEntries: [DutyHoursEntry]

    @State private var shiftDate: Date = Date()
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var hasEndTime: Bool = false
    @State private var isOvernightShift: Bool = false  // End time is next day
    @State private var shiftType: DutyHoursShiftType = .regular
    @State private var location: DutyHoursShiftLocation = .inHouse
    @State private var breakMinutes: Int = 0
    @State private var notes: String = ""
    @State private var wasCalledIn: Bool = false
    @State private var calledInTime: Date = Date()

    @State private var showingDeleteConfirmation = false

    private var isEditing: Bool { editingShift != nil }

    private var currentProgram: Program? { programs.first }

    /// Shift types enabled by program admin (Regular and Day Off always available)
    private var enabledShiftTypes: [DutyHoursShiftType] {
        // Individual mode shows all shift types
        if appState.isIndividualMode {
            return DutyHoursShiftType.allCases
        }

        guard let program = currentProgram else {
            return DutyHoursShiftType.allCases
        }

        var types: [DutyHoursShiftType] = [.regular]  // Always available

        if program.dutyHoursCallEnabled {
            types.append(.call)
        }
        if program.dutyHoursNightFloatEnabled {
            types.append(.nightFloat)
        }
        if program.dutyHoursMoonlightingEnabled {
            types.append(.moonlighting)
        }
        if program.dutyHoursAtHomeCallEnabled {
            types.append(.atHomeCall)
        }

        types.append(.dayOff)  // Always available

        return types
    }

    /// Calculate duration accounting for overnight shifts
    private var calculatedDuration: Double {
        guard hasEndTime else { return 0 }

        var duration: TimeInterval
        if isOvernightShift {
            // End time is on the next day
            let calendar = Calendar.current
            let nextDayEnd = calendar.date(byAdding: .day, value: 1, to: endTime) ?? endTime
            duration = nextDayEnd.timeIntervalSince(startTime)
        } else {
            duration = endTime.timeIntervalSince(startTime)
        }

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
                        .onChange(of: startTime) { _, _ in
                            autoDetectOvernightShift()
                        }

                    Toggle("Shift Ended", isOn: $hasEndTime)

                    if hasEndTime {
                        DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                            .onChange(of: endTime) { _, _ in
                                autoDetectOvernightShift()
                            }

                        Toggle("Overnight Shift", isOn: $isOvernightShift)
                    }
                } header: {
                    Text("Date & Time")
                } footer: {
                    if hasEndTime && isOvernightShift {
                        Text("End time is on the following day")
                    }
                }

                // Shift Type Section
                Section {
                    Picker("Shift Type", selection: $shiftType) {
                        ForEach(enabledShiftTypes) { type in
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

            // Detect if this is an overnight shift (end time is on a different day than start)
            let calendar = Calendar.current
            let startDay = calendar.component(.day, from: shift.startTime)
            let endDay = calendar.component(.day, from: end)
            isOvernightShift = endDay != startDay
        } else {
            hasEndTime = false
            isOvernightShift = false
        }
    }

    // MARK: - Save Shift

    private func saveShift() {
        let calendar = Calendar.current

        // Calculate the actual end time, accounting for overnight shifts
        let actualEndDate: Date? = hasEndTime ? {
            let baseEnd = combineDateAndTime(date: shiftDate, time: endTime)
            if isOvernightShift {
                return calendar.date(byAdding: .day, value: 1, to: baseEnd) ?? baseEnd
            }
            return baseEnd
        }() : nil

        if let existing = editingShift {
            // Update existing shift
            existing.shiftDate = shiftDate
            existing.startTime = combineDateAndTime(date: shiftDate, time: startTime)
            existing.endTime = actualEndDate
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
                shift.endTime = actualEndDate
                shift.totalHours = calculatedDuration + (Double(breakMinutes) / 60.0)
                shift.effectiveHours = calculatedDuration
            }

            modelContext.insert(shift)
        }

        try? modelContext.save()

        // Check compliance and notify if warnings/violations
        checkComplianceAndNotify()

        dismiss()
    }

    /// Check duty hours compliance and send notifications for warnings/violations
    private func checkComplianceAndNotify() {
        guard let userId = userId else { return }

        let fellowName = appState.currentUser?.fullName ?? "Fellow"

        // Get admin IDs from the same program
        let adminIds = users
            .filter { $0.role == .admin && $0.programId == programId && !$0.isArchived }
            .map { $0.id }

        // Get user's shifts and entries
        let userShifts = allShifts.filter { $0.userId == userId }
        let userEntries = allEntries.filter { $0.userId == userId }

        // Check and notify
        DutyHoursComplianceService.shared.checkAndNotify(
            userId: userId,
            fellowName: fellowName,
            programId: programId,
            shifts: userShifts,
            simpleEntries: userEntries,
            adminIds: adminIds
        )
    }

    // MARK: - Delete Shift

    private func deleteShift() {
        guard let shift = editingShift else { return }
        modelContext.delete(shift)
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Helper

    /// Auto-detect overnight shift based on AM/PM discrepancy
    /// If end time hour is before start time hour, it must cross midnight
    private func autoDetectOvernightShift() {
        guard hasEndTime else { return }

        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: startTime)
        let endHour = calendar.component(.hour, from: endTime)
        let startMinute = calendar.component(.minute, from: startTime)
        let endMinute = calendar.component(.minute, from: endTime)

        // Convert to minutes since midnight for comparison
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        // If end time is earlier than start time, it must be an overnight shift
        // e.g., Start 8 PM (20:00 = 1200 min), End 6 AM (6:00 = 360 min) -> overnight
        // e.g., Start 11 PM (23:00 = 1380 min), End 2 AM (2:00 = 120 min) -> overnight
        if endMinutes < startMinutes {
            isOvernightShift = true
        } else {
            // Don't auto-turn off if user manually set it to overnight
            // Only auto-turn on, not off
        }
    }

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
        .environment(AppState())
        .modelContainer(for: [DutyHoursShift.self, Program.self], inMemory: true)
}
