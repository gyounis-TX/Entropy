// ComprehensiveShiftLogView.swift
// Procedus - Unified
// List view of all logged shifts for comprehensive duty hours tracking

import SwiftUI
import SwiftData

struct ComprehensiveShiftLogView: View {
    let shifts: [DutyHoursShift]
    let userId: UUID?

    @Environment(\.modelContext) private var modelContext

    @State private var selectedShift: DutyHoursShift?
    @State private var showingAddShift = false
    @State private var filterType: ShiftFilterType = .all
    @State private var filterPeriod: ShiftFilterPeriod = .thisWeek

    enum ShiftFilterType: String, CaseIterable {
        case all = "All"
        case regular = "Regular"
        case call = "Call"
        case nightFloat = "Night"
    }

    enum ShiftFilterPeriod: String, CaseIterable {
        case thisWeek = "This Week"
        case lastWeek = "Last Week"
        case thisMonth = "This Month"
        case all = "All Time"
    }

    private var filteredShifts: [DutyHoursShift] {
        var result = shifts

        // Filter by type
        switch filterType {
        case .all:
            break
        case .regular:
            result = result.filter { $0.shiftType == .regular }
        case .call:
            result = result.filter { $0.shiftType == .call || $0.shiftType == .atHomeCall }
        case .nightFloat:
            result = result.filter { $0.shiftType == .nightFloat }
        }

        // Filter by period
        let calendar = Calendar.current
        let now = Date()

        switch filterPeriod {
        case .thisWeek:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            result = result.filter { $0.shiftDate >= startOfWeek }
        case .lastWeek:
            let startOfThisWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek) ?? now
            result = result.filter { $0.shiftDate >= startOfLastWeek && $0.shiftDate < startOfThisWeek }
        case .thisMonth:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            result = result.filter { $0.shiftDate >= startOfMonth }
        case .all:
            break
        }

        return result.sorted { $0.shiftDate > $1.shiftDate }
    }

    private var totalHoursInPeriod: Double {
        filteredShifts.reduce(0) { $0 + ($1.effectiveHours > 0 ? $1.effectiveHours : $1.effectiveDurationHours) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filters
            filterBar

            // Summary
            summaryBar

            // Shifts list
            if filteredShifts.isEmpty {
                emptyStateView
            } else {
                shiftsList
            }
        }
        .sheet(item: $selectedShift) { shift in
            AddEditShiftView(userId: userId, programId: shift.programId, editingShift: shift)
        }
        .sheet(isPresented: $showingAddShift) {
            AddEditShiftView(userId: userId, programId: nil, editingShift: nil)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 12) {
            // Period picker
            Picker("Period", selection: $filterPeriod) {
                ForEach(ShiftFilterPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)

            // Type filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ShiftFilterType.allCases, id: \.self) { type in
                        FilterChip(
                            title: type.rawValue,
                            isSelected: filterType == type
                        ) {
                            filterType = type
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(filteredShifts.count) shifts")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(String(format: "%.1f hours total", totalHoursInPeriod))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showingAddShift = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(ProcedusTheme.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Shifts Logged")
                .font(.headline)

            Text("Clock in to start tracking or add a manual entry")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingAddShift = true
            } label: {
                Label("Add Shift", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(ProcedusTheme.primary)
                    .cornerRadius(10)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Shifts List

    private var shiftsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredShifts) { shift in
                    ShiftRow(shift: shift)
                        .onTapGesture {
                            selectedShift = shift
                        }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Shift Row

struct ShiftRow: View {
    let shift: DutyHoursShift

    private var duration: String {
        let hours = shift.effectiveHours > 0 ? shift.effectiveHours : shift.effectiveDurationHours
        return String(format: "%.1f hrs", hours)
    }

    private var timeRange: String {
        let start = shift.startTime.formatted(date: .omitted, time: .shortened)
        if let end = shift.endTime {
            let endStr = end.formatted(date: .omitted, time: .shortened)
            return "\(start) - \(endStr)"
        } else {
            return "\(start) - In Progress"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Type indicator
            Circle()
                .fill(shift.shiftType.color)
                .frame(width: 10, height: 10)

            // Shift info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(shift.shiftDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.medium)

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

                HStack(spacing: 8) {
                    Label(shift.shiftType.displayName, systemImage: shift.shiftType.iconName)
                    Text("•")
                    Label(shift.location.displayName, systemImage: shift.location.iconName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Duration
            VStack(alignment: .trailing, spacing: 2) {
                Text(duration)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(shift.isActiveShift ? .green : .primary)

                if shift.breakMinutes > 0 {
                    Text("-\(shift.breakMinutes)m break")
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

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? ProcedusTheme.primary : Color(UIColor.tertiarySystemFill))
                .cornerRadius(20)
        }
    }
}

#Preview {
    ComprehensiveShiftLogView(shifts: [], userId: UUID())
        .modelContainer(for: [DutyHoursShift.self], inMemory: true)
}
