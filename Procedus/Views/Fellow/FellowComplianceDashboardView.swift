// FellowComplianceDashboardView.swift
// Procedus - Unified
// Personal ACGME compliance dashboard for fellows

import SwiftUI
import SwiftData

struct FellowComplianceDashboardView: View {
    let shifts: [DutyHoursShift]
    let simpleEntries: [DutyHoursEntry]
    let userId: UUID?

    @State private var complianceSummary: ComplianceSummary?

    private let complianceService = DutyHoursComplianceService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overall Status Card
                overallStatusCard

                // Key Metrics
                keyMetricsSection

                // Detailed Compliance Cards
                detailedComplianceSection

                // Violations & Warnings
                if let summary = complianceSummary,
                   !summary.violations.isEmpty || !summary.warnings.isEmpty {
                    violationsSection(summary)
                }

                // Tips Section
                complianceTipsSection
            }
            .padding(16)
        }
        .onAppear {
            calculateCompliance()
        }
    }

    // MARK: - Overall Status Card

    private var overallStatusCard: some View {
        VStack(spacing: 16) {
            // Status indicator
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 16, height: 16)

                Text(complianceSummary?.statusText ?? "Calculating...")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(statusColor)

                Spacer()

                Image(systemName: statusIcon)
                    .font(.title)
                    .foregroundStyle(statusColor)
            }

            // Period info
            if let summary = complianceSummary {
                Text("4-Week Period: \(summary.periodStart.formatted(date: .abbreviated, time: .omitted)) - \(summary.periodEnd.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(statusColor.opacity(0.1))
        .cornerRadius(16)
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

    // MARK: - Key Metrics Section

    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                MetricCard(
                    title: "Weekly Avg",
                    value: String(format: "%.1f", complianceSummary?.fourWeekAverageHours ?? 0),
                    unit: "hrs",
                    limit: "80 max",
                    progress: (complianceSummary?.fourWeekAverageHours ?? 0) / ACGMELimits.maxWeeklyHours,
                    color: weeklyHoursColor
                )

                MetricCard(
                    title: "Days Off",
                    value: "\(complianceSummary?.daysOffCount ?? 0)",
                    unit: "days",
                    limit: "4 min",
                    progress: Double(complianceSummary?.daysOffCount ?? 0) / Double(ACGMELimits.minDaysOffPer4Weeks),
                    color: daysOffColor
                )
            }

            HStack(spacing: 12) {
                MetricCard(
                    title: "Longest Shift",
                    value: String(format: "%.1f", complianceSummary?.longestShiftHours ?? 0),
                    unit: "hrs",
                    limit: "24 max",
                    progress: (complianceSummary?.longestShiftHours ?? 0) / ACGMELimits.maxContinuousDuty,
                    color: longestShiftColor
                )

                MetricCard(
                    title: "Min Rest",
                    value: String(format: "%.1f", complianceSummary?.shortestRestPeriod ?? 0),
                    unit: "hrs",
                    limit: "8 min",
                    progress: min(1, (complianceSummary?.shortestRestPeriod ?? 0) / ACGMELimits.minInterShiftRest),
                    color: restPeriodColor,
                    invertProgress: true
                )
            }
        }
    }

    private var weeklyHoursColor: Color {
        guard let hours = complianceSummary?.fourWeekAverageHours else { return .gray }
        if hours > ACGMELimits.maxWeeklyHours { return .red }
        if hours > ACGMELimits.maxWeeklyHours * 0.95 { return .orange }
        return .green
    }

    private var daysOffColor: Color {
        guard let days = complianceSummary?.daysOffCount else { return .gray }
        if days < ACGMELimits.minDaysOffPer4Weeks { return .red }
        if days == ACGMELimits.minDaysOffPer4Weeks { return .orange }
        return .green
    }

    private var longestShiftColor: Color {
        guard let hours = complianceSummary?.longestShiftHours else { return .gray }
        if hours > ACGMELimits.maxContinuousDuty { return .red }
        if hours > 22 { return .orange }
        return .green
    }

    private var restPeriodColor: Color {
        guard let hours = complianceSummary?.shortestRestPeriod, hours > 0 else { return .gray }
        if hours < ACGMELimits.minInterShiftRest { return .red }
        if hours < ACGMELimits.recommendedInterShiftRest { return .orange }
        return .green
    }

    // MARK: - Detailed Compliance Section

    private var detailedComplianceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACGME Requirements")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ComplianceRow(
                    title: "80-Hour Weekly Limit",
                    subtitle: "4-week rolling average",
                    value: String(format: "%.1f hrs", complianceSummary?.fourWeekAverageHours ?? 0),
                    isCompliant: (complianceSummary?.fourWeekAverageHours ?? 0) <= ACGMELimits.maxWeeklyHours,
                    acgmeRef: "VI.F.1"
                )

                ComplianceRow(
                    title: "24-Hour Continuous Duty",
                    subtitle: "Maximum shift length",
                    value: String(format: "%.1f hrs", complianceSummary?.longestShiftHours ?? 0),
                    isCompliant: (complianceSummary?.longestShiftHours ?? 0) <= ACGMELimits.maxContinuousDuty,
                    acgmeRef: "VI.F.3"
                )

                ComplianceRow(
                    title: "Inter-Shift Rest",
                    subtitle: "Minimum 8 hours (10 recommended)",
                    value: String(format: "%.1f hrs", complianceSummary?.shortestRestPeriod ?? Double.infinity),
                    isCompliant: !(complianceSummary?.interShiftRestViolation ?? false),
                    acgmeRef: "VI.F.4"
                )

                ComplianceRow(
                    title: "Days Off",
                    subtitle: "Minimum 4 days per 4-week period",
                    value: "\(complianceSummary?.daysOffCount ?? 0) days",
                    isCompliant: (complianceSummary?.daysOffCount ?? 0) >= ACGMELimits.minDaysOffPer4Weeks,
                    acgmeRef: "VI.F.5"
                )

                ComplianceRow(
                    title: "Call Frequency",
                    subtitle: "No more than every 3rd night",
                    value: "\(complianceSummary?.callNightsCount ?? 0) nights",
                    isCompliant: !(complianceSummary?.callFrequencyViolation ?? false),
                    acgmeRef: "VI.F.6"
                )

                ComplianceRow(
                    title: "Night Float",
                    subtitle: "Maximum 6 consecutive nights",
                    value: "\(complianceSummary?.maxConsecutiveNightFloat ?? 0) consecutive",
                    isCompliant: !(complianceSummary?.nightFloatViolation ?? false),
                    acgmeRef: "VI.F.7"
                )
            }
        }
    }

    // MARK: - Violations Section

    private func violationsSection(_ summary: ComplianceSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !summary.violations.isEmpty {
                Text("Violations")
                    .font(.headline)
                    .foregroundStyle(.red)

                ForEach(summary.violations, id: \.self) { violation in
                    ViolationCard(violation: violation, isWarning: false)
                }
            }

            if !summary.warnings.isEmpty {
                Text("Warnings")
                    .font(.headline)
                    .foregroundStyle(.orange)

                ForEach(summary.warnings, id: \.self) { warning in
                    ViolationCard(violation: warning, isWarning: true)
                }
            }
        }
    }

    // MARK: - Tips Section

    private var complianceTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tips for Compliance")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                TipRow(icon: "clock.badge.checkmark", text: "Log all shifts promptly to ensure accurate tracking")
                TipRow(icon: "moon.stars", text: "Track overnight call separately from regular shifts")
                TipRow(icon: "cup.and.saucer", text: "Remember to log break time during long shifts")
                TipRow(icon: "calendar.badge.exclamationmark", text: "Plan days off to meet the 4-day minimum")
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Calculate Compliance

    private func calculateCompliance() {
        guard let userId = userId else { return }

        complianceSummary = complianceService.checkCompliance(
            userId: userId,
            shifts: shifts,
            simpleEntries: simpleEntries
        )
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let limit: String
    let progress: Double
    let color: Color
    var invertProgress: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(color)

                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(height: 6)
                        .cornerRadius(3)

                    Rectangle()
                        .fill(color)
                        .frame(width: min(geometry.size.width, geometry.size.width * min(1, max(0, progress))), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)

            Text(limit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Compliance Row

struct ComplianceRow: View {
    let title: String
    let subtitle: String
    let value: String
    let isCompliant: Bool
    let acgmeRef: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Text(subtitle)
                    Text("•")
                    Text("ACGME \(acgmeRef)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isCompliant ? Color.primary : Color.red)

                Image(systemName: isCompliant ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isCompliant ? Color.green : Color.red)
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Violation Card

struct ViolationCard: View {
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

// MARK: - Tip Row

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(ProcedusTheme.primary)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

#Preview {
    FellowComplianceDashboardView(shifts: [], simpleEntries: [], userId: UUID())
        .modelContainer(for: [DutyHoursShift.self, DutyHoursEntry.self], inMemory: true)
}
