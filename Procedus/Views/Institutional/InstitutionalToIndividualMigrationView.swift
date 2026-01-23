// InstitutionalToIndividualMigrationView.swift
// Procedus - Unified
// Migration wizard for transferring institutional data back to individual mode

import SwiftUI
import SwiftData

// MARK: - Migration Wizard

struct InstitutionalToIndividualMigrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \CaseEntry.createdAt, order: .reverse) private var allCases: [CaseEntry]
    @Query private var attendings: [Attending]
    @Query private var facilities: [TrainingFacility]
    @Query private var customProcedures: [CustomProcedure]
    @Query private var users: [User]
    @Query private var programs: [Program]

    // Current fellow ID
    private var currentFellowId: UUID? {
        appState.selectedFellowId ?? appState.currentUser?.id
    }

    // Current fellow
    private var currentFellow: User? {
        guard let fellowId = currentFellowId else { return nil }
        return users.first { $0.id == fellowId }
    }

    // Current program
    private var currentProgram: Program? {
        programs.first
    }

    // Cases belonging to current fellow
    private var myCases: [CaseEntry] {
        guard let fellowId = currentFellowId else { return [] }
        return allCases.filter { $0.ownerId == fellowId || $0.fellowId == fellowId }
    }

    // Attendings used in my cases
    private var usedAttendingIds: Set<UUID> {
        Set(myCases.compactMap { $0.attendingId ?? $0.supervisorId })
    }

    // Facilities used in my cases
    private var usedFacilityIds: Set<UUID> {
        Set(myCases.compactMap { $0.facilityId ?? $0.hospitalId })
    }

    // Attendings that will be copied
    private var attendingsToCopy: [Attending] {
        attendings.filter { usedAttendingIds.contains($0.id) && !$0.isArchived }
    }

    // Facilities that will be copied
    private var facilitiesToCopy: [TrainingFacility] {
        facilities.filter { usedFacilityIds.contains($0.id) && !$0.isArchived }
    }

    // Custom procedures to copy
    private var customProceduresToCopy: [CustomProcedure] {
        guard let fellowId = currentFellowId else { return [] }
        return customProcedures.filter { $0.creatorId == fellowId && !$0.isArchived }
    }

    // Wizard state
    @State private var currentStep: MigrationStep = .welcome
    @State private var isMigrating = false
    @State private var migrationComplete = false
    @State private var migrationError: String?
    @State private var confirmExport = false

    enum MigrationStep: Int, CaseIterable {
        case welcome = 0
        case preview = 1
        case confirm = 2
        case migrating = 3
        case complete = 4
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        stepContent
                    }
                    .padding(24)
                }

                // Navigation buttons
                navigationButtons
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Switch to Individual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if currentStep != .migrating && currentStep != .complete {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { index in
                Capsule()
                    .fill(index <= currentStep.rawValue ? Color.orange : Color(UIColor.systemGray4))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            welcomeStep
        case .preview:
            previewStep
        case .confirm:
            confirmStep
        case .migrating:
            migratingStep
        case .complete:
            completeStep
        }
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .padding(.top, 20)

            Text("Switch to Individual Mode")
                .font(.title.bold())

            Text("Transfer your procedure log from the institutional system to a standalone Individual Mode account.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Current identity card
            if let fellow = currentFellow {
                HStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(fellow.fullName)
                            .font(.headline)
                        Text("Your cases will be transferred")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 16) {
                MigrationInfoRow(icon: "doc.text.fill", title: "Your Cases", description: "\(myCases.count) cases will be transferred")
                MigrationInfoRow(icon: "person.2.fill", title: "Attendings", description: "\(attendingsToCopy.count) attendings will be copied")
                MigrationInfoRow(icon: "building.2.fill", title: "Facilities", description: "\(facilitiesToCopy.count) facilities will be copied")
                MigrationInfoRow(icon: "list.clipboard.fill", title: "Custom Procedures", description: "\(customProceduresToCopy.count) custom procedures")
            }
            .padding(.vertical, 20)

            // Warning
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Important")
                        .font(.subheadline.bold())
                    Text("You will be signed out of the institutional system. Cases pending attestation will be marked as attested in individual mode.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - Preview Step

    private var previewStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Review Data")
                .font(.title2.bold())

            Text("Review what will be transferred to your individual account.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Summary cards
            VStack(spacing: 12) {
                MigrationSummaryCard(
                    icon: "doc.text.fill",
                    title: "Cases",
                    value: "\(myCases.count)",
                    subtitle: "Total cases"
                )

                let attestedCount = myCases.filter { $0.attestationStatus == .attested || $0.attestationStatus == .notRequired }.count
                MigrationSummaryCard(
                    icon: "checkmark.seal.fill",
                    title: "Attested",
                    value: "\(attestedCount)",
                    subtitle: "Already verified"
                )

                let pendingCount = myCases.filter { $0.attestationStatus == .pending }.count
                if pendingCount > 0 {
                    MigrationSummaryCard(
                        icon: "clock.fill",
                        title: "Pending",
                        value: "\(pendingCount)",
                        subtitle: "Will be auto-attested"
                    )
                }

                MigrationSummaryCard(
                    icon: "chart.bar.fill",
                    title: "Total Procedures",
                    value: "\(totalProcedureCount)",
                    subtitle: "Across all cases"
                )
            }

            // What happens to pending cases
            if myCases.contains(where: { $0.attestationStatus == .pending }) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Cases pending attestation will be automatically marked as attested since individual mode doesn't use the attestation workflow.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Confirm Step

    private var confirmStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Confirm Migration")
                .font(.title2.bold())

            Text("Please confirm you want to proceed with the migration.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("You will be signed out of the institutional system", systemImage: "rectangle.portrait.and.arrow.right")
                    Label("Your cases will be transferred to individual mode", systemImage: "doc.on.doc")
                    Label("Pending attestations will be auto-completed", systemImage: "checkmark.circle")
                    Label("You can always migrate back to institutional later", systemImage: "arrow.triangle.merge")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            // Export recommendation
            VStack(spacing: 12) {
                Toggle(isOn: $confirmExport) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export data first")
                                .font(.subheadline.bold())
                            Text("Recommended: Export a backup before migrating")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .toggleStyle(.switch)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Migrating Step

    private var migratingStep: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()

            Text("Migrating Your Data...")
                .font(.title2.bold())

            Text("Please wait while we transfer your cases to individual mode.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Complete Step

    private var completeStep: some View {
        VStack(spacing: 24) {
            if let error = migrationError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)

                Text("Migration Failed")
                    .font(.title.bold())

                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Migration Complete!")
                    .font(.title.bold())

                Text("Your data has been successfully transferred to individual mode. You are now using the app independently.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    Text("Welcome to Individual Mode!")
                        .font(.headline)
                    Text("Tap Done to start using your migrated case log.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep != .welcome && currentStep != .migrating && currentStep != .complete {
                Button("Back") {
                    withAnimation {
                        currentStep = MigrationStep(rawValue: currentStep.rawValue - 1) ?? .welcome
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            switch currentStep {
            case .welcome:
                Button("Continue") {
                    withAnimation { currentStep = .preview }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(myCases.isEmpty)

            case .preview:
                Button("Next") {
                    withAnimation { currentStep = .confirm }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

            case .confirm:
                Button("Start Migration") {
                    startMigration()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

            case .migrating:
                EmptyView()

            case .complete:
                Button("Done") {
                    completeAndDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Helpers

    private var totalProcedureCount: Int {
        myCases.reduce(0) { $0 + $1.procedureTagIds.count }
    }

    // MARK: - Migration Logic

    private func startMigration() {
        withAnimation {
            currentStep = .migrating
        }

        // Perform migration on background thread
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            performMigration()
        }
    }

    private func performMigration() {
        do {
            // 1. Create or get individual user UUID
            let individualUserId = getOrCreateIndividualUserId()

            // 2. Copy attendings that are used in cases
            var attendingIdMapping: [UUID: UUID] = [:] // old ID -> new ID
            for attending in attendingsToCopy {
                // Check if we already have this attending in individual mode
                let existingIndividual = attendings.first {
                    $0.ownerId == individualUserId &&
                    $0.firstName == attending.firstName &&
                    $0.lastName == attending.lastName
                }

                if let existing = existingIndividual {
                    attendingIdMapping[attending.id] = existing.id
                } else {
                    // Create new attending for individual mode
                    let newAttending = Attending(
                        firstName: attending.firstName,
                        lastName: attending.lastName,
                        ownerId: individualUserId,
                        phoneNumber: attending.phoneNumber
                    )
                    modelContext.insert(newAttending)
                    attendingIdMapping[attending.id] = newAttending.id
                }
            }

            // 3. Copy facilities that are used in cases
            var facilityIdMapping: [UUID: UUID] = [:] // old ID -> new ID
            for facility in facilitiesToCopy {
                // Check if we already have this facility in individual mode
                let existingIndividual = facilities.first {
                    $0.ownerId == individualUserId &&
                    $0.name == facility.name
                }

                if let existing = existingIndividual {
                    facilityIdMapping[facility.id] = existing.id
                } else {
                    // Create new facility for individual mode
                    let newFacility = TrainingFacility(
                        name: facility.name,
                        ownerId: individualUserId
                    )
                    newFacility.shortName = facility.shortName
                    modelContext.insert(newFacility)
                    facilityIdMapping[facility.id] = newFacility.id
                }
            }

            // 4. Update all cases to individual mode
            for caseEntry in myCases {
                // Update owner to individual user
                caseEntry.ownerId = individualUserId
                caseEntry.fellowId = nil // Individual mode doesn't use fellowId
                caseEntry.programId = nil // No program in individual mode

                // Remap attending if needed
                if let oldAttendingId = caseEntry.attendingId ?? caseEntry.supervisorId,
                   let newAttendingId = attendingIdMapping[oldAttendingId] {
                    caseEntry.attendingId = newAttendingId
                    caseEntry.supervisorId = newAttendingId
                }

                // Remap facility if needed
                if let oldFacilityId = caseEntry.facilityId ?? caseEntry.hospitalId,
                   let newFacilityId = facilityIdMapping[oldFacilityId] {
                    caseEntry.facilityId = newFacilityId
                    caseEntry.hospitalId = newFacilityId
                }

                // Auto-attest any pending cases (individual mode doesn't use attestation)
                if caseEntry.attestationStatus == .pending {
                    caseEntry.attestationStatus = .attested
                    caseEntry.attestedAt = Date()
                }

                // Ensure all cases have appropriate attestation status for individual mode
                if caseEntry.attestationStatus == .rejected {
                    // Keep rejected as-is but mark as attested since no workflow
                    caseEntry.attestationStatus = .attested
                }

                caseEntry.isMigrated = true
                caseEntry.migratedAt = Date()
                caseEntry.updatedAt = Date()
            }

            // 5. Update custom procedures to individual mode
            for procedure in customProceduresToCopy {
                procedure.creatorId = nil // Individual mode doesn't track creator
                procedure.programId = nil
            }

            // 6. Copy profile information to individual mode settings
            if let fellow = currentFellow {
                appState.individualFirstName = fellow.firstName
                appState.individualLastName = fellow.lastName

                // Copy program specialty if available
                if let specialty = currentProgram?.fellowshipSpecialty {
                    appState.individualFellowshipSpecialty = specialty
                }
            }

            // 7. Save all changes
            try modelContext.save()

            // 8. Update app state to individual mode
            appState.currentUser = nil
            appState.accountMode = .individual
            UserDefaults.standard.removeObject(forKey: "selectedFellowId")
            UserDefaults.standard.removeObject(forKey: "selectedAttendingId")
            UserDefaults.standard.set("individual", forKey: "accountMode")

            #if DEBUG
            // Exit dev mode if active
            appState.devSignOut()
            #endif

            withAnimation {
                migrationComplete = true
                currentStep = .complete
            }

        } catch {
            withAnimation {
                migrationError = error.localizedDescription
                currentStep = .complete
            }
        }
    }

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

    private func completeAndDismiss() {
        dismiss()
    }
}

#Preview {
    InstitutionalToIndividualMigrationView()
        .environment(AppState())
}
