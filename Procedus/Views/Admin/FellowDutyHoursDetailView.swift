// FellowDutyHoursDetailView.swift
// Procedus - Unified
// Detailed duty hours view for a specific fellow (Admin view)

import SwiftUI
import SwiftData

struct FellowDutyHoursDetailView: View {
    let fellow: User
    let shifts: [DutyHoursShift]
    let entries: [DutyHoursEntry]
    let violations: [DutyHoursViolation]

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: DetailTab = .overview
    @State private var complianceSummary: ComplianceSummary?

    private let complianceService = DutyHoursComplianceService.shared

    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case shifts = "Shifts"
        case violations = "Violations"

        var iconName: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .shifts: return "list.clipboard"
            case .violations: return "exclamationmark.shield"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab bar
                tabBar

                // Content
                switch selectedTab {
                case .overview:
                    overviewContent
                case .shifts:
                    shiftsContent
                case .violations:
                    violationsContent
                }
            }
            .navigationTitle(fellow.fullName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // Export this fellow's data
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .onAppear {
                calculateCompliance()
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 18))
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .foregroundStyle(selectedTab == tab ? ProcedusTheme.primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab ?
                        ProcedusTheme.primary.opacity(0.1) : Color.clear
                    )
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Overview Content

    private var overviewContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status card
                statusCard

                // Key metrics
                keyMetricsGrid

                // Weekly breakdown
                weeklyBreakdownSection

                // Recent activity
                recentActivitySection
            }
            .padding(16)
        }
    }

    private var statusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 16, height: 16)

                Text(complianceSummary?.statusText ?? "Calculating...")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(statusColor)

                Spacer()

                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Role")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(fellow.role.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("PGY Level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("PGY-\(fellow.trainingYear ?? 1)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(16)
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        guard let summary = complianceSummary else { return .gray }
        switch summary.statusColor {
        case "red": return .red
        case "yellow": return .orange
        default: return .green
        }
    }

    private var statusIcon: String {
        guard let summary = complianceSummary else { return "hourglass" }
        switch summary.statusColor {
        case "red": return "exclamationmark.shield.fill"
        case "yellow": return "exclamationmark.triangle.fill"
        default: return "checkmark.shield.fill"
        }
    }

    private var keyMetricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            DetailMetricCard(
                title: "Weekly Average",
                value: String(format: "%.1f hrs", complianceSummary?.fourWeekAverageHours ?? 0),
                limit: "80 max",
                isViolation: (complianceSummary?.fourWeekAverageHours ?? 0) > 80
            )

            DetailMetricCard(
                title: "Days Off",
                value: "\(complianceSummary?.daysOffCount ?? 0) days",
                limit: "4 min",
                isViolation: (complianceSummary?.daysOffCount ?? 0) < 4
            )

            DetailMetricCard(
                title: "Longest Shift",
                value: String(format: "%.1f hrs", complianceSummary?.longestShiftHours ?? 0),
                limit: "24 max",
                isViolation: (complianceSummary?.longestShiftHours ?? 0) > 24
            )

            DetailMetricCard(
                title: "Total Shifts",
                value: "\(shifts.count)",
                limit: "4 weeks",
                isViolation: false
            )
        }
    }

    private var weeklyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Hours")
                .font(.headline)
                .foregroundStyle(.secondary)

            if let summary = complianceSummary {
                ForEach(summary.weeklyHoursByWeek.sorted(by: { $0.key > $1.key }).prefix(4), id: \.key) { week, hours in
                    HStack {
                        Text(week.toWeekTimeframeLabel())
                            .font(.subheadline)

                        Spacer()

                        HStack(spacing: 8) {
                            ProgressView(value: min(1, hours / 80))
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(width: 60)
                                .tint(hours > 80 ? .red : .green)

                            Text(String(format: "%.0f hrs", hours))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(hours > 80 ? .red : .primary)
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Shifts")
                .font(.headline)
                .foregroundStyle(.secondary)

            if shifts.isEmpty {
                Text("No shifts logged")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
            } else {
                ForEach(shifts.prefix(5)) { shift in
                    ShiftSummaryRow(shift: shift)
                }
            }
        }
    }

    // MARK: - Shifts Content

    private var shiftsContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                if shifts.isEmpty {
                    emptyShiftsView
                } else {
                    ForEach(shifts) { shift in
                        ShiftDetailRow(shift: shift)
                    }
                }
            }
            .padding(16)
        }
    }

    private var emptyShiftsView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Shifts Logged")
                .font(.headline)

            Text("This fellow has not logged any shifts yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Violations Content

    private var violationsContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Current violations from summary
                if let summary = complianceSummary {
                    if !summary.violations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Active Violations")
                                .font(.headline)
                                .foregroundStyle(.red)

                            ForEach(summary.violations, id: \.self) { violation in
                                ViolationDetailCard(violation: violation, isWarning: false)
                            }
                        }
                    }

                    if !summary.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Warnings")
                                .font(.headline)
                                .foregroundStyle(.orange)

                            ForEach(summary.warnings, id: \.self) { warning in
                                ViolationDetailCard(violation: warning, isWarning: true)
                            }
                        }
                    }

                    if summary.violations.isEmpty && summary.warnings.isEmpty {
                        emptyViolationsView
                    }
                }

                // Historical violations
                if !violations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Historical Violations")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 16)

                        ForEach(violations) { violation in
                            HistoricalViolationRow(violation: violation)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var emptyViolationsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("No Violations")
                .font(.headline)

            Text("This fellow is currently in compliance with all ACGME requirements")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    // MARK: - Helper Methods

    private func calculateCompliance() {
        complianceSummary = complianceService.checkCompliance(
            userId: fellow.id,
            shifts: shifts,
            simpleEntries: entries
        )
    }
}

// MARK: - Detail Metric Card

struct DetailMetricCard: View {
    let title: String
    let value: String
    let limit: String
    let isViolation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(isViolation ? .red : .primary)

            Text(limit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isViolation ? Color.red.opacity(0.1) : Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Shift Summary Row

struct ShiftSummaryRow: View {
    let shift: DutyHoursShift

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(shift.shiftType.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(shift.shiftDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(shift.shiftType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%.1f hrs", shift.effectiveDurationHours))
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Shift Detail Row

struct ShiftDetailRow: View {
    let shift: DutyHoursShift

    private var timeRange: String {
        let start = shift.startTime.formatted(date: .omitted, time: .shortened)
        if let end = shift.endTime {
            let endStr = end.formatted(date: .omitted, time: .shortened)
            return "\(start) - \(endStr)"
        }
        return "\(start) - In Progress"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(shift.shiftType.color)
                    .frame(width: 10, height: 10)

                Text(shift.shiftDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if shift.isActiveShift {
                    Text("ACTIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
                }
            }

            HStack {
                Label(shift.shiftType.displayName, systemImage: shift.shiftType.iconName)
                Text("•")
                Label(shift.location.displayName, systemImage: shift.location.iconName)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Text(timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(String(format: "%.1f hrs", shift.effectiveDurationHours))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            if shift.breakMinutes > 0 {
                Text("Break: \(shift.breakMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Violation Detail Card

struct ViolationDetailCard: View {
    let violation: DutyHoursViolationType
    let isWarning: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "xmark.octagon.fill")
                .font(.title3)
                .foregroundStyle(isWarning ? .orange : .red)

            VStack(alignment: .leading, spacing: 4) {
                Text(violation.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("ACGME Reference: \(violation.acgmeReference)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background((isWarning ? Color.orange : Color.red).opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Historical Violation Row

struct HistoricalViolationRow: View {
    let violation: DutyHoursViolation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: violation.isResolved ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(violation.isResolved ? .green : .red)

            VStack(alignment: .leading, spacing: 4) {
                Text(violation.violationType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Text(violation.detectedAt.formatted(date: .abbreviated, time: .omitted))
                    if violation.isResolved {
                        Text("• Resolved")
                            .foregroundStyle(.green)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(violation.severity.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(severityColor(violation.severity))
                .cornerRadius(4)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }

    private func severityColor(_ severity: ViolationSeverity) -> Color {
        switch severity {
        case .minor: return .yellow
        case .major: return .orange
        case .critical: return .red
        }
    }
}

#Preview {
    FellowDutyHoursDetailView(
        fellow: User(
            email: "fellow@test.com",
            firstName: "John",
            lastName: "Doe",
            role: .fellow,
            programId: UUID(),
            trainingYear: 1
        ),
        shifts: [],
        entries: [],
        violations: []
    )
    .modelContainer(for: [User.self, DutyHoursShift.self, DutyHoursEntry.self, DutyHoursViolation.self], inMemory: true)
}
