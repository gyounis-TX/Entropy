// DutyHoursView.swift
// Procedus - Unified
// ACGME-compliant duty hours tracking with simple and comprehensive modes

import SwiftUI
import SwiftData

// MARK: - Main Duty Hours View

struct DutyHoursView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query private var programs: [Program]
    @Query(sort: \DutyHoursEntry.weekBucket, order: .reverse) private var allEntries: [DutyHoursEntry]
    @Query(sort: \DutyHoursShift.shiftDate, order: .reverse) private var allShifts: [DutyHoursShift]

    @AppStorage("dutyHoursLoggingMode") private var loggingModeRaw: String = DutyHoursLoggingMode.simple.rawValue

    @State private var selectedComprehensiveTab: ComprehensiveTab = .log

    private var currentProgram: Program? { programs.first }

    private var allowSimpleMode: Bool {
        // Individual mode always allows simple mode
        if appState.isIndividualMode { return true }
        // Institutional mode respects program setting
        return currentProgram?.allowSimpleDutyHours ?? true
    }

    private var loggingMode: DutyHoursLoggingMode {
        get { DutyHoursLoggingMode(rawValue: loggingModeRaw) ?? .simple }
        set { loggingModeRaw = newValue.rawValue }
    }

    private var userId: UUID? {
        appState.isIndividualMode ? getOrCreateIndividualUserId() : appState.currentUser?.id
    }

    private func getOrCreateIndividualUserId() -> UUID {
        let key = "individualUserUUID"
        if let uuidString = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }
        let newUUID = UUID()
        UserDefaults.standard.set(newUUID.uuidString, forKey: key)
        return newUUID
    }

    private var userEntries: [DutyHoursEntry] {
        guard let userId = userId else { return [] }
        return allEntries.filter { $0.userId == userId }
    }

    private var userShifts: [DutyHoursShift] {
        guard let userId = userId else { return [] }
        return allShifts.filter { $0.userId == userId }
    }

    enum ComprehensiveTab: String, CaseIterable {
        case log = "Log"
        case clockInOut = "Clock"
        case compliance = "Compliance"

        var iconName: String {
            switch self {
            case .log: return "list.clipboard"
            case .clockInOut: return "clock.badge.checkmark"
            case .compliance: return "checkmark.shield"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode toggle (only show if simple mode is allowed)
                if allowSimpleMode {
                    modeToggle
                }

                // Content based on mode
                if loggingMode == .simple && allowSimpleMode {
                    SimpleWeeklyHoursView(
                        userEntries: userEntries,
                        userId: userId,
                        programId: appState.currentUser?.programId
                    )
                } else {
                    comprehensiveContent
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true) // Hide nav bar - unified top bar is in FellowContentWrapper
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        Picker("Mode", selection: Binding(
            get: { loggingMode },
            set: { loggingModeRaw = $0.rawValue }
        )) {
            ForEach(DutyHoursLoggingMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Comprehensive Content

    private var comprehensiveContent: some View {
        VStack(spacing: 0) {
            // Tab bar for comprehensive mode
            comprehensiveTabBar

            // Tab content
            switch selectedComprehensiveTab {
            case .log:
                ComprehensiveShiftLogView(shifts: userShifts, userId: userId)
            case .clockInOut:
                ClockInOutView(
                    userId: userId,
                    programId: appState.currentUser?.programId,
                    activeShift: userShifts.first { $0.isActiveShift }
                )
            case .compliance:
                FellowComplianceDashboardView(
                    shifts: userShifts,
                    simpleEntries: userEntries,
                    userId: userId
                )
            }
        }
    }

    private var comprehensiveTabBar: some View {
        HStack(spacing: 0) {
            ForEach(ComprehensiveTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedComprehensiveTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 20))
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .foregroundStyle(selectedComprehensiveTab == tab ? ProcedusTheme.primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedComprehensiveTab == tab ?
                        ProcedusTheme.primary.opacity(0.1) : Color.clear
                    )
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
    }
}

// MARK: - Simple Weekly Hours View (Extracted)

struct SimpleWeeklyHoursView: View {
    let userEntries: [DutyHoursEntry]
    let userId: UUID?
    let programId: UUID?

    @Environment(\.modelContext) private var modelContext

    @State private var weeks: [String] = []
    @State private var hoursInput: [String: String] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(ProcedusTheme.primary)

                    Text("Duty Hours")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Track your weekly work hours")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 24)

                // Weekly entries
                VStack(spacing: 12) {
                    ForEach(weeks, id: \.self) { weekBucket in
                        WeekHoursRow(
                            weekBucket: weekBucket,
                            hours: binding(for: weekBucket),
                            existingEntry: userEntries.first { $0.weekBucket == weekBucket }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            generateWeeks()
            loadExistingEntries()
        }
        .onDisappear {
            saveAllEntries()
        }
    }

    private func binding(for weekBucket: String) -> Binding<String> {
        Binding(
            get: { hoursInput[weekBucket] ?? "" },
            set: { hoursInput[weekBucket] = $0 }
        )
    }

    private func generateWeeks() {
        var result: [String] = []
        let calendar = Calendar(identifier: .iso8601)
        var date = Date()

        for _ in 0..<52 {
            let weekBucket = CaseEntry.makeWeekBucket(for: date)
            result.append(weekBucket)
            date = calendar.date(byAdding: .weekOfYear, value: -1, to: date) ?? date
        }

        weeks = result
    }

    private func loadExistingEntries() {
        for entry in userEntries {
            if hoursInput[entry.weekBucket] == nil {
                hoursInput[entry.weekBucket] = String(format: "%.0f", entry.hours)
            }
        }
    }

    private func saveAllEntries() {
        guard let userId = userId else { return }

        for (weekBucket, hoursStr) in hoursInput {
            guard !hoursStr.isEmpty else { continue }
            guard let hours = Double(hoursStr) else { continue }

            if let existing = userEntries.first(where: { $0.weekBucket == weekBucket }) {
                existing.hours = hours
                existing.updatedAt = Date()
            } else {
                let entry = DutyHoursEntry(
                    userId: userId,
                    programId: programId,
                    weekBucket: weekBucket,
                    hours: hours
                )
                modelContext.insert(entry)
            }
        }

        try? modelContext.save()
    }
}

// MARK: - Week Hours Row

struct WeekHoursRow: View {
    let weekBucket: String
    @Binding var hours: String
    let existingEntry: DutyHoursEntry?

    @State private var showingCustomInput = false
    @FocusState private var isInputFocused: Bool

    private var weekLabel: String {
        weekBucket.toWeekTimeframeLabel()
    }

    private var hasValue: Bool {
        !hours.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(weekLabel)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach([40, 60, 80], id: \.self) { value in
                    Button {
                        hours = "\(value)"
                        showingCustomInput = false
                    } label: {
                        Text("\(value)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(width: 56, height: 44)
                            .background(hours == "\(value)" ? ProcedusTheme.primary : Color(UIColor.tertiarySystemFill))
                            .foregroundStyle(hours == "\(value)" ? .white : .primary)
                            .cornerRadius(10)
                    }
                }

                Spacer()

                if showingCustomInput {
                    HStack(spacing: 4) {
                        TextField("Hrs", text: $hours)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 60, height: 44)
                            .background(Color(UIColor.tertiarySystemFill))
                            .cornerRadius(10)
                            .focused($isInputFocused)

                        Button {
                            showingCustomInput = false
                            isInputFocused = false
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(ProcedusTheme.primary)
                        }
                    }
                } else {
                    Button {
                        showingCustomInput = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isInputFocused = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if hasValue && hours != "40" && hours != "60" && hours != "80" {
                                Text(hours)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            } else {
                                Text("Other")
                                    .font(.subheadline)
                            }
                        }
                        .frame(height: 44)
                        .padding(.horizontal, 12)
                        .background(hasValue && hours != "40" && hours != "60" && hours != "80" ? ProcedusTheme.primary : Color(UIColor.tertiarySystemFill))
                        .foregroundStyle(hasValue && hours != "40" && hours != "60" && hours != "80" ? .white : .primary)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    DutyHoursView()
        .environment(AppState())
        .modelContainer(for: [DutyHoursEntry.self, DutyHoursShift.self, Program.self], inMemory: true)
}
