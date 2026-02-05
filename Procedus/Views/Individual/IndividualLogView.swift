// IndividualLogView.swift
// Procedus - Unified
// FIXED: Works in both Individual and Institutional mode

import SwiftUI
import SwiftData

// Attestation status filter for institutional mode
enum LogAttestationFilter: String, CaseIterable {
    case all = "All"
    case attested = "Attested"
    case unattested = "Unattested"
}

struct IndividualLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CaseEntry.createdAt, order: .reverse) private var allCases: [CaseEntry]
    @Query(filter: #Predicate<Attending> { !$0.isArchived }) private var attendings: [Attending]
    @Query(filter: #Predicate<TrainingFacility> { !$0.isArchived }) private var facilities: [TrainingFacility]
    @Query private var customProcedures: [CustomProcedure]

    @State private var caseToEdit: CaseEntry?
    @State private var selectedRange: ProcedusAnalyticsRange = .allTime
    @State private var selectedPGYLevelFilter: Int? = nil  // For PGY year filtering
    @State private var selectedCaseTypeFilter: CaseType? = nil  // nil = all cases
    @State private var caseToDelete: CaseEntry? = nil
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteImportedConfirmation = false
    @State private var showingAttestedCaseAlert = false
    @State private var selectedAttestationFilter: LogAttestationFilter = .all

    // Check if we should show case type filter (cardiology with both imaging and other packs)
    private var shouldShowCaseTypeFilter: Bool {
        appState.shouldShowCaseTypeToggle
    }

    // FIXED: Get user ID that works in both Individual and Institutional mode
    private var currentUserId: UUID {
        // In institutional mode, prioritize selectedFellowId (matches what's used when creating cases)
        if !appState.isIndividualMode {
            if let fellowId = appState.selectedFellowId {
                return fellowId
            }
            // Fallback to currentUser's ID
            if let userId = appState.currentUser?.id {
                return userId
            }
        }
        // In individual mode, use persistent UUID from UserDefaults
        return getOrCreateIndividualUserId()
    }
    
    /// Get or create a persistent user ID for individual mode
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
    
    // FIXED: Use currentUserId instead of appState.currentUser?.id
    private var myCases: [CaseEntry] {
        let userId = currentUserId
        return allCases.filter { $0.ownerId == userId }
    }

    private var casesForSelectedRange: [CaseEntry] {
        let calendar = Calendar.current
        let now = Date()

        var filteredCases: [CaseEntry]

        switch selectedRange {
        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            filteredCases = myCases.filter { $0.procedureDate >= startOfWeek }
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            filteredCases = myCases.filter { $0.procedureDate >= thirtyDaysAgo }
        case .monthToDate:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            filteredCases = myCases.filter { $0.procedureDate >= startOfMonth }
        case .yearToDate:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            filteredCases = myCases.filter { $0.procedureDate >= startOfYear }
        case .academicYearToDate:
            let startOfAcademicYear = academicYearStartDate(for: now)
            filteredCases = myCases.filter { $0.procedureDate >= startOfAcademicYear }
        case .pgy:
            // Filter by specific PGY year if selected
            if let pgyLevel = selectedPGYLevelFilter, let currentPGY = appState.individualPGYLevel {
                let currentAcademicYear = academicYear(for: Date())
                let yearsAgo = currentPGY.rawValue - pgyLevel
                let targetAcademicYear = currentAcademicYear - yearsAgo

                filteredCases = myCases.filter { caseEntry in
                    academicYear(for: caseEntry.procedureDate) == targetAcademicYear
                }
            } else {
                filteredCases = myCases
            }
        case .allTime:
            filteredCases = myCases
        case .custom:
            filteredCases = myCases
        }

        // Apply case type filter if selected
        if let caseTypeFilter = selectedCaseTypeFilter {
            filteredCases = filteredCases.filter { caseEntry in
                // Check stored case type first
                if let storedCaseType = caseEntry.caseType {
                    return storedCaseType == caseTypeFilter
                }
                // For legacy cases without case type, infer from procedures
                let hasCardiacImagingOnly = caseEntry.procedureTagIds.allSatisfy { $0.hasPrefix("ci-") }
                if caseTypeFilter == .noninvasive {
                    return hasCardiacImagingOnly
                } else {
                    return !hasCardiacImagingOnly
                }
            }
        }

        // Apply attestation filter (institutional mode only)
        if !appState.isIndividualMode {
            switch selectedAttestationFilter {
            case .all:
                break  // No filtering
            case .attested:
                filteredCases = filteredCases.filter { $0.attestationStatus == .attested || $0.attestationStatus == .proxyAttested || $0.attestationStatus == .notRequired }
            case .unattested:
                filteredCases = filteredCases.filter { $0.attestationStatus == .pending || $0.attestationStatus == .requested || $0.attestationStatus == .rejected }
            }
        }

        return filteredCases
    }

    private func academicYearStartDate(for date: Date) -> Date {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let academicYearStartYear = month < 7 ? year - 1 : year
        var components = DateComponents()
        components.year = academicYearStartYear
        components.month = 7
        components.day = 1
        return calendar.date(from: components) ?? date
    }

    /// Calculate academic year for a date (July 1 start)
    private func academicYear(for date: Date) -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return month >= 7 ? year : year - 1
    }

    /// Get available PGY levels that have data, based on fellow's current PGY level
    private var availablePGYLevels: [(level: Int, displayName: String)] {
        guard let currentPGY = appState.individualPGYLevel else { return [] }

        let currentAcademicYear = academicYear(for: Date())
        var levelsWithData: Set<Int> = []

        // Check which PGY levels have case data
        for caseEntry in myCases {
            let caseAcademicYear = academicYear(for: caseEntry.createdAt)
            let yearsAgo = currentAcademicYear - caseAcademicYear
            let pgyLevel = currentPGY.rawValue - yearsAgo

            if pgyLevel >= 1 && pgyLevel <= 8 {
                levelsWithData.insert(pgyLevel)
            }
        }

        // Convert to display array, sorted descending (current year first)
        return levelsWithData.sorted(by: >).map { level in
            (level: level, displayName: "PGY-\(level)")
        }
    }

    /// Combined display name for the current time range selection
    private var timeRangeDisplayName: String {
        if let pgyLevel = selectedPGYLevelFilter {
            return "PGY-\(pgyLevel)"
        }
        return selectedRange.rawValue
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Case Type Filter (cardiology with both imaging and other packs)
                if shouldShowCaseTypeFilter {
                    caseTypeFilterSection
                }

                dateRangeSelector

                if casesForSelectedRange.isEmpty {
                    EmptyStateView(icon: "list.clipboard", title: "No Cases", message: "No cases for this time range. Tap + above to add one.")
                } else {
                    List {
                        ForEach(casesForSelectedRange) { caseEntry in
                            IndividualCaseRowView(caseEntry: caseEntry, attendings: Array(attendings), facilities: Array(facilities), customProcedures: Array(customProcedures))
                                .onTapGesture {
                                    if caseEntry.attestationStatus == .attested {
                                        showingAttestedCaseAlert = true
                                    } else {
                                        caseToEdit = caseEntry
                                    }
                                }
                        }
                        .onDelete { offsets in
                            // Show confirmation before deleting
                            if let firstIndex = offsets.first {
                                caseToDelete = casesForSelectedRange[firstIndex]
                                showingDeleteConfirmation = true
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .alert("Delete Case?", isPresented: $showingDeleteConfirmation) {
                        Button("Cancel", role: .cancel) {
                            caseToDelete = nil
                        }
                        Button("Delete", role: .destructive) {
                            if let caseEntry = caseToDelete {
                                modelContext.delete(caseEntry)
                                try? modelContext.save()
                            }
                            caseToDelete = nil
                        }
                    } message: {
                        Text("This action cannot be undone. The case and all its procedures will be permanently removed.")
                    }
                    .alert("Case Cannot Be Modified", isPresented: $showingAttestedCaseAlert) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("Attested cases cannot be edited. Please contact your attending if changes are needed.")
                    }
                }
            }
            .background(ProcedusTheme.background)
            .navigationTitle("Case Log")
            .navigationBarHidden(true) // Hide nav bar - unified top bar is in FellowContentWrapper
            .sheet(item: $caseToEdit) { c in IndividualAddEditCaseView(existingCase: c) }
        }
    }
    
    // MARK: - Case Type Filter Section

    private var caseTypeFilterSection: some View {
        HStack(spacing: 4) {
            // Invasive button
            Button {
                selectedCaseTypeFilter = .invasive
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 10))
                    Text("Invasive")
                        .font(.caption)
                        .fontWeight(selectedCaseTypeFilter == .invasive ? .semibold : .regular)
                }
                .foregroundColor(selectedCaseTypeFilter == .invasive ? .white : ProcedusTheme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selectedCaseTypeFilter == .invasive ? Color.red : Color(UIColor.tertiarySystemFill))
                .cornerRadius(6)
            }

            // Noninvasive button
            Button {
                selectedCaseTypeFilter = .noninvasive
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 10))
                    Text("Noninvasive")
                        .font(.caption)
                        .fontWeight(selectedCaseTypeFilter == .noninvasive ? .semibold : .regular)
                }
                .foregroundColor(selectedCaseTypeFilter == .noninvasive ? .white : ProcedusTheme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selectedCaseTypeFilter == .noninvasive ? Color.blue : Color(UIColor.tertiarySystemFill))
                .cornerRadius(6)
            }

            // All cases button
            Button {
                selectedCaseTypeFilter = nil
            } label: {
                Text("All")
                    .font(.caption)
                    .fontWeight(selectedCaseTypeFilter == nil ? .semibold : .regular)
                    .foregroundColor(selectedCaseTypeFilter == nil ? .white : ProcedusTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedCaseTypeFilter == nil ? ProcedusTheme.primary : Color(UIColor.tertiarySystemFill))
                    .cornerRadius(6)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(ProcedusTheme.cardBackground)
    }

    private var dateRangeSelector: some View {
        HStack {
            Text("Show:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Menu {
                // Standard time ranges (excluding generic PGY and custom)
                ForEach(ProcedusAnalyticsRange.allCases.filter { $0 != .pgy && $0 != .custom }, id: \.self) { range in
                    Button {
                        selectedPGYLevelFilter = nil
                        selectedRange = range
                    } label: {
                        if selectedPGYLevelFilter == nil && selectedRange == range {
                            Label(range.rawValue, systemImage: "checkmark")
                        } else {
                            Text(range.rawValue)
                        }
                    }
                }

                // Dynamic PGY levels (only if PGY level is set and there's data)
                if !availablePGYLevels.isEmpty {
                    Divider()
                    ForEach(availablePGYLevels, id: \.level) { pgyOption in
                        Button {
                            selectedPGYLevelFilter = pgyOption.level
                            selectedRange = .pgy
                        } label: {
                            if selectedPGYLevelFilter == pgyOption.level {
                                Label(pgyOption.displayName, systemImage: "checkmark")
                            } else {
                                Text(pgyOption.displayName)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(timeRangeDisplayName)
                        .font(.subheadline)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(ProcedusTheme.primary)
            }
            .tint(ProcedusTheme.primary)

            // Attestation filter (institutional mode only)
            if !appState.isIndividualMode {
                Picker("", selection: $selectedAttestationFilter) {
                    ForEach(LogAttestationFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .tint(ProcedusTheme.primary)
            }

            Spacer()

            Text("\(casesForSelectedRange.count) cases")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(UIColor.tertiarySystemFill))
                .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ProcedusTheme.cardBackground)
    }
}

struct IndividualCaseRowView: View {
    let caseEntry: CaseEntry
    let attendings: [Attending]
    let facilities: [TrainingFacility]
    var customProcedures: [CustomProcedure] = []

    @State private var showingProcedurePopover = false

    /// Get unique procedure categories for this case (including custom procedures)
    private var procedureCategories: [ProcedureCategory] {
        var seen = Set<ProcedureCategory>()
        var result: [ProcedureCategory] = []
        for procedureId in caseEntry.procedureTagIds {
            if procedureId.hasPrefix("custom-") {
                let uuidString = String(procedureId.dropFirst(7))
                if let uuid = UUID(uuidString: uuidString),
                   let customProc = customProcedures.first(where: { $0.id == uuid }) {
                    if !seen.contains(customProc.category) {
                        seen.insert(customProc.category)
                        result.append(customProc.category)
                    }
                }
            } else if let category = SpecialtyPackCatalog.findCategory(for: procedureId) {
                if !seen.contains(category) {
                    seen.insert(category)
                    result.append(category)
                }
            }
        }
        return result
    }

    /// Whether any procedure tag IDs don't resolve to a known category
    private var hasUnresolvedProcedures: Bool {
        caseEntry.procedureTagIds.contains { tagId in
            if tagId.hasPrefix("custom-") {
                let uuidString = String(tagId.dropFirst(7))
                guard let uuid = UUID(uuidString: uuidString) else { return true }
                return !customProcedures.contains { $0.id == uuid }
            }
            return SpecialtyPackCatalog.findCategory(for: tagId) == nil
        }
    }

    /// Check if this is a noninvasive case (all procedures from cardiac imaging)
    private var isNoninvasiveCase: Bool {
        // Check caseType if set, otherwise infer from procedure IDs
        if let caseType = caseEntry.caseType {
            return caseType == .noninvasive
        }
        // Fallback: all cardiac imaging procedures start with "ci-"
        return !caseEntry.procedureTagIds.isEmpty && caseEntry.procedureTagIds.allSatisfy { $0.hasPrefix("ci-") }
    }

    /// Get first procedure name for display
    private var firstProcedureName: String {
        guard let firstId = caseEntry.procedureTagIds.first,
              let procedure = SpecialtyPackCatalog.findProcedure(by: firstId) else {
            return "Study"
        }
        return procedure.title
    }

    private var attendingName: String {
        // For noninvasive cases without an attending, show the procedure name instead
        let attendingId = caseEntry.supervisorId ?? caseEntry.attendingId
        if attendingId == nil && isNoninvasiveCase {
            return firstProcedureName
        }
        guard let id = attendingId else { return "Unknown" }
        guard let attending = attendings.first(where: { $0.id == id }) else { return "Unknown" }
        // Use lastName if available, otherwise fall back to name or fullName
        if !attending.lastName.isEmpty {
            return attending.lastName
        }
        return attending.name.isEmpty ? attending.fullName : attending.name
    }

    var body: some View {
        HStack(spacing: 8) {
            // Attestation status icon
            attestationStatusIcon
                .frame(width: 20)

            // Attending name
            Text(attendingName)
                .font(.subheadline)
                .foregroundStyle(caseEntry.attestationStatus == .rejected ? .red : .primary)
                .lineLimit(1)

            // Category bubbles inline (tappable for procedure list)
            HStack(spacing: 4) {
                ForEach(procedureCategories.prefix(3), id: \.self) { category in
                    CategoryBubble(category: category, size: 20)
                }

                if procedureCategories.count > 3 {
                    Text("+\(procedureCategories.count - 3)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if hasUnresolvedProcedures {
                    UnmappedProcedureBubble(size: 20)
                }
            }
            .onTapGesture {
                showingProcedurePopover = true
            }
            .popover(isPresented: $showingProcedurePopover) {
                ProcedureListPopover(
                    procedureTagIds: caseEntry.procedureTagIds,
                    customProcedures: customProcedures
                )
            }

            Spacer()

            // Procedure count
            Text("\(caseEntry.procedureTagIds.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(UIColor.tertiarySystemFill))
                .cornerRadius(4)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var attestationStatusIcon: some View {
        if caseEntry.isImported {
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 18))
                .foregroundColor(.teal)
        } else {
            switch caseEntry.attestationStatus {
            case .pending, .requested:
                Image(systemName: "clock.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
            case .attested:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.green)
            case .proxyAttested:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            case .rejected:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
            case .notRequired:
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
            }
        }
    }
}

struct LogExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let cases: [CaseEntry]
    let attendings: [Attending]
    let facilities: [TrainingFacility]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Procedure Counts") {
                    Button { exportCountsCSV() } label: { Label("CSV", systemImage: "doc.text") }
                    Button { exportCountsExcel() } label: { Label("Excel", systemImage: "tablecells") }
                    Button { exportCountsPDF() } label: { Label("PDF", systemImage: "doc.richtext") }
                }
                Section("Procedure Log") {
                    Button { exportLogCSV() } label: { Label("CSV", systemImage: "doc.text") }
                    Button { exportLogExcel() } label: { Label("Excel", systemImage: "tablecells") }
                    Button { exportLogPDF() } label: { Label("PDF", systemImage: "doc.richtext") }
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
    
    private func buildRows() -> [ExportService.CaseExportRow] {
        let df = DateFormatter(); df.dateStyle = .short
        
        // CRITICAL PER SPEC: Rejected and archived cases do NOT appear in exports
        // "Rejected cases do NOT count toward: Procedure totals, Analytics, Reports, Exports"
        let exportableCases = cases.filter { $0.attestationStatus != .rejected && !$0.isArchived }
        
        return exportableCases.map { c in
            ExportService.CaseExportRow(
                // NOTE: In institutional mode, use user.displayName which returns lastName only
                // For individual mode, "User" is acceptable
                fellowName: "User",
                attendingName: attendings.first { $0.id == c.supervisorId }?.name ?? "?",
                facilityName: facilities.first { $0.id == c.hospitalId }?.name ?? "N/A",
                weekBucket: c.weekBucket.toWeekTimeframeLabel(),
                procedures: c.procedureTagIds.compactMap { SpecialtyPackCatalog.findProcedure(by: $0)?.title }.joined(separator: "; "),
                procedureCount: c.procedureTagIds.count,
                accessSites: c.accessSiteIds.joined(separator: "; "),
                complications: c.complicationIds.joined(separator: "; "),
                outcome: c.outcome.rawValue,
                attestationStatus: c.attestationStatus.displayName,
                attestedDate: c.attestedAt?.formatted(date: .abbreviated, time: .omitted) ?? "N/A",
                createdDate: df.string(from: c.createdAt),
                procedureDate: df.string(from: c.procedureDate)
            )
        }
    }
    
    private func buildCountRows() -> [ExportService.ProcedureCountRow] {
        var counts: [String: (String, Int)] = [:]
        
        // CRITICAL PER SPEC: Rejected and archived cases do NOT count in procedure totals
        let validCases = cases.filter { $0.attestationStatus != .rejected && !$0.isArchived }
        
        for c in validCases {
            for pid in c.procedureTagIds {
                if let p = SpecialtyPackCatalog.findProcedure(by: pid), let cat = SpecialtyPackCatalog.findCategory(for: pid) {
                    counts[p.title, default: (cat.rawValue, 0)].1 += 1
                }
            }
        }
        return counts.map { ExportService.ProcedureCountRow(category: $0.value.0, procedure: $0.key, count: $0.value.1) }
            .sorted {
                // Sort by category first, then by procedure name within category
                if $0.category != $1.category {
                    return $0.category < $1.category
                }
                return $0.procedure < $1.procedure
            }
    }
    
    // Note: totalCases in exportCountsExcel should exclude rejected and archived
    private var validCaseCount: Int {
        cases.filter { $0.attestationStatus != .rejected && !$0.isArchived }.count
    }
    
    private func exportCountsCSV() { if let url = ExportService.shared.exportProcedureCountsToCSV(rows: buildCountRows(), filename: "counts") { ShareSheetPresenter.present(url: url) } }
    private func exportCountsExcel() { if let url = ExportService.shared.exportProcedureCountsToExcel(rows: buildCountRows(), fellowName: "User", totalCases: validCaseCount, dateRange: "All") { ShareSheetPresenter.present(url: url) } }
    private func exportCountsPDF() { if let url = ExportService.shared.exportProcedureCountsToPDF(rows: buildCountRows(), fellowName: "User", dateRange: "All") { ShareSheetPresenter.present(url: url) } }
    private func exportLogCSV() { if let url = ExportService.shared.exportToCSV(rows: buildRows(), filename: "log") { ShareSheetPresenter.present(url: url) } }
    private func exportLogExcel() { if let url = ExportService.shared.exportToExcel(rows: buildRows(), filename: "procedure_log") { ShareSheetPresenter.present(url: url) } }
    private func exportLogPDF() { if let url = ExportService.shared.exportToPDF(rows: buildRows(), fellowName: "User", title: "Procedure Log") { ShareSheetPresenter.present(url: url) } }
}
