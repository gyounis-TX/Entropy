// AnalyticsView.swift
// Procedus - Unified
// Analytics dashboard with category case summaries (counts CASES not procedures)
// NOTE: ProcedusAnalyticsRange is defined in Enums.swift

import SwiftUI
import SwiftData
import Charts

// MARK: - Category Presets for Quick Filtering

enum CategoryPreset: String, CaseIterable, Identifiable {
    case all = "All Procedures"
    case pci = "PCI (Coronary)"
    case diagnostic = "Diagnostic"
    case peripheral = "Peripheral"
    case venous = "Venous"
    case structural = "Structural"
    case ep = "EP"

    var id: String { rawValue }

    var categories: [ProcedureCategory] {
        switch self {
        case .all: return []  // Empty means all
        case .pci: return [.coronaryIntervention]
        case .diagnostic: return [.cardiacDiagnostic]
        case .peripheral: return [.peripheralArterial]
        case .venous: return [.venousPE]
        case .structural: return [.structuralValve]
        case .ep: return [.ep, .epDiagnostic, .ablation, .implants]
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .pci: return "heart.fill"
        case .diagnostic: return "waveform.path.ecg"
        case .peripheral: return "figure.walk"
        case .venous: return "drop.fill"
        case .structural: return "bolt.heart.fill"
        case .ep: return "bolt.fill"
        }
    }
}

// MARK: - Analytics View

struct AnalyticsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query private var allCases: [CaseEntry]
    @Query(filter: #Predicate<CustomProcedure> { !$0.isArchived }) private var customProcedures: [CustomProcedure]
    @Query(filter: #Predicate<TrainingFacility> { !$0.isArchived }, sort: \TrainingFacility.name) private var facilities: [TrainingFacility]
    @Query(filter: #Predicate<Attending> { !$0.isArchived }) private var attendings: [Attending]
    @Query private var notifications: [Procedus.Notification]

    @State private var selectedRange: ProcedusAnalyticsRange = .allTime
    @State private var selectedFacilityId: UUID? = nil // nil = All Facilities
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var showingNotifications = false
    @State private var selectedChartType: AnalyticsChartType = .bar
    @State private var selectedChartGrouping: ChartGrouping = .weeks
    @State private var showChart = true
    @State private var notesSearchText: String = ""
    @State private var showingProcedureFilter = false
    @State private var selectedProcedureIds: Set<String> = []  // Empty = all procedures
    @State private var selectedCategoryPresets: Set<CategoryPreset> = []  // Multiple presets allowed
    @State private var selectedAnalyticsCaseType: CaseType? = nil  // nil = all, for cardiology programs

    // Check if this is a cardiology program that should show the case type filter
    private var shouldShowAnalyticsCaseTypeFilter: Bool {
        appState.shouldShowCaseTypeToggle
    }

    // Cardiac imaging categories for noninvasive filtering
    private var cardiacImagingCategories: [ProcedureCategory] {
        [.echo, .nuclear, .cardiacCT, .cardiacMRI, .vascularUltrasound]
    }

    // Available category presets based on case type selection
    private var availableCategoryPresets: [CategoryPreset] {
        if selectedAnalyticsCaseType == .noninvasive {
            // Only show All for noninvasive (specific categories handled separately)
            return [.all]
        }
        // For invasive or all, show standard presets
        return CategoryPreset.allCases
    }

    private var unreadNotificationCount: Int {
        guard let userId = currentUserId else { return 0 }
        return notifications.filter { $0.userId == userId && !$0.isRead }.count
    }

    /// Get the current user ID - handles both individual and institutional modes
    private var currentUserId: UUID? {
        if appState.isIndividualMode {
            // In individual mode, use the persistent individual user UUID
            if let uuidString = UserDefaults.standard.string(forKey: "individualUserUUID"),
               let uuid = UUID(uuidString: uuidString) {
                return uuid
            }
            return nil
        } else {
            // In institutional mode, use current user or selected fellow
            return appState.selectedFellowId ?? appState.currentUser?.id
        }
    }

    private var userCases: [CaseEntry] {
        guard let userId = currentUserId else { return [] }
        return allCases.filter { $0.ownerId == userId }
    }
    
    private var filteredCases: [CaseEntry] {
        let calendar = Calendar.current
        let now = Date()

        var cases: [CaseEntry]

        switch selectedRange {
        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            cases = userCases.filter { $0.createdAt >= startOfWeek }
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            cases = userCases.filter { $0.createdAt >= thirtyDaysAgo }
        case .monthToDate:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            cases = userCases.filter { $0.createdAt >= startOfMonth }
        case .yearToDate:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            cases = userCases.filter { $0.createdAt >= startOfYear }
        case .academicYearToDate:
            // Academic year starts July 1
            let startOfAcademicYear = academicYearStartDate(for: now)
            cases = userCases.filter { $0.createdAt >= startOfAcademicYear }
        case .pgy:
            // PGY shows all cases - grouping is done by academic year in chart
            cases = userCases
        case .allTime:
            cases = userCases
        case .custom:
            cases = userCases.filter { $0.createdAt >= customStartDate && $0.createdAt <= customEndDate }
        }

        // Apply facility filter
        if let facilityId = selectedFacilityId {
            cases = cases.filter { $0.hospitalId == facilityId }
        }

        // CRITICAL PER SPEC: Rejected cases do NOT count toward analytics
        // "Rejected cases do NOT count toward: Procedure totals, Analytics, Reports, Exports"
        cases = cases.filter { $0.attestationStatus != .rejected }

        // Apply case type filter if selected (for cardiology programs)
        if let caseTypeFilter = selectedAnalyticsCaseType {
            cases = cases.filter { caseEntry in
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

        return cases
    }

    /// Cases filtered by selected procedures (for chart)
    private var procedureFilteredCases: [CaseEntry] {
        // If no specific procedures or presets selected, use all cases
        if selectedProcedureIds.isEmpty && selectedCategoryPresets.isEmpty {
            return filteredCases
        }

        // If presets are selected, combine their categories
        if !selectedCategoryPresets.isEmpty {
            // Check if "All" is selected - if so, return all
            if selectedCategoryPresets.contains(.all) {
                return filteredCases
            }

            // Combine categories from all selected presets
            var combinedCategories = Set<ProcedureCategory>()
            for preset in selectedCategoryPresets {
                combinedCategories.formUnion(preset.categories)
            }

            return filteredCases.filter { caseEntry in
                caseEntry.procedureTagIds.contains { tagId in
                    if let category = SpecialtyPackCatalog.findCategory(for: tagId) {
                        return combinedCategories.contains(category)
                    }
                    return false
                }
            }
        }

        // If individual procedures selected, filter by those
        if !selectedProcedureIds.isEmpty {
            return filteredCases.filter { caseEntry in
                !caseEntry.procedureTagIds.filter { selectedProcedureIds.contains($0) }.isEmpty
            }
        }

        return filteredCases
    }

    /// Description of what's being filtered for chart title
    private var procedureFilterDescription: String {
        if !selectedCategoryPresets.isEmpty {
            if selectedCategoryPresets.contains(.all) {
                return "All Procedures"
            }
            let names = selectedCategoryPresets.map { $0.rawValue }.sorted()
            if names.count == 1 {
                return names[0]
            } else if names.count == 2 {
                return "\(names[0]) + \(names[1])"
            } else {
                return "\(names.count) categories"
            }
        }
        if !selectedProcedureIds.isEmpty {
            return "\(selectedProcedureIds.count) procedure\(selectedProcedureIds.count == 1 ? "" : "s")"
        }
        return "All Procedures"
    }

    /// Cases that have notes, filtered by search text
    private var casesWithNotes: [CaseEntry] {
        let casesWithNonEmptyNotes = filteredCases.filter { caseEntry in
            guard let notes = caseEntry.notes, !notes.isEmpty else { return false }
            return true
        }

        // If search text is empty, return all cases with notes
        guard !notesSearchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return casesWithNonEmptyNotes.sorted { $0.createdAt > $1.createdAt }
        }

        // Filter by search text (case-insensitive)
        let searchLower = notesSearchText.lowercased()
        return casesWithNonEmptyNotes.filter { caseEntry in
            caseEntry.notes?.lowercased().contains(searchLower) ?? false
        }.sorted { $0.createdAt > $1.createdAt }
    }

    /// Calculate the start of the academic year (July 1)
    private func academicYearStartDate(for date: Date) -> Date {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        // If we're in January-June, academic year started previous July
        // If we're in July-December, academic year started this July
        let academicYearStartYear = month < 7 ? year - 1 : year

        var components = DateComponents()
        components.year = academicYearStartYear
        components.month = 7
        components.day = 1

        return calendar.date(from: components) ?? date
    }
    
    private var isCustomRangeValid: Bool {
        let days = Calendar.current.dateComponents([.day], from: customStartDate, to: customEndDate).day ?? 0
        return days >= 6
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Case type filter for cardiology programs
                if shouldShowAnalyticsCaseTypeFilter {
                    analyticsCaseTypeSection
                }

                rangeSection
                facilityFilterSection

                if selectedRange == .custom {
                    customRangeSection
                }

                summarySection
                chartSection
                countsSection

                // Hide access site section for noninvasive mode
                if selectedAnalyticsCaseType != .noninvasive {
                    accessSiteSection
                }

                notesSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NotificationBellButton(
                        role: appState.userRole,
                        badgeCount: unreadNotificationCount
                    ) {
                        showingNotifications = true
                    }
                }
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationsSheet(role: appState.userRole, userId: appState.currentUser?.id)
            }
        }
    }
    
    // MARK: - Case Type Filter Section (Cardiology)

    private var analyticsCaseTypeSection: some View {
        Section {
            HStack(spacing: 8) {
                // All cases button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedAnalyticsCaseType = nil
                        selectedCategoryPresets.removeAll()
                    }
                } label: {
                    Text("All")
                        .font(.subheadline)
                        .fontWeight(selectedAnalyticsCaseType == nil ? .semibold : .regular)
                        .foregroundColor(selectedAnalyticsCaseType == nil ? .white : ProcedusTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedAnalyticsCaseType == nil ? ProcedusTheme.primary : Color(UIColor.tertiarySystemFill))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Invasive button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedAnalyticsCaseType = .invasive
                        selectedCategoryPresets.removeAll()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 11))
                        Text("Invasive")
                            .font(.subheadline)
                            .fontWeight(selectedAnalyticsCaseType == .invasive ? .semibold : .regular)
                    }
                    .foregroundColor(selectedAnalyticsCaseType == .invasive ? .white : ProcedusTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedAnalyticsCaseType == .invasive ? Color.red : Color(UIColor.tertiarySystemFill))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Noninvasive button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedAnalyticsCaseType = .noninvasive
                        selectedCategoryPresets.removeAll()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 11))
                        Text("Noninvasive")
                            .font(.subheadline)
                            .fontWeight(selectedAnalyticsCaseType == .noninvasive ? .semibold : .regular)
                    }
                    .foregroundColor(selectedAnalyticsCaseType == .noninvasive ? .white : ProcedusTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedAnalyticsCaseType == .noninvasive ? Color.blue : Color(UIColor.tertiarySystemFill))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        } header: {
            Text("Case Type")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }

    // MARK: - Range Section

    private var rangeSection: some View {
        Section {
            HStack {
                Text("Time Range")
                    .font(.clinicalBody)
                    .foregroundStyle(ProcedusTheme.textPrimary)
                
                Spacer()
                
                Picker("", selection: $selectedRange) {
                    ForEach(ProcedusAnalyticsRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
                .tint(ProcedusTheme.primary)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
            }
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    // MARK: - Facility Filter Section
    
    private var facilityFilterSection: some View {
        Section {
            HStack {
                Text("Hospital")
                    .font(.clinicalBody)
                    .foregroundStyle(ProcedusTheme.textPrimary)
                
                Spacer()
                
                Picker("", selection: $selectedFacilityId) {
                    Text("All Hospitals").tag(nil as UUID?)
                    ForEach(facilities) { facility in
                        Text(facility.name).tag(facility.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
                .tint(ProcedusTheme.primary)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
            }
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    // MARK: - Custom Range Section
    
    private var customRangeSection: some View {
        Section {
            DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                .tint(ProcedusTheme.primary)
            DatePicker("End Date", selection: $customEndDate, displayedComponents: .date)
                .tint(ProcedusTheme.primary)
            
            if !isCustomRangeValid {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(ProcedusTheme.warning)
                    Text("Range must be at least 7 days")
                        .font(.clinicalCaption)
                        .foregroundStyle(ProcedusTheme.warning)
                }
            }
        } header: {
            Text("Custom Range")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        Section {
            HStack {
                Text("Total Cases")
                    .font(.clinicalBody)
                    .foregroundStyle(ProcedusTheme.textPrimary)
                Spacer()
                Text("\(filteredCases.count)")
                    .font(.clinicalHeadline)
                    .foregroundStyle(ProcedusTheme.primary)
            }
        } header: {
            Text("Summary")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        Section {
            // Chart type toggle
            HStack {
                Text("Chart Type")
                    .font(.clinicalBody)
                    .foregroundStyle(ProcedusTheme.textPrimary)

                Spacer()

                Picker("", selection: $selectedChartType) {
                    ForEach(AnalyticsChartType.allCases) { type in
                        Label(type.rawValue, systemImage: type.systemImage).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            // Chart grouping picker (X-axis)
            HStack {
                Text("Group By")
                    .font(.clinicalBody)
                    .foregroundStyle(ProcedusTheme.textPrimary)

                Spacer()

                Picker("", selection: $selectedChartGrouping) {
                    ForEach(ChartGrouping.allCases) { grouping in
                        Text(grouping.rawValue).tag(grouping)
                    }
                }
                .pickerStyle(.menu)
                .tint(ProcedusTheme.primary)
            }

            // Procedure filter
            HStack {
                Text("Procedures")
                    .font(.clinicalBody)
                    .foregroundStyle(ProcedusTheme.textPrimary)

                Spacer()

                Button {
                    showingProcedureFilter = true
                } label: {
                    HStack(spacing: 4) {
                        Text(procedureFilterDescription)
                            .font(.clinicalBody)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(ProcedusTheme.primary)
                }
            }

            // Toggle chart visibility
            Toggle(isOn: $showChart) {
                Text("Show Chart")
                    .font(.clinicalBody)
                    .foregroundStyle(ProcedusTheme.textPrimary)
            }
            .tint(ProcedusTheme.primary)

            if showChart {
                if filteredCases.isEmpty {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.bar.xaxis",
                        description: Text("No cases to display for this time range.")
                    )
                    .frame(height: 200)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        // Chart title with filter info
                        HStack {
                            Text("Cases Over Time")
                                .font(.clinicalFootnote)
                                .foregroundStyle(ProcedusTheme.textSecondary)
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(ProcedusTheme.textTertiary)
                            Text(procedureFilterDescription)
                                .font(.caption2)
                                .foregroundStyle(ProcedusTheme.primary)
                        }

                        caseChart
                            .frame(height: 200)

                        // X-axis label and landscape hint
                        HStack {
                            Text("X-Axis: \(selectedChartGrouping.xAxisLabel)")
                                .font(.caption2)
                                .foregroundStyle(ProcedusTheme.textTertiary)

                            Spacer()

                            Label("Rotate for larger view", systemImage: "rotate.right")
                                .font(.caption2)
                                .foregroundStyle(ProcedusTheme.textTertiary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        } header: {
            Text("Trends")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
        .sheet(isPresented: $showingProcedureFilter) {
            ProcedureFilterSheet(
                selectedCategoryPresets: $selectedCategoryPresets,
                selectedProcedureIds: $selectedProcedureIds,
                enabledPacks: appState.getEnabledPacks()
            )
        }
    }

    @ViewBuilder
    private var caseChart: some View {
        let chartData = chartDataForGrouping

        if chartData.isEmpty {
            ContentUnavailableView(
                "No Data",
                systemImage: "chart.bar.xaxis",
                description: Text("Add cases to see trends.")
            )
            .frame(height: 200)
        } else if selectedChartType == .bar {
            Chart(chartData) { item in
                BarMark(
                    x: .value(selectedChartGrouping.xAxisLabel, item.label),
                    y: .value("Cases", item.count)
                )
                .foregroundStyle(ProcedusTheme.primary.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        } else {
            // Line chart
            Chart(chartData) { item in
                LineMark(
                    x: .value(selectedChartGrouping.xAxisLabel, item.label),
                    y: .value("Cases", item.count)
                )
                .foregroundStyle(ProcedusTheme.primary)
                .interpolationMethod(.linear)
                .symbol(Circle().strokeBorder(lineWidth: 2))
                .symbolSize(50)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
    }

    // MARK: - Chart Data Helpers

    private struct ChartDataPoint: Identifiable {
        let id = UUID()
        let bucket: String      // Sortable key (e.g., "2026-W03", "2026-01", "2026-Q1", "2026")
        let label: String       // Display label (e.g., "Jan 13", "Jan", "Q1", "2026")
        let count: Int
    }

    private var chartDataForGrouping: [ChartDataPoint] {
        switch selectedChartGrouping {
        case .weeks:
            return casesByWeek
        case .months:
            return casesByMonth
        case .quarters:
            return casesByQuarter
        case .years:
            return casesByYear
        }
    }

    private var casesByWeek: [ChartDataPoint] {
        var grouped: [String: Int] = [:]
        for caseEntry in procedureFilteredCases {
            grouped[caseEntry.weekBucket, default: 0] += 1
        }
        return grouped.map { bucket, count in
            ChartDataPoint(bucket: bucket, label: formatWeekLabel(bucket), count: count)
        }
        .sorted { $0.bucket < $1.bucket }
        .suffix(12)
        .map { $0 }
    }

    private var casesByMonth: [ChartDataPoint] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        var grouped: [String: Int] = [:]
        for caseEntry in procedureFilteredCases {
            let year = calendar.component(.year, from: caseEntry.createdAt)
            let month = calendar.component(.month, from: caseEntry.createdAt)
            let bucket = String(format: "%04d-%02d", year, month)
            grouped[bucket, default: 0] += 1
        }
        return grouped.map { bucket, count in
            let parts = bucket.split(separator: "-")
            var label = bucket
            if parts.count == 2, let month = Int(parts[1]) {
                var components = DateComponents()
                components.month = month
                if let date = calendar.date(from: components) {
                    label = formatter.string(from: date)
                }
            }
            return ChartDataPoint(bucket: bucket, label: label, count: count)
        }
        .sorted { $0.bucket < $1.bucket }
        .suffix(12)
        .map { $0 }
    }

    private var casesByQuarter: [ChartDataPoint] {
        let calendar = Calendar.current
        var grouped: [String: Int] = [:]
        for caseEntry in procedureFilteredCases {
            let year = calendar.component(.year, from: caseEntry.createdAt)
            let month = calendar.component(.month, from: caseEntry.createdAt)
            let quarter = (month - 1) / 3 + 1
            let bucket = String(format: "%04d-Q%d", year, quarter)
            grouped[bucket, default: 0] += 1
        }
        return grouped.map { bucket, count in
            let parts = bucket.split(separator: "-")
            let label = parts.count == 2 ? String(parts[1]) : bucket
            return ChartDataPoint(bucket: bucket, label: label, count: count)
        }
        .sorted { $0.bucket < $1.bucket }
        .suffix(8)
        .map { $0 }
    }

    private var casesByYear: [ChartDataPoint] {
        let calendar = Calendar.current
        var grouped: [String: Int] = [:]
        for caseEntry in procedureFilteredCases {
            let year = calendar.component(.year, from: caseEntry.createdAt)
            let bucket = String(year)
            grouped[bucket, default: 0] += 1
        }
        return grouped.map { bucket, count in
            ChartDataPoint(bucket: bucket, label: bucket, count: count)
        }
        .sorted { $0.bucket < $1.bucket }
        .suffix(5)
        .map { $0 }
    }

    /// Format week bucket (e.g., "2026-W03") to readable label (e.g., "Jan 13")
    private func formatWeekLabel(_ bucket: String) -> String {
        let parts = bucket.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              parts[1].hasPrefix("W"),
              let week = Int(parts[1].dropFirst()) else {
            return bucket
        }

        var components = DateComponents()
        components.weekOfYear = week
        components.yearForWeekOfYear = year
        components.weekday = 2  // Monday

        let calendar = Calendar(identifier: .iso8601)
        if let date = calendar.date(from: components) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }

        return bucket
    }

    // MARK: - Counts Section (Case-based counting)

    private var countsSection: some View {
        Section {
            // Get unique categories from user's enabled packs
            let categories = getActiveCategories()
            
            ForEach(categories, id: \.self) { category in
                let counts = procedureCounts(for: category)
                let totalCasesForCategory = totalCases(for: category)
                
                if !counts.isEmpty || totalCasesForCategory > 0 {
                    DisclosureGroup {
                        ForEach(counts, id: \.tagId) { item in
                            HStack {
                                Text(item.title)
                                    .font(.clinicalBody)
                                    .foregroundStyle(ProcedusTheme.textPrimary)
                                
                                CategoryBubble(category: category, size: 16)
                                
                                Spacer()
                                
                                Text("\(item.count)")
                                    .font(.clinicalBody)
                                    .fontWeight(.medium)
                                    .foregroundStyle(ProcedusTheme.textSecondary)
                            }
                        }
                        
                        // Category CASE summary (not procedure count)
                        HStack {
                            Text("Total \(category.rawValue) Cases")
                                .font(.clinicalBody)
                                .fontWeight(.semibold)
                                .foregroundStyle(ProcedusTheme.primary)
                            
                            Spacer()
                            
                            Text("\(totalCasesForCategory)")
                                .font(.clinicalHeadline)
                                .foregroundStyle(ProcedusTheme.primary)
                        }
                        .padding(.top, 4)
                    } label: {
                        HStack(spacing: 8) {
                            Text(category.rawValue)
                                .font(.clinicalBody)
                                .fontWeight(.medium)
                                .foregroundStyle(ProcedusTheme.textPrimary)
                            
                            CategoryBubble(category: category, size: 20)
                        }
                    }
                }
            }
        } header: {
            Text("Procedure Counts")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }

    // MARK: - Access Site Section

    private var accessSiteSection: some View {
        Section {
            let siteCounts = casesByAccessSite
            if siteCounts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.title2)
                            .foregroundStyle(ProcedusTheme.textSecondary)
                        Text("No access site data")
                            .font(.clinicalCaption)
                            .foregroundStyle(ProcedusTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                ForEach(siteCounts, id: \.site) { item in
                    HStack {
                        Text(item.site)
                            .font(.clinicalBody)
                            .foregroundStyle(ProcedusTheme.textPrimary)
                        Spacer()
                        Text("\(item.count)")
                            .font(.clinicalBody)
                            .fontWeight(.medium)
                            .foregroundStyle(ProcedusTheme.primary)
                        Text("cases")
                            .font(.clinicalCaption)
                            .foregroundStyle(ProcedusTheme.textSecondary)
                    }
                }
            }
        } header: {
            Text("Cases by Access Site")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }

    private struct AccessSiteCount {
        let site: String
        let count: Int
    }

    private var casesByAccessSite: [AccessSiteCount] {
        var counts: [String: Int] = [:]

        for caseEntry in filteredCases {
            for siteId in caseEntry.accessSiteIds {
                // Look up the display name for the access site
                let siteName = AccessSite(rawValue: siteId)?.rawValue ?? siteId
                counts[siteName, default: 0] += 1
            }
        }

        return counts.map { AccessSiteCount(site: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        Section {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ProcedusTheme.textSecondary)
                TextField("Search notes...", text: $notesSearchText)
                    .textFieldStyle(.plain)

                if !notesSearchText.isEmpty {
                    Button {
                        notesSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ProcedusTheme.textSecondary)
                    }
                }
            }
            .padding(8)
            .background(Color(UIColor.tertiarySystemGroupedBackground))
            .cornerRadius(8)

            if casesWithNotes.isEmpty {
                if notesSearchText.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "note.text")
                                .font(.title2)
                                .foregroundStyle(ProcedusTheme.textSecondary)
                            Text("No case notes")
                                .font(.clinicalCaption)
                                .foregroundStyle(ProcedusTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                } else {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundStyle(ProcedusTheme.textSecondary)
                            Text("No matching notes")
                                .font(.clinicalCaption)
                                .foregroundStyle(ProcedusTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
            } else {
                ForEach(casesWithNotes) { caseEntry in
                    NoteRowView(caseEntry: caseEntry, attendings: attendings, searchText: notesSearchText)
                }
            }
        } header: {
            HStack {
                Text("Case Notes")
                    .font(.clinicalFootnote)
                    .foregroundStyle(ProcedusTheme.textSecondary)
                Spacer()
                Text("\(casesWithNotes.count) note\(casesWithNotes.count == 1 ? "" : "s")")
                    .font(.clinicalCaption)
                    .foregroundStyle(ProcedusTheme.textSecondary)
            }
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }

    // MARK: - Helpers
    
    private func getActiveCategories() -> [ProcedureCategory] {
        var categories = Set<ProcedureCategory>()
        
        // Get categories from enabled specialty packs
        for packId in appState.enabledSpecialtyPackIds {
            if let pack = SpecialtyPackCatalog.allPacks.first(where: { $0.id == packId }) {
                for categoryData in pack.categories {
                    categories.insert(categoryData.category)
                }
            }
        }
        
        // Add categories from custom procedures
        for procedure in customProcedures {
            categories.insert(procedure.category)
        }
        
        return Array(categories).sorted { $0.rawValue < $1.rawValue }
    }
    
    private struct ProcedureCountItem {
        let tagId: String
        let title: String
        let count: Int
    }
    
    private func procedureCounts(for category: ProcedureCategory) -> [ProcedureCountItem] {
        var counts: [String: Int] = [:]
        
        for caseEntry in filteredCases {
            for tagId in caseEntry.procedureTagIds {
                // Check if this tag belongs to the category
                if let tagCategory = findCategory(for: tagId), tagCategory == category {
                    counts[tagId, default: 0] += 1
                }
            }
        }
        
        return counts.map { tagId, count in
            let title = findTitle(for: tagId)
            return ProcedureCountItem(tagId: tagId, title: title, count: count)
        }.sorted { $0.title < $1.title }
    }
    
    /// Count CASES (not procedures) that have at least one procedure in this category
    private func totalCases(for category: ProcedureCategory) -> Int {
        var caseCount = 0
        
        for caseEntry in filteredCases {
            let hasCategory = caseEntry.procedureTagIds.contains { tagId in
                findCategory(for: tagId) == category
            }
            if hasCategory { caseCount += 1 }
        }
        
        return caseCount
    }
    
    private func findCategory(for tagId: String) -> ProcedureCategory? {
        // Check custom procedures first
        if tagId.hasPrefix("custom:") {
            let uuidString = String(tagId.dropFirst(7))
            if let uuid = UUID(uuidString: uuidString),
               let procedure = customProcedures.first(where: { $0.id == uuid }) {
                return procedure.category
            }
        }
        
        // Check specialty packs
        return SpecialtyPackCatalog.findCategory(for: tagId)
    }
    
    private func findTitle(for tagId: String) -> String {
        // Check custom procedures first
        if tagId.hasPrefix("custom:") {
            let uuidString = String(tagId.dropFirst(7))
            if let uuid = UUID(uuidString: uuidString),
               let procedure = customProcedures.first(where: { $0.id == uuid }) {
                return procedure.title
            }
        }
        
        // Check specialty packs
        if let procedure = SpecialtyPackCatalog.findProcedure(by: tagId) {
            return procedure.title
        }
        
        return tagId
    }
}

// MARK: - Note Row View

private struct NoteRowView: View {
    let caseEntry: CaseEntry
    let attendings: [Attending]
    let searchText: String

    private var attendingName: String {
        guard let id = caseEntry.attendingId else { return "Unknown" }
        return attendings.first { $0.id == id }?.lastName ?? "Unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Format: "date range ... attending ... #procedures"
            HStack(spacing: 4) {
                Text(caseEntry.weekBucket.toWeekTimeframeLabel())
                    .font(.clinicalCaption)
                    .foregroundStyle(ProcedusTheme.textSecondary)

                Text("...")
                    .font(.clinicalCaption)
                    .foregroundStyle(ProcedusTheme.textTertiary)

                Text(attendingName)
                    .font(.clinicalCaption)
                    .foregroundStyle(ProcedusTheme.textSecondary)

                Text("...")
                    .font(.clinicalCaption)
                    .foregroundStyle(ProcedusTheme.textTertiary)

                Text("\(caseEntry.procedureTagIds.count)")
                    .font(.clinicalCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(ProcedusTheme.primary)

                Spacer()
            }

            // Note text with highlighted search term
            if let notes = caseEntry.notes {
                highlightedText(notes)
                    .font(.clinicalBody)
                    .foregroundStyle(ProcedusTheme.textPrimary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func highlightedText(_ text: String) -> some View {
        if searchText.isEmpty {
            Text(text)
        } else {
            let searchLower = searchText.lowercased()
            let textLower = text.lowercased()

            if let range = textLower.range(of: searchLower) {
                let before = String(text[text.startIndex..<range.lowerBound])
                let match = String(text[range])
                let after = String(text[range.upperBound..<text.endIndex])

                Text(before) +
                Text(match)
                    .foregroundStyle(ProcedusTheme.primary)
                    .fontWeight(.semibold) +
                Text(after)
            } else {
                Text(text)
            }
        }
    }
}

// MARK: - Procedure Filter Sheet

struct ProcedureFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategoryPresets: Set<CategoryPreset>
    @Binding var selectedProcedureIds: Set<String>
    let enabledPacks: [SpecialtyPack]

    @State private var expandedCategories: Set<ProcedureCategory> = []

    var body: some View {
        NavigationStack {
            List {
                // Quick Presets Section (multiple selection allowed)
                Section {
                    ForEach(CategoryPreset.allCases) { preset in
                        Button {
                            togglePreset(preset)
                        } label: {
                            HStack {
                                Image(systemName: preset.systemImage)
                                    .foregroundStyle(ProcedusTheme.primary)
                                    .frame(width: 24)
                                Text(preset.rawValue)
                                    .foregroundStyle(ProcedusTheme.textPrimary)
                                Spacer()
                                if selectedCategoryPresets.contains(preset) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(ProcedusTheme.primary)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(ProcedusTheme.textTertiary)
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Quick Presets")
                        Spacer()
                        if !selectedCategoryPresets.isEmpty {
                            Text("\(selectedCategoryPresets.count) selected")
                                .font(.caption)
                                .foregroundStyle(ProcedusTheme.primary)
                        }
                    }
                } footer: {
                    Text("Select one or more presets to combine categories. Or expand categories below for individual procedure selection.")
                }

                // Individual Procedures by Category
                Section {
                    ForEach(getAvailableCategories(), id: \.self) { category in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedCategories.contains(category) },
                                set: { if $0 { expandedCategories.insert(category) } else { expandedCategories.remove(category) } }
                            )
                        ) {
                            // Select All for this category
                            Button {
                                toggleAllInCategory(category)
                            } label: {
                                HStack {
                                    Text(allInCategorySelected(category) ? "Deselect All" : "Select All")
                                        .font(.clinicalCaption)
                                        .foregroundStyle(ProcedusTheme.primary)
                                    Spacer()
                                }
                            }

                            // Individual procedures
                            ForEach(getProcedures(for: category), id: \.id) { procedure in
                                HStack {
                                    Text(procedure.title)
                                        .font(.clinicalBody)
                                        .foregroundStyle(ProcedusTheme.textPrimary)
                                    Spacer()
                                    Image(systemName: selectedProcedureIds.contains(procedure.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedProcedureIds.contains(procedure.id) ? ProcedusTheme.primary : ProcedusTheme.textTertiary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleProcedure(procedure.id)
                                }
                            }
                        } label: {
                            HStack {
                                CategoryBubble(category: category, size: 24)
                                Text(category.rawValue)
                                    .font(.clinicalBody)
                                    .foregroundStyle(ProcedusTheme.textPrimary)
                                Spacer()
                                let count = proceduresSelectedInCategory(category)
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(ProcedusTheme.primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Categories & Procedures")
                }

                // Clear All Button
                Section {
                    Button(role: .destructive) {
                        clearAll()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Clear All Filters", systemImage: "xmark.circle")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Filter Procedures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func togglePreset(_ preset: CategoryPreset) {
        // If selecting "All", clear other presets and individual procedures
        if preset == .all {
            selectedCategoryPresets = [.all]
            selectedProcedureIds.removeAll()
            return
        }

        // Remove "All" if selecting a specific preset
        selectedCategoryPresets.remove(.all)
        selectedProcedureIds.removeAll()  // Clear individual procedures when using presets

        // Toggle the preset
        if selectedCategoryPresets.contains(preset) {
            selectedCategoryPresets.remove(preset)
        } else {
            selectedCategoryPresets.insert(preset)
        }
    }

    private func toggleProcedure(_ id: String) {
        selectedCategoryPresets.removeAll()  // Clear presets when selecting individual procedures
        if selectedProcedureIds.contains(id) {
            selectedProcedureIds.remove(id)
        } else {
            selectedProcedureIds.insert(id)
        }
    }

    private func toggleAllInCategory(_ category: ProcedureCategory) {
        selectedCategoryPresets.removeAll()
        let procedureIds = getProcedures(for: category).map { $0.id }
        if allInCategorySelected(category) {
            procedureIds.forEach { selectedProcedureIds.remove($0) }
        } else {
            procedureIds.forEach { selectedProcedureIds.insert($0) }
        }
    }

    private func allInCategorySelected(_ category: ProcedureCategory) -> Bool {
        let procedureIds = Set(getProcedures(for: category).map { $0.id })
        return !procedureIds.isEmpty && procedureIds.isSubset(of: selectedProcedureIds)
    }

    private func proceduresSelectedInCategory(_ category: ProcedureCategory) -> Int {
        let procedureIds = Set(getProcedures(for: category).map { $0.id })
        return procedureIds.intersection(selectedProcedureIds).count
    }

    private func clearAll() {
        selectedCategoryPresets.removeAll()
        selectedProcedureIds.removeAll()
    }

    private func getAvailableCategories() -> [ProcedureCategory] {
        var categories = Set<ProcedureCategory>()
        for pack in enabledPacks {
            for categoryData in pack.categories {
                categories.insert(categoryData.category)
            }
        }
        return categories.sorted { $0.rawValue < $1.rawValue }
    }

    private func getProcedures(for category: ProcedureCategory) -> [ProcedureTag] {
        var procedures: [ProcedureTag] = []
        for pack in enabledPacks {
            for categoryData in pack.categories where categoryData.category == category {
                procedures.append(contentsOf: categoryData.procedures)
            }
        }
        return procedures.sorted { $0.title < $1.title }
    }
}

// MARK: - Preview

#Preview {
    AnalyticsView()
        .environment(AppState())
        .modelContainer(for: [CaseEntry.self, Attending.self, TrainingFacility.self, CustomProcedure.self], inMemory: true)
}
