// DutyHoursExportSheet.swift
// Procedus - Unified
// Export duty hours data in various formats with ACGME compliance report

import SwiftUI
import SwiftData

struct DutyHoursExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \DutyHoursShift.shiftDate, order: .reverse) private var allShifts: [DutyHoursShift]
    @Query(sort: \DutyHoursEntry.weekBucket, order: .reverse) private var allSimpleEntries: [DutyHoursEntry]
    @Query private var programs: [Program]

    @State private var selectedRange: DutyHoursExportRange = .last4Weeks
    @State private var exportFormat: DutyHoursExportFormat = .pdf
    @State private var includeComplianceReport = true
    @State private var isExporting = false

    private let complianceService = DutyHoursComplianceService.shared

    // MARK: - User Data

    private var userId: UUID {
        if appState.isIndividualMode {
            let key = "individualUserUUID"
            if let uuidString = UserDefaults.standard.string(forKey: key),
               let uuid = UUID(uuidString: uuidString) {
                return uuid
            }
            let newUUID = UUID()
            UserDefaults.standard.set(newUUID.uuidString, forKey: key)
            return newUUID
        }
        return appState.currentUser?.id ?? UUID()
    }

    private var fellowName: String {
        if appState.isIndividualMode {
            return appState.individualDisplayName
        }
        return appState.currentUser?.fullName ?? "Fellow"
    }

    private var programName: String {
        programs.first?.name ?? "Individual Training"
    }

    private var pgyLevel: Int {
        if appState.isIndividualMode {
            return appState.individualPGYLevel?.rawValue ?? 1
        }
        return appState.currentUser?.trainingYear ?? 1
    }

    // MARK: - Filtered Data

    private var userShifts: [DutyHoursShift] {
        allShifts.filter { $0.userId == userId }
    }

    private var userSimpleEntries: [DutyHoursEntry] {
        allSimpleEntries.filter { $0.userId == userId }
    }

    private var filteredShifts: [DutyHoursShift] {
        let (startDate, endDate) = selectedRange.dateRange
        return userShifts.filter { shift in
            shift.shiftDate >= startDate && shift.shiftDate <= endDate
        }
    }

    private var filteredSimpleEntries: [DutyHoursEntry] {
        let (startDate, endDate) = selectedRange.dateRange
        return userSimpleEntries.filter { entry in
            guard let entryDate = entry.weekBucket.toDate() else { return false }
            return entryDate >= startDate && entryDate <= endDate
        }
    }

    // MARK: - Stats

    private var totalShifts: Int {
        filteredShifts.count
    }

    private var totalHours: Double {
        let shiftHours = filteredShifts.reduce(0.0) { $0 + ($1.effectiveHours > 0 ? $1.effectiveHours : $1.effectiveDurationHours) }
        let simpleHours = filteredSimpleEntries.reduce(0.0) { $0 + $1.hours }
        return max(shiftHours, simpleHours)
    }

    private var avgWeeklyHours: Double {
        let weeks = Set(filteredShifts.map { $0.weekBucket } + filteredSimpleEntries.map { $0.weekBucket }).count
        guard weeks > 0 else { return 0 }
        return totalHours / Double(weeks)
    }

    private var complianceSummary: ComplianceSummary {
        complianceService.checkCompliance(
            userId: userId,
            shifts: userShifts,
            simpleEntries: userSimpleEntries,
            endDate: selectedRange.dateRange.1
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Time Period Section
                Section {
                    Picker("Time Period", selection: $selectedRange) {
                        ForEach(DutyHoursExportRange.allCases) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Time Period")
                } footer: {
                    let (start, end) = selectedRange.dateRange
                    Text("\(start.formatted(date: .abbreviated, time: .omitted)) - \(end.formatted(date: .abbreviated, time: .omitted))")
                }

                // Export Format Section
                Section {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(DutyHoursExportFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Export Format")
                } footer: {
                    Text(exportFormat.description)
                        .font(.caption2)
                }

                // Options Section
                if exportFormat == .pdf || exportFormat == .acgme {
                    Section {
                        Toggle("Include Compliance Report", isOn: $includeComplianceReport)
                    } header: {
                        Text("Options")
                    } footer: {
                        Text("Include ACGME compliance metrics and violation summary")
                    }
                }

                // Summary Section
                Section {
                    HStack {
                        Text("Total Shifts")
                            .font(.subheadline)
                        Spacer()
                        Text("\(totalShifts)")
                            .font(.subheadline.weight(.semibold))
                    }

                    HStack {
                        Text("Total Hours")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f", totalHours))
                            .font(.subheadline.weight(.semibold))
                    }

                    HStack {
                        Text("Avg Weekly Hours")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f", avgWeeklyHours))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(avgWeeklyHours > 80 ? .red : .primary)
                    }

                    HStack {
                        Text("Compliance Status")
                            .font(.subheadline)
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(complianceStatusColor)
                                .frame(width: 8, height: 8)
                            Text(complianceSummary.statusText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(complianceStatusColor)
                        }
                    }
                } header: {
                    Text("Summary")
                }

                // Export Button Section
                Section {
                    Button {
                        exportDutyHours()
                    } label: {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: "square.and.arrow.up.fill")
                                    .foregroundColor(ProcedusTheme.primary)
                            }
                            Text("Export Duty Hours")
                                .font(.subheadline)
                                .foregroundColor(ProcedusTheme.primary)
                        }
                    }
                    .disabled(isExporting || (totalShifts == 0 && filteredSimpleEntries.isEmpty))
                }
            }
            .navigationTitle("Export Duty Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.subheadline)
                }
            }
        }
    }

    private var complianceStatusColor: Color {
        switch complianceSummary.statusColor {
        case "red": return .red
        case "yellow": return .orange
        default: return .green
        }
    }

    // MARK: - Export Logic

    private func exportDutyHours() {
        isExporting = true

        DispatchQueue.global(qos: .userInitiated).async {
            var fileURL: URL?
            let (startDate, endDate) = selectedRange.dateRange
            let dateRange = "\(startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))"

            switch exportFormat {
            case .csv:
                fileURL = exportToCSV(dateRange: dateRange)
            case .excel:
                fileURL = exportToExcel(dateRange: dateRange)
            case .pdf:
                fileURL = exportToPDF(dateRange: dateRange)
            case .acgme:
                fileURL = exportToACGME(dateRange: dateRange)
            }

            DispatchQueue.main.async {
                isExporting = false
                if let url = fileURL {
                    ShareSheetPresenter.present(url: url)
                    dismiss()
                }
            }
        }
    }

    private func exportToCSV(dateRange: String) -> URL? {
        // Build rows for comprehensive shifts
        let shiftRows: [ExportService.DutyHoursRow] = filteredShifts.map { shift in
            ExportService.DutyHoursRow(
                weekBucket: shift.weekBucket,
                weekLabel: shift.weekBucket.toWeekTimeframeLabel(),
                hours: shift.effectiveHours > 0 ? shift.effectiveHours : shift.effectiveDurationHours,
                notes: "\(shift.shiftType.displayName) - \(shift.location.displayName)"
            )
        }

        // Build rows for simple entries
        let simpleRows: [ExportService.DutyHoursRow] = filteredSimpleEntries.map { entry in
            ExportService.DutyHoursRow(
                weekBucket: entry.weekBucket,
                weekLabel: entry.weekBucket.toWeekTimeframeLabel(),
                hours: entry.hours,
                notes: "Simple Entry"
            )
        }

        let allRows = (shiftRows + simpleRows).sorted { $0.weekBucket > $1.weekBucket }
        let safeName = fellowName.replacingOccurrences(of: " ", with: "_")
        return ExportService.shared.exportDutyHoursToCSV(rows: allRows, filename: "\(safeName)_duty_hours")
    }

    private func exportToExcel(dateRange: String) -> URL? {
        let shiftRows: [ExportService.DutyHoursRow] = filteredShifts.map { shift in
            ExportService.DutyHoursRow(
                weekBucket: shift.weekBucket,
                weekLabel: shift.weekBucket.toWeekTimeframeLabel(),
                hours: shift.effectiveHours > 0 ? shift.effectiveHours : shift.effectiveDurationHours,
                notes: "\(shift.shiftType.displayName) - \(shift.location.displayName)"
            )
        }

        let simpleRows: [ExportService.DutyHoursRow] = filteredSimpleEntries.map { entry in
            ExportService.DutyHoursRow(
                weekBucket: entry.weekBucket,
                weekLabel: entry.weekBucket.toWeekTimeframeLabel(),
                hours: entry.hours,
                notes: "Simple Entry"
            )
        }

        let allRows = (shiftRows + simpleRows).sorted { $0.weekBucket > $1.weekBucket }
        return ExportService.shared.exportDutyHoursToExcel(rows: allRows, fellowName: fellowName, dateRange: dateRange)
    }

    private func exportToPDF(dateRange: String) -> URL? {
        if includeComplianceReport {
            return exportToACGME(dateRange: dateRange)
        }

        let shiftRows: [ExportService.DutyHoursRow] = filteredShifts.map { shift in
            ExportService.DutyHoursRow(
                weekBucket: shift.weekBucket,
                weekLabel: shift.weekBucket.toWeekTimeframeLabel(),
                hours: shift.effectiveHours > 0 ? shift.effectiveHours : shift.effectiveDurationHours,
                notes: "\(shift.shiftType.displayName) - \(shift.location.displayName)"
            )
        }

        let simpleRows: [ExportService.DutyHoursRow] = filteredSimpleEntries.map { entry in
            ExportService.DutyHoursRow(
                weekBucket: entry.weekBucket,
                weekLabel: entry.weekBucket.toWeekTimeframeLabel(),
                hours: entry.hours,
                notes: "Simple Entry"
            )
        }

        let allRows = (shiftRows + simpleRows).sorted { $0.weekBucket > $1.weekBucket }
        return ExportService.shared.exportDutyHoursToPDF(rows: allRows, fellowName: fellowName, dateRange: dateRange)
    }

    private func exportToACGME(dateRange: String) -> URL? {
        // Get violations
        let violations = fetchViolations()

        let exportData = ExportService.ACGMEDutyHoursExportData(
            fellowName: fellowName,
            pgyLevel: pgyLevel,
            programName: programName,
            periodStart: selectedRange.dateRange.0,
            periodEnd: selectedRange.dateRange.1,
            complianceSummary: complianceSummary,
            shifts: filteredShifts,
            violations: violations
        )

        let safeName = fellowName.replacingOccurrences(of: " ", with: "_")

        switch exportFormat {
        case .csv:
            return ExportService.shared.exportACGMEDutyHoursToCSV(exportData, filename: "\(safeName)_ACGME_hours")
        case .excel:
            return ExportService.shared.exportACGMEDutyHoursToExcel(exportData, filename: "\(safeName)_ACGME_hours")
        case .pdf, .acgme:
            return ExportService.shared.exportACGMEDutyHoursToPDF(exportData, filename: "\(safeName)_ACGME_hours")
        }
    }

    private func fetchViolations() -> [DutyHoursViolation] {
        let descriptor = FetchDescriptor<DutyHoursViolation>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.detectedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Export Range Enum

enum DutyHoursExportRange: String, CaseIterable, Identifiable {
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case last2Weeks = "Last 2 Weeks"
    case last4Weeks = "Last 4 Weeks"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case last3Months = "Last 3 Months"
    case yearToDate = "Year to Date"
    case academicYear = "Academic Year"
    case allTime = "All Time"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var dateRange: (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        let endDate = now

        switch self {
        case .thisWeek:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            return (startOfWeek, endDate)

        case .lastWeek:
            let startOfThisWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek) ?? now
            let endOfLastWeek = calendar.date(byAdding: .day, value: -1, to: startOfThisWeek) ?? now
            return (startOfLastWeek, endOfLastWeek)

        case .last2Weeks:
            let startDate = calendar.date(byAdding: .day, value: -14, to: now) ?? now
            return (startDate, endDate)

        case .last4Weeks:
            let startDate = calendar.date(byAdding: .day, value: -28, to: now) ?? now
            return (startDate, endDate)

        case .thisMonth:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return (startOfMonth, endDate)

        case .lastMonth:
            let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) ?? now
            let endOfLastMonth = calendar.date(byAdding: .day, value: -1, to: startOfThisMonth) ?? now
            return (startOfLastMonth, endOfLastMonth)

        case .last3Months:
            let startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return (startDate, endDate)

        case .yearToDate:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            return (startOfYear, endDate)

        case .academicYear:
            // Academic year starts July 1
            var components = calendar.dateComponents([.year], from: now)
            let currentMonth = calendar.component(.month, from: now)
            if currentMonth < 7 {
                components.year = (components.year ?? 2024) - 1
            }
            components.month = 7
            components.day = 1
            let startOfAcademicYear = calendar.date(from: components) ?? now
            return (startOfAcademicYear, endDate)

        case .allTime:
            let distantPast = calendar.date(byAdding: .year, value: -10, to: now) ?? now
            return (distantPast, endDate)
        }
    }
}

// MARK: - Export Format Enum

enum DutyHoursExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case excel = "Excel"
    case pdf = "PDF"
    case acgme = "ACGME"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var description: String {
        switch self {
        case .csv:
            return "Comma-separated values for spreadsheet apps"
        case .excel:
            return "Native Excel format with headers"
        case .pdf:
            return "Formatted PDF with compliance summary"
        case .acgme:
            return "Full ACGME compliance report with metrics"
        }
    }
}

// MARK: - String Extension for Week Bucket Parsing

extension String {
    func toDate() -> Date? {
        // Parse week bucket format "2024-W03"
        let parts = self.split(separator: "-W")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let week = Int(parts[1]) else {
            return nil
        }

        var components = DateComponents()
        components.yearForWeekOfYear = year
        components.weekOfYear = week
        components.weekday = 1  // Sunday

        return Calendar.current.date(from: components)
    }
}

#Preview {
    DutyHoursExportSheet()
        .environment(AppState())
        .modelContainer(for: [DutyHoursShift.self, DutyHoursEntry.self, DutyHoursViolation.self, Program.self], inMemory: true)
}
