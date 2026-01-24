// DutyHoursDashboardView.swift
// Procedus - Unified
// Admin dashboard for monitoring fellow duty hours compliance

import SwiftUI
import SwiftData

struct DutyHoursDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query private var programs: [Program]
    @Query private var users: [User]
    @Query(sort: \DutyHoursShift.shiftDate, order: .reverse) private var allShifts: [DutyHoursShift]
    @Query(sort: \DutyHoursEntry.weekBucket, order: .reverse) private var allEntries: [DutyHoursEntry]
    @Query(sort: \DutyHoursViolation.detectedAt, order: .reverse) private var allViolations: [DutyHoursViolation]

    @State private var selectedFellow: User?
    @State private var filterStatus: ComplianceFilterStatus = .all

    private let complianceService = DutyHoursComplianceService.shared

    private var currentProgram: Program? { programs.first }

    private var fellows: [User] {
        users.filter { $0.role == .fellow }
    }

    enum ComplianceFilterStatus: String, CaseIterable {
        case all = "All"
        case compliant = "Compliant"
        case warning = "Warning"
        case violation = "Violation"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Cards
                    summarySection

                    // Filter
                    filterBar

                    // Fellows List
                    fellowsListSection
                }
                .padding(16)
            }
            .navigationTitle("Duty Hours")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            // Export report
                        } label: {
                            Label("Export Report", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            // Run compliance check
                        } label: {
                            Label("Run Compliance Check", systemImage: "checkmark.shield")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $selectedFellow) { fellow in
                FellowDutyHoursDetailView(
                    fellow: fellow,
                    shifts: shiftsForUser(fellow.id),
                    entries: entriesForUser(fellow.id),
                    violations: violationsForUser(fellow.id)
                )
            }
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SummaryCard(
                    title: "Fellows",
                    value: "\(fellows.count)",
                    icon: "person.3.fill",
                    color: .blue
                )

                SummaryCard(
                    title: "Compliant",
                    value: "\(compliantCount)",
                    icon: "checkmark.shield.fill",
                    color: .green
                )
            }

            HStack(spacing: 12) {
                SummaryCard(
                    title: "Warnings",
                    value: "\(warningCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                )

                SummaryCard(
                    title: "Violations",
                    value: "\(violationCount)",
                    icon: "xmark.shield.fill",
                    color: .red
                )
            }
        }
    }

    private var compliantCount: Int {
        fellows.filter { fellow in
            let summary = getSummary(for: fellow)
            return summary?.isCompliant == true && summary?.warnings.isEmpty == true
        }.count
    }

    private var warningCount: Int {
        fellows.filter { fellow in
            let summary = getSummary(for: fellow)
            return summary?.isCompliant == true && !(summary?.warnings.isEmpty ?? true)
        }.count
    }

    private var violationCount: Int {
        fellows.filter { fellow in
            let summary = getSummary(for: fellow)
            return summary?.isCompliant == false
        }.count
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ComplianceFilterStatus.allCases, id: \.self) { status in
                    FilterChip(
                        title: status.rawValue,
                        isSelected: filterStatus == status
                    ) {
                        filterStatus = status
                    }
                }
            }
        }
    }

    // MARK: - Fellows List

    private var fellowsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fellows")
                .font(.headline)
                .foregroundStyle(.secondary)

            if filteredFellows.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredFellows) { fellow in
                    FellowComplianceRow(
                        fellow: fellow,
                        summary: getSummary(for: fellow)
                    )
                    .onTapGesture {
                        selectedFellow = fellow
                    }
                }
            }
        }
    }

    private var filteredFellows: [User] {
        switch filterStatus {
        case .all:
            return fellows
        case .compliant:
            return fellows.filter { fellow in
                let summary = getSummary(for: fellow)
                return summary?.isCompliant == true && summary?.warnings.isEmpty == true
            }
        case .warning:
            return fellows.filter { fellow in
                let summary = getSummary(for: fellow)
                return summary?.isCompliant == true && !(summary?.warnings.isEmpty ?? true)
            }
        case .violation:
            return fellows.filter { fellow in
                let summary = getSummary(for: fellow)
                return summary?.isCompliant == false
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No Fellows Found")
                .font(.headline)

            Text("No fellows match the selected filter")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }

    // MARK: - Helper Methods

    private func getSummary(for fellow: User) -> ComplianceSummary? {
        return complianceService.checkCompliance(
            userId: fellow.id,
            shifts: shiftsForUser(fellow.id),
            simpleEntries: entriesForUser(fellow.id)
        )
    }

    private func shiftsForUser(_ userId: UUID) -> [DutyHoursShift] {
        allShifts.filter { $0.userId == userId }
    }

    private func entriesForUser(_ userId: UUID) -> [DutyHoursEntry] {
        allEntries.filter { $0.userId == userId }
    }

    private func violationsForUser(_ userId: UUID) -> [DutyHoursViolation] {
        allViolations.filter { $0.userId == userId }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Fellow Compliance Row

struct FellowComplianceRow: View {
    let fellow: User
    let summary: ComplianceSummary?

    private var statusColor: Color {
        guard let summary = summary else { return .gray }
        if !summary.isCompliant { return .red }
        if !summary.warnings.isEmpty { return .orange }
        return .green
    }

    private var statusIcon: String {
        guard let summary = summary else { return "questionmark.circle" }
        if !summary.isCompliant { return "xmark.shield.fill" }
        if !summary.warnings.isEmpty { return "exclamationmark.triangle.fill" }
        return "checkmark.shield.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundStyle(statusColor)

            // Fellow info
            VStack(alignment: .leading, spacing: 4) {
                Text(fellow.fullName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let summary = summary {
                    HStack(spacing: 8) {
                        Text(String(format: "%.0f hrs/wk avg", summary.fourWeekAverageHours))
                        Text("•")
                        Text("\(summary.daysOffCount) days off")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Weekly hours badge
            if let summary = summary {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f", summary.fourWeekAverageHours))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(summary.fourWeekAverageHours > 80 ? .red : .primary)

                    Text("hrs/wk")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    DutyHoursDashboardView()
        .environment(AppState())
        .modelContainer(for: [User.self, DutyHoursShift.self, DutyHoursEntry.self, DutyHoursViolation.self, Program.self], inMemory: true)
}
