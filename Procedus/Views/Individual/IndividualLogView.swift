// IndividualLogView.swift
// Procedus - Unified
// FIXED: Works in both Individual and Institutional mode

import SwiftUI
import SwiftData

struct IndividualLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CaseEntry.createdAt, order: .reverse) private var allCases: [CaseEntry]
    @Query(filter: #Predicate<Attending> { !$0.isArchived }) private var attendings: [Attending]
    @Query(filter: #Predicate<TrainingFacility> { !$0.isArchived }) private var facilities: [TrainingFacility]
    @Query private var notifications: [Procedus.Notification]

    @State private var showingAddCase = false
    @State private var caseToEdit: CaseEntry?
    @State private var showingExportOptions = false
    @State private var showingNotifications = false
    @State private var selectedRange: ProcedusAnalyticsRange = .allTime
    @State private var selectedCaseTypeFilter: CaseType? = nil  // nil = all cases

    // Check if we should show case type filter (cardiology with both imaging and other packs)
    private var shouldShowCaseTypeFilter: Bool {
        appState.shouldShowCaseTypeToggle
    }

    private var unreadNotificationCount: Int {
        let userId = currentUserId
        return notifications.filter { $0.userId == userId && !$0.isRead }.count
    }
    
    // FIXED: Get user ID that works in both Individual and Institutional mode
    private var currentUserId: UUID {
        // In institutional mode, use the currentUser's ID
        if let userId = appState.currentUser?.id {
            return userId
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
            filteredCases = myCases.filter { $0.createdAt >= startOfWeek }
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            filteredCases = myCases.filter { $0.createdAt >= thirtyDaysAgo }
        case .monthToDate:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            filteredCases = myCases.filter { $0.createdAt >= startOfMonth }
        case .yearToDate:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            filteredCases = myCases.filter { $0.createdAt >= startOfYear }
        case .academicYearToDate:
            let startOfAcademicYear = academicYearStartDate(for: now)
            filteredCases = myCases.filter { $0.createdAt >= startOfAcademicYear }
        case .pgy:
            // PGY shows all cases - useful for year-over-year comparison
            filteredCases = myCases
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Case Type Filter (cardiology with both imaging and other packs)
                if shouldShowCaseTypeFilter {
                    caseTypeFilterSection
                }

                dateRangeSelector

                if casesForSelectedRange.isEmpty {
                    EmptyStateView(icon: "list.clipboard", title: "No Cases", message: "No cases for this time range.", actionTitle: "Add Case", action: { showingAddCase = true })
                } else {
                    List {
                        ForEach(casesForSelectedRange) { caseEntry in
                            IndividualCaseRowView(caseEntry: caseEntry, attendings: Array(attendings), facilities: Array(facilities))
                                .onTapGesture { caseToEdit = caseEntry }
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(casesForSelectedRange[i]) }
                            try? modelContext.save()
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(ProcedusTheme.background)
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NotificationBellButton(
                        role: appState.userRole,
                        badgeCount: unreadNotificationCount
                    ) {
                        showingNotifications = true
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button { showingExportOptions = true } label: { Image(systemName: "square.and.arrow.up") }
                            .disabled(myCases.isEmpty)
                        Button { showingAddCase = true } label: { Image(systemName: "plus").fontWeight(.semibold) }
                    }
                }
            }
            .sheet(isPresented: $showingAddCase) { IndividualAddEditCaseView(weekBucket: CaseEntry.makeWeekBucket(for: Date())) }
            .sheet(item: $caseToEdit) { c in IndividualAddEditCaseView(existingCase: c) }
            .sheet(isPresented: $showingExportOptions) { LogExportSheet(cases: myCases, attendings: Array(attendings), facilities: Array(facilities)) }
            .sheet(isPresented: $showingNotifications) { NotificationsSheet(role: appState.userRole, userId: currentUserId) }
        }
    }
    
    // MARK: - Case Type Filter Section

    private var caseTypeFilterSection: some View {
        HStack(spacing: 0) {
            // All cases button
            Button {
                selectedCaseTypeFilter = nil
            } label: {
                Text("All")
                    .font(.subheadline)
                    .fontWeight(selectedCaseTypeFilter == nil ? .semibold : .regular)
                    .foregroundColor(selectedCaseTypeFilter == nil ? .white : ProcedusTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedCaseTypeFilter == nil ? ProcedusTheme.primary : Color.clear)
                    .cornerRadius(8)
            }

            // Invasive button
            Button {
                selectedCaseTypeFilter = .invasive
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 12))
                    Text("Invasive")
                        .font(.subheadline)
                        .fontWeight(selectedCaseTypeFilter == .invasive ? .semibold : .regular)
                }
                .foregroundColor(selectedCaseTypeFilter == .invasive ? .white : ProcedusTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedCaseTypeFilter == .invasive ? Color.red : Color.clear)
                .cornerRadius(8)
            }

            // Noninvasive button
            Button {
                selectedCaseTypeFilter = .noninvasive
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 12))
                    Text("Noninvasive")
                        .font(.subheadline)
                        .fontWeight(selectedCaseTypeFilter == .noninvasive ? .semibold : .regular)
                }
                .foregroundColor(selectedCaseTypeFilter == .noninvasive ? .white : ProcedusTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedCaseTypeFilter == .noninvasive ? Color.blue : Color.clear)
                .cornerRadius(8)
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

            Picker("", selection: $selectedRange) {
                ForEach(ProcedusAnalyticsRange.allCases.filter { $0 != .custom }, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.menu)
            .tint(ProcedusTheme.primary)

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

    /// Get unique procedure categories for this case
    private var procedureCategories: [ProcedureCategory] {
        var seen = Set<ProcedureCategory>()
        var result: [ProcedureCategory] = []
        for procedureId in caseEntry.procedureTagIds {
            if let category = SpecialtyPackCatalog.findCategory(for: procedureId) {
                if !seen.contains(category) {
                    seen.insert(category)
                    result.append(category)
                }
            }
        }
        return result
    }

    private var attendingName: String {
        let attendingId = caseEntry.supervisorId ?? caseEntry.attendingId
        guard let id = attendingId else { return "Unknown" }
        return attendings.first { $0.id == id }?.lastName ?? "Unknown"
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

            // Category bubbles inline
            ForEach(procedureCategories.prefix(3), id: \.self) { category in
                CategoryBubble(category: category, size: 20)
            }

            if procedureCategories.count > 3 {
                Text("+\(procedureCategories.count - 3)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
        
        // CRITICAL PER SPEC: Rejected cases do NOT appear in exports
        // "Rejected cases do NOT count toward: Procedure totals, Analytics, Reports, Exports"
        let exportableCases = cases.filter { $0.attestationStatus != .rejected }
        
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
                createdDate: df.string(from: c.createdAt)
            )
        }
    }
    
    private func buildCountRows() -> [ExportService.ProcedureCountRow] {
        var counts: [String: (String, Int)] = [:]
        
        // CRITICAL PER SPEC: Rejected cases do NOT count in procedure totals
        let validCases = cases.filter { $0.attestationStatus != .rejected }
        
        for c in validCases {
            for pid in c.procedureTagIds {
                if let p = SpecialtyPackCatalog.findProcedure(by: pid), let cat = SpecialtyPackCatalog.findCategory(for: pid) {
                    counts[p.title, default: (cat.rawValue, 0)].1 += 1
                }
            }
        }
        return counts.map { ExportService.ProcedureCountRow(category: $0.value.0, procedure: $0.key, count: $0.value.1) }
            .sorted { $0.count > $1.count }
    }
    
    // Note: totalCases in exportCountsExcel should exclude rejected
    private var validCaseCount: Int {
        cases.filter { $0.attestationStatus != .rejected }.count
    }
    
    private func exportCountsCSV() { if let url = ExportService.shared.exportProcedureCountsToCSV(rows: buildCountRows(), filename: "counts") { ShareSheetPresenter.present(url: url) } }
    private func exportCountsExcel() { if let url = ExportService.shared.exportProcedureCountsToExcel(rows: buildCountRows(), fellowName: "User", totalCases: validCaseCount, dateRange: "All") { ShareSheetPresenter.present(url: url) } }
    private func exportCountsPDF() { if let url = ExportService.shared.exportProcedureCountsToPDF(rows: buildCountRows(), fellowName: "User", dateRange: "All") { ShareSheetPresenter.present(url: url) } }
    private func exportLogCSV() { if let url = ExportService.shared.exportToCSV(rows: buildRows(), filename: "log") { ShareSheetPresenter.present(url: url) } }
    private func exportLogExcel() { if let url = ExportService.shared.exportToExcel(rows: buildRows(), filename: "procedure_log") { ShareSheetPresenter.present(url: url) } }
    private func exportLogPDF() { if let url = ExportService.shared.exportToPDF(rows: buildRows(), fellowName: "User", title: "Procedure Log") { ShareSheetPresenter.present(url: url) } }
}
