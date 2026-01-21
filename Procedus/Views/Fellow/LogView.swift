import SwiftUI
import SwiftData

// MARK: - Week Option

struct WeekOption: Identifiable {
    let id: String
    let bucket: String
    let label: String

    init(bucket: String) {
        self.id = bucket
        self.bucket = bucket
        self.label = bucket.toWeekTimeframeLabel()
    }
}

func generateWeekOptions() -> [WeekOption] {
    let calendar = Calendar.current
    var options: [WeekOption] = []

    // Generate last 12 weeks + current week
    for weekOffset in (-12...0).reversed() {
        if let date = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) {
            let bucket = CaseEntry.makeWeekBucket(for: date)
            if !options.contains(where: { $0.bucket == bucket }) {
                options.append(WeekOption(bucket: bucket))
            }
        }
    }

    return options
}

struct LogView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allCases: [CaseEntry]
    @Query private var attendings: [Attending]
    @Query private var users: [User]
    @Query private var notifications: [Notification]
    @Query private var facilities: [TrainingFacility]
    
    // Get selected fellow ID from settings
    @AppStorage("selectedFellowId") private var selectedFellowIdString = ""
    
    @State private var showingNotifications = false
    @State private var showingExportOptions = false
    @State private var isExporting = false
    
    private var currentFellowId: UUID? {
        UUID(uuidString: selectedFellowIdString)
    }
    
    // Count unread notifications for current fellow
    private var unreadNotificationCount: Int {
        guard let fellowId = currentFellowId else { return 0 }
        return notifications.filter { $0.userId == fellowId && !$0.isRead }.count
    }
    
    // Check if fellow is properly selected
    private var hasFellowSelected: Bool {
        guard let id = currentFellowId else { return false }
        return users.contains { $0.id == id && $0.role == .fellow }
    }
    
    // Get current fellow name for initials
    private var currentFellowName: String {
        guard let id = currentFellowId,
              let user = users.first(where: { $0.id == id }) else {
            return "Fellow"
        }
        return user.displayName
    }
    
    // Filter cases to only show current fellow's cases
    private var myCases: [CaseEntry] {
        guard let fellowId = currentFellowId else { return [] }
        return allCases.filter { $0.fellowId == fellowId }
    }
    
    // Computed sorted version
    private var sortedCases: [CaseEntry] {
        myCases.sorted { $0.createdAt > $1.createdAt }
    }
    
    @State private var selectedWeek: String = ""
    @State private var showingAddCase = false
    @State private var caseToEdit: CaseEntry?
    @State private var weeks: [WeekOption] = []
    @State private var selectedRange: ProcedusAnalyticsRange = .allTime
    @State private var selectedCaseTypeFilter: CaseType? = nil  // nil = all cases

    @Query private var programs: [Program]

    // Check if this is a cardiology program with invasive/noninvasive distinction
    private var currentProgram: Program? {
        programs.first
    }

    private var shouldShowCaseTypeFilter: Bool {
        guard let program = currentProgram else { return false }
        let hasCardiacImaging = program.specialtyPackIds.contains("cardiac-imaging")
        let hasOtherCardiology = program.specialtyPackIds.contains("interventional-cardiology") || program.specialtyPackIds.contains("electrophysiology")
        return hasCardiacImaging && hasOtherCardiology
    }

    private var casesForSelectedWeek: [CaseEntry] {
        myCases.filter { $0.weekBucket == selectedWeek }
    }

    private var casesForSelectedRange: [CaseEntry] {
        let calendar = Calendar.current
        let now = Date()

        var filteredCases: [CaseEntry]

        switch selectedRange {
        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            filteredCases = sortedCases.filter { $0.createdAt >= startOfWeek }
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            filteredCases = sortedCases.filter { $0.createdAt >= thirtyDaysAgo }
        case .monthToDate:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            filteredCases = sortedCases.filter { $0.createdAt >= startOfMonth }
        case .yearToDate:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            filteredCases = sortedCases.filter { $0.createdAt >= startOfYear }
        case .academicYearToDate:
            let startOfAcademicYear = academicYearStartDate(for: now)
            filteredCases = sortedCases.filter { $0.createdAt >= startOfAcademicYear }
        case .pgy:
            // PGY shows all cases - useful for year-over-year comparison
            filteredCases = sortedCases
        case .allTime:
            filteredCases = sortedCases
        case .custom:
            filteredCases = sortedCases
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
                // Warning banner if no fellow selected
                if !hasFellowSelected {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Select your identity in Settings to view and log cases")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.15))
                }
                
                #if DEBUG
                // Debug info bar
                VStack(alignment: .leading, spacing: 4) {
                    Text("DEBUG: Total: \(allCases.count) | Mine: \(myCases.count) | Week: \(casesForSelectedWeek.count)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("Fellow ID: \(selectedFellowIdString.isEmpty ? "NOT SET" : String(selectedFellowIdString.prefix(8)))... | Valid: \(hasFellowSelected ? "✓" : "✗")")
                        .font(.caption2)
                        .foregroundColor(hasFellowSelected ? .green : .red)
                    if !hasFellowSelected && !selectedFellowIdString.isEmpty {
                        Text("⚠️ ID set but no matching User found - select identity in Settings")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                #endif

                // Case Type Filter (cardiology programs with both imaging and other packs)
                if shouldShowCaseTypeFilter {
                    caseTypeFilterSection
                }

                // Date Range Selector
                dateRangeSelector

                // Case List
                if !hasFellowSelected {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.questionmark",
                        title: "No Fellow Selected",
                        message: "Go to Settings and select your identity to view your cases."
                    )
                } else if casesForSelectedRange.isEmpty {
                    EmptyStateView(
                        icon: "list.clipboard",
                        title: "No Cases",
                        message: "You haven't logged any cases for this time range.",
                        actionTitle: "Add Case",
                        action: { showingAddCase = true }
                    )
                } else {
                    caseList
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NotificationBellButton(
                        role: .fellow,
                        badgeCount: unreadNotificationCount
                    ) {
                        showingNotifications = true
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        // Export button
                        Button {
                            showingExportOptions = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16))
                        }
                        .disabled(!hasFellowSelected || myCases.isEmpty)
                        
                        // Add case button
                        Button {
                            showingAddCase = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .disabled(!hasFellowSelected)
                    }
                }
            }
            .sheet(isPresented: $showingAddCase) {
                AddEditCaseView(weekBucket: selectedWeek)
            }
            .sheet(item: $caseToEdit) { caseEntry in
                AddEditCaseView(existingCase: caseEntry)
            }
            .sheet(isPresented: $showingNotifications) {
                FellowNotificationsSheet(fellowId: currentFellowId)
            }
            .sheet(isPresented: $showingExportOptions) {
                FellowExportSheet(
                    cases: myCases,
                    fellowName: currentFellowName,
                    attendings: attendings,
                    facilities: facilities
                )
            }
            .onAppear {
                weeks = generateWeekOptions()
                if selectedWeek.isEmpty {
                    selectedWeek = appState.currentWeekBucket
                }
            }
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
                .foregroundColor(selectedCaseTypeFilter == .invasive ? .white : Color(UIColor.label))
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
                .foregroundColor(selectedCaseTypeFilter == .noninvasive ? .white : Color(UIColor.label))
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
                    .foregroundColor(selectedCaseTypeFilter == nil ? .white : Color(UIColor.label))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedCaseTypeFilter == nil ? Color(red: 0.05, green: 0.35, blue: 0.65) : Color(UIColor.tertiarySystemFill))
                    .cornerRadius(6)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }

    // MARK: - Date Range Selector

    private var dateRangeSelector: some View {
        HStack {
            Text("Show:")
                .font(.subheadline)
                .foregroundColor(Color(UIColor.secondaryLabel))

            Picker("", selection: $selectedRange) {
                ForEach(ProcedusAnalyticsRange.allCases.filter { $0 != .custom }, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.menu)
            .tint(Color(red: 0.05, green: 0.35, blue: 0.65))

            Spacer()

            Text("\(casesForSelectedRange.count) cases")
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(UIColor.tertiarySystemFill))
                .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }

    // MARK: - Week Selector (Legacy - keeping for reference)

    private var weekSelector: some View {
        HStack {
            Button {
                navigateToPreviousWeek()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))
            }

            Spacer()

            Menu {
                ForEach(weeks) { week in
                    Button {
                        selectedWeek = week.bucket
                    } label: {
                        Text(week.label)
                            .font(.subheadline)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedWeek.toWeekTimeframeLabel())
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.label))

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
            
            Spacer()
            
            Button {
                navigateToNextWeek()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(canNavigateToNextWeek ? Color(red: 0.05, green: 0.35, blue: 0.65) : Color(UIColor.tertiaryLabel))
            }
            .disabled(!canNavigateToNextWeek)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    private var canNavigateToNextWeek: Bool {
        guard let currentIndex = weeks.firstIndex(where: { $0.bucket == selectedWeek }) else {
            return false
        }
        return currentIndex > 0
    }
    
    private func navigateToPreviousWeek() {
        guard let currentIndex = weeks.firstIndex(where: { $0.bucket == selectedWeek }),
              currentIndex < weeks.count - 1 else { return }
        selectedWeek = weeks[currentIndex + 1].bucket
    }
    
    private func navigateToNextWeek() {
        guard let currentIndex = weeks.firstIndex(where: { $0.bucket == selectedWeek }),
              currentIndex > 0 else { return }
        selectedWeek = weeks[currentIndex - 1].bucket
    }
    
    // MARK: - Case List
    
    private var caseList: some View {
        List {
            ForEach(casesForSelectedRange) { caseEntry in
                CaseRowView(caseEntry: caseEntry, attendings: attendings)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        caseToEdit = caseEntry
                    }
                    .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
            }
            .onDelete(perform: deleteCases)
        }
        .listStyle(.insetGrouped)
    }

    private func deleteCases(at offsets: IndexSet) {
        for index in offsets {
            let caseEntry = casesForSelectedRange[index]
            modelContext.delete(caseEntry)
        }
    }
}

// MARK: - Case Row View

struct CaseRowView: View {
    let caseEntry: CaseEntry
    let attendings: [Attending]

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
        if caseEntry.attendingId == nil && isNoninvasiveCase {
            return firstProcedureName
        }
        return attendings.first { $0.id == caseEntry.attendingId }?.lastName ?? "Unknown"
    }
    
    private var categoryBubbles: [ProcedureCategory] {
        var categories: Set<ProcedureCategory> = []
        
        for tagId in caseEntry.procedureTagIds {
            // Look up category for each procedure tag
            for pack in SpecialtyPackCatalog.allPacks {
                for packCategory in pack.categories {
                    if packCategory.procedures.contains(where: { $0.id == tagId }) {
                        categories.insert(packCategory.category)
                        break
                    }
                }
            }
        }
        
        return Array(categories).sorted { $0.rawValue < $1.rawValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Attestation Status Indicator
                if caseEntry.attestationStatus == .attested {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))
                        .font(.system(size: 18))
                } else if caseEntry.attestationStatus == .rejected {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 18))
                } else if caseEntry.attestationStatus == .pending {
                    Image(systemName: "clock.fill")
                        .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.2))
                        .font(.system(size: 18))
                }
                
                // Attending name (with rejection indicator if rejected)
                Text(attendingName)
                    .font(.subheadline)
                    .foregroundColor(caseEntry.attestationStatus == .rejected ? .red : Color(UIColor.label))
                    .lineLimit(1)
                
                #if DEBUG
                if let attendingId = caseEntry.attendingId {
                    Text("(\(String(attendingId.uuidString.prefix(4))))")
                        .font(.caption2)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
                #endif
                
                // Category Bubbles - inline
                ForEach(categoryBubbles.prefix(3), id: \.rawValue) { category in
                    CategoryBubble(category: category, size: 20)
                }
                
                // Show +N if more than 3 categories
                if categoryBubbles.count > 3 {
                    Text("+\(categoryBubbles.count - 3)")
                        .font(.caption2)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
                
                Spacer()
                
                // Procedure count
                Text("\(caseEntry.procedureTagIds.count)")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(UIColor.tertiarySystemFill))
                    .cornerRadius(4)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            
            // Show rejection reason if rejected
            if caseEntry.attestationStatus == .rejected,
               let reason = caseEntry.rejectionReason,
               !reason.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .font(.caption2)
                    Text(reason)
                        .font(.caption)
                        .lineLimit(2)
                }
                .foregroundColor(.red)
                .padding(.leading, 26) // Align with text after status icon
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Fellow Notifications Sheet

struct FellowNotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Notification.createdAt, order: .reverse) private var allNotifications: [Notification]
    
    let fellowId: UUID?
    
    private var myNotifications: [Notification] {
        guard let fellowId = fellowId else { return [] }
        return allNotifications.filter { $0.userId == fellowId }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if myNotifications.isEmpty {
                    Section {
                        Text("No notifications")
                            .font(.subheadline)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                } else {
                    ForEach(myNotifications) { notification in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if !notification.isRead {
                                    Circle()
                                        .fill(Color(red: 0.05, green: 0.35, blue: 0.65))
                                        .frame(width: 8, height: 8)
                                }
                                
                                // Icon based on notification type
                                if notification.notificationType == "approval" {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                } else if notification.notificationType == "rejection" {
                                    Image(systemName: "xmark.seal.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                                
                                Text(notification.title)
                                    .font(.subheadline)
                                    .fontWeight(notification.isRead ? .regular : .semibold)
                            }
                            
                            Text(notification.message)
                                .font(.caption)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                            
                            Text(notification.createdAt, style: .relative)
                                .font(.caption2)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                        .padding(.vertical, 4)
                        .onTapGesture {
                            notification.isRead = true
                        }
                    }
                    .onDelete(perform: deleteNotifications)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.subheadline)
                }
                
                if !myNotifications.isEmpty {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Clear All") {
                            for notification in myNotifications {
                                modelContext.delete(notification)
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private func deleteNotifications(at offsets: IndexSet) {
        let notificationsToDelete = offsets.map { myNotifications[$0] }
        for notification in notificationsToDelete {
            modelContext.delete(notification)
        }
    }
}

// MARK: - Fellow Export Sheet

struct FellowExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let cases: [CaseEntry]
    let fellowName: String
    let attendings: [Attending]
    let facilities: [TrainingFacility]
    
    @State private var exportFormat: ExportFormat = .excel
    @State private var isExporting = false
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case excel = "Excel"
        case acgme = "ACGME Format"
    }
    
    private func attendingName(for id: UUID?) -> String {
        guard let id = id else { return "Unknown" }
        return attendings.first { $0.id == id }?.lastName ?? "Unknown"
    }
    
    private func facilityName(for id: UUID?) -> String {
        guard let id = id else { return "N/A" }
        return facilities.first { $0.id == id }?.name ?? "Unknown"
    }
    
    private func procedureNames(for ids: [String]) -> String {
        ids.compactMap { procId in
            for pack in SpecialtyPackCatalog.allPacks {
                for category in pack.categories {
                    if let proc = category.procedures.first(where: { $0.id == procId }) {
                        return proc.title
                    }
                }
            }
            return procId
        }.joined(separator: "; ")
    }
    
    // Filter out rejected cases
    private var exportableCases: [CaseEntry] {
        cases.filter { $0.attestationStatus != .rejected }
    }
    
    private func buildExportRows() -> [ExportService.CaseExportRow] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        
        return exportableCases.map { caseEntry in
            ExportService.CaseExportRow(
                fellowName: fellowName,
                attendingName: attendingName(for: caseEntry.attendingId),
                facilityName: facilityName(for: caseEntry.facilityId),
                weekBucket: caseEntry.weekBucket.toWeekTimeframeLabel(),
                procedures: procedureNames(for: caseEntry.procedureTagIds),
                procedureCount: caseEntry.procedureTagIds.count,
                accessSites: caseEntry.accessSiteIds.joined(separator: "; "),
                complications: caseEntry.complicationIds.joined(separator: "; "),
                outcome: caseEntry.outcome.rawValue,
                attestationStatus: caseEntry.attestationStatus.rawValue,
                attestedDate: caseEntry.attestedAt.map { dateFormatter.string(from: $0) } ?? "N/A",
                createdDate: dateFormatter.string(from: caseEntry.createdAt)
            )
        }
    }
    
    private func exportCases() {
        isExporting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let rows = buildExportRows()
            var fileURL: URL?
            
            let safeName = fellowName.replacingOccurrences(of: " ", with: "_")
            
            switch exportFormat {
            case .csv:
                fileURL = ExportService.shared.exportToCSV(rows: rows, filename: "\(safeName)_case_log")
            case .excel:
                fileURL = ExportService.shared.exportToExcel(rows: rows, filename: "\(safeName)_case_log")
            case .acgme:
                var procedureCounts: [String: Int] = [:]
                for caseEntry in exportableCases {
                    for procId in caseEntry.procedureTagIds {
                        let procName = procedureNames(for: [procId])
                        procedureCounts[procName, default: 0] += 1
                    }
                }
                fileURL = ExportService.shared.exportACGMEFormat(
                    fellowName: fellowName,
                    rows: rows,
                    procedureCounts: procedureCounts
                )
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
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Export Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    switch exportFormat {
                    case .csv:
                        Text("Comma-separated values. Opens in any spreadsheet app.")
                            .font(.caption2)
                    case .excel:
                        Text("Native Excel format with headers.")
                            .font(.caption2)
                    case .acgme:
                        Text("Formatted for ACGME requirements with procedure summary.")
                            .font(.caption2)
                    }
                }
                
                Section {
                    HStack {
                        Text("Total Cases")
                            .font(.subheadline)
                        Spacer()
                        Text("\(exportableCases.count)")
                            .font(.subheadline.weight(.semibold))
                    }
                    
                    HStack {
                        Text("Total Procedures")
                            .font(.subheadline)
                        Spacer()
                        Text("\(exportableCases.reduce(0) { $0 + $1.procedureTagIds.count })")
                            .font(.subheadline.weight(.semibold))
                    }
                    
                    if cases.count != exportableCases.count {
                        HStack {
                            Text("Excluded (Rejected)")
                                .font(.subheadline)
                            Spacer()
                            Text("\(cases.count - exportableCases.count)")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("Summary")
                        .font(.caption)
                }
                
                Section {
                    Button {
                        exportCases()
                    } label: {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: "square.and.arrow.up.fill")
                                    .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))
                            }
                            Text("Export Case Log")
                                .font(.subheadline)
                                .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))
                        }
                    }
                    .disabled(isExporting || exportableCases.isEmpty)
                }
            }
            .navigationTitle("Export Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.subheadline)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LogView()
        .environment(AppState())
}
