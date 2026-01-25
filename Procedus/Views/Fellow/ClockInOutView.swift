// ClockInOutView.swift
// Procedus - Unified
// Real-time clock in/out for comprehensive duty hours tracking

import SwiftUI
import SwiftData

struct ClockInOutView: View {
    let userId: UUID?
    let programId: UUID?
    let activeShift: DutyHoursShift?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query private var programs: [Program]

    @State private var selectedShiftType: DutyHoursShiftType = .regular
    @State private var selectedLocation: DutyHoursShiftLocation = .inHouse
    @State private var showingAddManualShift = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    private var currentProgram: Program? { programs.first }

    /// Shift types enabled by program admin (excludes Day Off for clock-in)
    private var enabledShiftTypes: [DutyHoursShiftType] {
        // Individual mode shows all shift types
        if appState.isIndividualMode {
            return DutyHoursShiftType.allCases.filter { $0 != .dayOff }
        }

        guard let program = currentProgram else {
            return DutyHoursShiftType.allCases.filter { $0 != .dayOff }
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

        return types
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Active shift display or clock in section
                if let activeShift = activeShift {
                    activeShiftView(activeShift)
                } else {
                    clockInSection
                }

                // Quick stats
                quickStatsSection

                // Manual entry button
                manualEntryButton
            }
            .padding(16)
        }
        .onAppear {
            startTimerIfNeeded()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .sheet(isPresented: $showingAddManualShift) {
            AddEditShiftView(userId: userId, programId: programId, editingShift: nil)
        }
    }

    // MARK: - Clock In Section

    private var clockInSection: some View {
        VStack(spacing: 20) {
            // Header
            Text("Start Your Shift")
                .font(.title2)
                .fontWeight(.bold)

            // Shift type selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Shift Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(enabledShiftTypes) { type in
                        ShiftTypeButton(
                            type: type,
                            isSelected: selectedShiftType == type
                        ) {
                            selectedShiftType = type
                        }
                    }
                }
            }

            // Location toggle
            VStack(alignment: .leading, spacing: 12) {
                Text("Location")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Picker("Location", selection: $selectedLocation) {
                    ForEach(DutyHoursShiftLocation.allCases) { location in
                        Label(location.displayName, systemImage: location.iconName)
                            .tag(location)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Clock In button
            Button {
                clockIn()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                    Text("Clock In")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green)
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Active Shift View

    private func activeShiftView(_ shift: DutyHoursShift) -> some View {
        VStack(spacing: 20) {
            // Status indicator
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                Text("Shift In Progress")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
            }

            // Timer display
            Text(formatElapsedTime(elapsedTime))
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(ProcedusTheme.primary)

            // Shift info
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: shift.shiftType.iconName)
                        .foregroundStyle(shift.shiftType.color)
                    Text(shift.shiftType.displayName)
                        .font(.headline)
                }

                HStack {
                    Image(systemName: shift.location.iconName)
                    Text(shift.location.displayName)
                    Text("•")
                    Text("Started \(shift.startTime.formatted(date: .omitted, time: .shortened))")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            // Break button
            Button {
                addBreak()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                    Text("Add 30min Break")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(ProcedusTheme.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ProcedusTheme.primary.opacity(0.1))
                .cornerRadius(8)
            }

            if shift.breakMinutes > 0 {
                Text("Total breaks: \(shift.breakMinutes) minutes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Clock Out button
            Button {
                clockOut()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                    Text("Clock Out")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red)
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Quick Stats Section

    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                QuickStatCard(
                    title: "Hours",
                    value: "0",
                    icon: "clock.fill",
                    color: .blue
                )
                QuickStatCard(
                    title: "Shifts",
                    value: "0",
                    icon: "calendar",
                    color: .green
                )
                QuickStatCard(
                    title: "On Call",
                    value: "0",
                    icon: "phone.fill",
                    color: .orange
                )
            }
        }
    }

    // MARK: - Manual Entry Button

    private var manualEntryButton: some View {
        Button {
            showingAddManualShift = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Manual Shift Entry")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(ProcedusTheme.primary)
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Actions

    private func clockIn() {
        guard let userId = userId else { return }

        let shift = DutyHoursShift(
            userId: userId,
            programId: programId,
            shiftDate: Date(),
            startTime: Date(),
            shiftType: selectedShiftType,
            location: selectedLocation
        )

        modelContext.insert(shift)
        try? modelContext.save()

        startTimerIfNeeded()
    }

    private func clockOut() {
        guard let activeShift = activeShift else { return }
        activeShift.clockOut()
        try? modelContext.save()

        timer?.invalidate()
        elapsedTime = 0
    }

    private func addBreak() {
        guard let activeShift = activeShift else { return }
        activeShift.addBreak(minutes: 30)
        try? modelContext.save()
    }

    private func startTimerIfNeeded() {
        guard let activeShift = activeShift else { return }

        elapsedTime = Date().timeIntervalSince(activeShift.startTime)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(activeShift.startTime)
        }
    }

    private func formatElapsedTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Shift Type Button

struct ShiftTypeButton: View {
    let type: DutyHoursShiftType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: type.iconName)
                    .font(.title3)
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? .white : type.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? type.color : type.color.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

#Preview {
    ClockInOutView(userId: UUID(), programId: nil, activeShift: nil)
        .environment(AppState())
        .modelContainer(for: [DutyHoursShift.self, Program.self], inMemory: true)
}
