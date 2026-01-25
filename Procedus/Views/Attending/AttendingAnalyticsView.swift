// AttendingAnalyticsView.swift
// Procedus - Unified
// Analytics for attendings showing cases they've attested, sortable by trainee

import SwiftUI
import SwiftData

struct AttendingAnalyticsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query private var allCases: [CaseEntry]
    @Query private var users: [User]
    @Query private var attendings: [Attending]

    @AppStorage("selectedAttendingId") private var selectedAttendingIdString = ""

    @State private var selectedRange: ProcedusAnalyticsRange = .allTime
    @State private var selectedTraineeId: UUID? = nil // nil = All Trainees
    @State private var sortBy: AttendingSortOption = .recentFirst

    private var currentAttendingId: UUID? {
        UUID(uuidString: selectedAttendingIdString)
    }

    private var currentAttending: Attending? {
        guard let id = currentAttendingId else { return nil }
        return attendings.first { $0.id == id }
    }

    // Cases attested by this attending
    private var attestedCases: [CaseEntry] {
        guard let attendingId = currentAttendingId else { return [] }
        return allCases.filter { $0.attestorId == attendingId && $0.attestationStatus == .attested }
    }

    // Cases pending attestation by this attending
    private var pendingCases: [CaseEntry] {
        guard let attendingId = currentAttendingId else { return [] }
        return allCases.filter { $0.attestorId == attendingId && $0.attestationStatus == .pending }
    }

    // Cases filtered by time range
    private var filteredCases: [CaseEntry] {
        let calendar = Calendar.current
        let now = Date()

        var cases: [CaseEntry]

        switch selectedRange {
        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            cases = attestedCases.filter { ($0.attestedAt ?? $0.createdAt) >= startOfWeek }
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            cases = attestedCases.filter { ($0.attestedAt ?? $0.createdAt) >= thirtyDaysAgo }
        case .monthToDate:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            cases = attestedCases.filter { ($0.attestedAt ?? $0.createdAt) >= startOfMonth }
        case .yearToDate:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            cases = attestedCases.filter { ($0.attestedAt ?? $0.createdAt) >= startOfYear }
        case .academicYearToDate:
            // Academic year starts July 1
            let startOfAcademicYear = academicYearStartDate(for: now)
            cases = attestedCases.filter { ($0.attestedAt ?? $0.createdAt) >= startOfAcademicYear }
        case .pgy:
            // PGY shows all cases - useful for year-over-year comparison
            cases = attestedCases
        case .allTime:
            cases = attestedCases
        case .custom:
            cases = attestedCases
        }

        // Filter by trainee if selected
        if let traineeId = selectedTraineeId {
            cases = cases.filter { $0.fellowId == traineeId || $0.ownerId == traineeId }
        }

        return cases
    }

    // Get unique trainees from attested cases
    private var uniqueTrainees: [(id: UUID, name: String)] {
        var traineeIds = Set<UUID>()
        for caseEntry in attestedCases {
            if let fellowId = caseEntry.fellowId ?? caseEntry.ownerId {
                traineeIds.insert(fellowId)
            }
        }

        return traineeIds.compactMap { id in
            if let user = users.first(where: { $0.id == id }) {
                return (id: id, name: user.displayName)
            }
            return nil
        }.sorted { $0.name < $1.name }
    }

    // Group cases by trainee
    private var casesByTrainee: [(trainee: String, traineeId: UUID?, cases: [CaseEntry])] {
        var grouped: [UUID: [CaseEntry]] = [:]

        for caseEntry in filteredCases {
            let traineeId = caseEntry.fellowId ?? caseEntry.ownerId ?? UUID()
            grouped[traineeId, default: []].append(caseEntry)
        }

        return grouped.map { (traineeId, cases) in
            let traineeName = users.first { $0.id == traineeId }?.displayName ?? "Unknown Trainee"
            return (trainee: traineeName, traineeId: traineeId, cases: cases)
        }.sorted {
            switch sortBy {
            case .traineeAZ:
                return $0.trainee < $1.trainee
            case .traineeZA:
                return $0.trainee > $1.trainee
            case .mostCases:
                return $0.cases.count > $1.cases.count
            case .recentFirst:
                let date1 = $0.cases.max(by: { ($0.attestedAt ?? $0.createdAt) < ($1.attestedAt ?? $1.createdAt) })?.attestedAt ?? Date.distantPast
                let date2 = $1.cases.max(by: { ($0.attestedAt ?? $0.createdAt) < ($1.attestedAt ?? $1.createdAt) })?.attestedAt ?? Date.distantPast
                return date1 > date2
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                filtersSection
                summarySection
                traineeBreakdownSection
            }
            .listStyle(.insetGrouped)
            .navigationBarHidden(true)
        }
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        Section {
            // Time Range Picker
            HStack {
                Text("Time Range")
                Spacer()
                Picker("", selection: $selectedRange) {
                    ForEach(ProcedusAnalyticsRange.allCases.filter { $0 != .custom }, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            // Trainee Filter
            HStack {
                Text("Trainee")
                Spacer()
                Picker("", selection: $selectedTraineeId) {
                    Text("All Trainees").tag(nil as UUID?)
                    ForEach(uniqueTrainees, id: \.id) { trainee in
                        Text(trainee.name).tag(trainee.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            // Sort By
            HStack {
                Text("Sort By")
                Spacer()
                Picker("", selection: $sortBy) {
                    ForEach(AttendingSortOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        Section {
            HStack {
                Text("Total Cases Attested")
                Spacer()
                Text("\(filteredCases.count)")
                    .font(.headline)
                    .foregroundStyle(Color.green)
            }

            HStack {
                Text("Pending Attestations")
                Spacer()
                Text("\(pendingCases.count)")
                    .font(.headline)
                    .foregroundStyle(Color.orange)
            }

            HStack {
                Text("Unique Trainees")
                Spacer()
                Text("\(Set(filteredCases.compactMap { $0.fellowId ?? $0.ownerId }).count)")
                    .font(.headline)
                    .foregroundStyle(Color.blue)
            }
        } header: {
            Text("Summary")
        }
    }

    // MARK: - Trainee Breakdown Section

    private var traineeBreakdownSection: some View {
        Section {
            if casesByTrainee.isEmpty {
                ContentUnavailableView(
                    "No Attested Cases",
                    systemImage: "checkmark.seal",
                    description: Text("You haven't attested any cases yet.")
                )
            } else {
                ForEach(casesByTrainee, id: \.traineeId) { item in
                    DisclosureGroup {
                        // Cases for this trainee
                        ForEach(item.cases.sorted(by: { ($0.attestedAt ?? $0.createdAt) > ($1.attestedAt ?? $1.createdAt) })) { caseEntry in
                            TraineeAttestationRow(caseEntry: caseEntry)
                        }

                        // Trainee summary
                        HStack {
                            Text("Total for \(item.trainee.split(separator: " ").first.map(String.init) ?? item.trainee)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.green)
                            Spacer()
                            Text("\(item.cases.count) cases")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.green)
                        }
                        .padding(.top, 4)
                    } label: {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.blue)

                            Text(item.trainee)
                                .fontWeight(.medium)

                            Spacer()

                            Text("\(item.cases.count) cases")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("By Trainee")
        }
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
}

// MARK: - Trainee Attestation Row

struct TraineeAttestationRow: View {
    let caseEntry: CaseEntry

    private var categoryBubbles: [ProcedureCategory] {
        var seen = Set<ProcedureCategory>()
        var result: [ProcedureCategory] = []
        for tagId in caseEntry.procedureTagIds {
            if let category = SpecialtyPackCatalog.findCategory(for: tagId) {
                if !seen.contains(category) {
                    seen.insert(category)
                    result.append(category)
                }
            }
        }
        return result
    }

    var body: some View {
        HStack(spacing: 8) {
            // Category bubbles
            HStack(spacing: 4) {
                ForEach(categoryBubbles.prefix(3), id: \.self) { category in
                    CategoryBubble(category: category, size: 20)
                }
            }

            // Week
            Text(caseEntry.weekBucket.toWeekTimeframeLabel())
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // Procedure count
            Text("\(caseEntry.procedureTagIds.count) proc")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(UIColor.tertiarySystemFill))
                .cornerRadius(4)

            // Attestation date
            if let attestedAt = caseEntry.attestedAt {
                Text(attestedAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Sort Option

enum AttendingSortOption: String, CaseIterable {
    case recentFirst = "recent"
    case traineeAZ = "traineeAZ"
    case traineeZA = "traineeZA"
    case mostCases = "mostCases"

    var displayName: String {
        switch self {
        case .recentFirst: return "Recent First"
        case .traineeAZ: return "Trainee A-Z"
        case .traineeZA: return "Trainee Z-A"
        case .mostCases: return "Most Cases"
        }
    }
}

// MARK: - Preview

#Preview {
    AttendingAnalyticsView()
        .environment(AppState())
        .modelContainer(for: [CaseEntry.self, User.self], inMemory: true)
}
