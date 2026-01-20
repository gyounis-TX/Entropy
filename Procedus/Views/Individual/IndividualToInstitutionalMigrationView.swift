// IndividualToInstitutionalMigrationView.swift
// Procedus - Unified
// Migration wizard for transferring individual mode data to institutional mode

import SwiftUI
import SwiftData

// MARK: - Migration Wizard

struct IndividualToInstitutionalMigrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(filter: #Predicate<Attending> { !$0.isArchived }) private var individualAttendings: [Attending]
    @Query(filter: #Predicate<TrainingFacility> { !$0.isArchived }) private var individualFacilities: [TrainingFacility]
    @Query(sort: \CaseEntry.createdAt, order: .reverse) private var allCases: [CaseEntry]
    @Query(filter: #Predicate<CustomProcedure> { !$0.isArchived }) private var customProcedures: [CustomProcedure]
    @Query private var programs: [Program]
    @Query private var institutionalAttendings: [Attending]
    @Query private var institutionalFacilities: [TrainingFacility]
    @Query private var users: [User]

    // Get individual user ID
    private var individualUserId: UUID {
        let key = "individualUserUUID"
        if let uuidString = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }
        return UUID()
    }

    // Cases belonging to individual user
    private var myCases: [CaseEntry] {
        allCases.filter { $0.ownerId == individualUserId }
    }

    // My custom procedures (no creatorId = individual mode)
    private var myCustomProcedures: [CustomProcedure] {
        customProcedures.filter { $0.creatorId == nil && $0.programId == nil }
    }

    // Current program
    private var currentProgram: Program? {
        programs.first
    }

    // Available fellows to select as identity
    private var availableFellows: [User] {
        users.filter { $0.role == .fellow && !$0.isArchived }
    }

    // Institutional attendings (those with program ID)
    private var programAttendings: [Attending] {
        guard let programId = currentProgram?.id else { return [] }
        return institutionalAttendings.filter { $0.programId == programId && !$0.isArchived }
    }

    // Institutional facilities (those with program ID)
    private var programFacilities: [TrainingFacility] {
        guard let programId = currentProgram?.id else { return [] }
        return institutionalFacilities.filter { $0.programId == programId && !$0.isArchived }
    }

    // Wizard state
    @State private var currentStep: MigrationStep = .welcome
    @State private var selectedFellowId: UUID?
    @State private var attendingMappings: [UUID: UUID] = [:] // individual ID -> institutional ID
    @State private var facilityMappings: [UUID: UUID] = [:] // individual ID -> institutional ID
    @State private var isMigrating = false
    @State private var migrationComplete = false
    @State private var migrationError: String?

    enum MigrationStep: Int, CaseIterable {
        case welcome = 0
        case selectIdentity = 1
        case mapAttendings = 2
        case mapFacilities = 3
        case preview = 4
        case migrating = 5
        case complete = 6
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
            .navigationTitle("Migrate to Program")
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
            ForEach(0..<5) { index in
                Capsule()
                    .fill(index <= currentStep.rawValue ? Color(red: 0.05, green: 0.35, blue: 0.65) : Color(UIColor.systemGray4))
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
        case .selectIdentity:
            selectIdentityStep
        case .mapAttendings:
            mapAttendingsStep
        case .mapFacilities:
            mapFacilitiesStep
        case .preview:
            previewStep
        case .migrating:
            migratingStep
        case .complete:
            completeStep
        }
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.merge")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))
                .padding(.top, 20)

            Text("Migrate Your Data")
                .font(.title.bold())

            Text("Transfer your procedure log and settings from Individual Mode to your program's institutional system.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 16) {
                MigrationInfoRow(icon: "person.2.fill", title: "Map Attendings", description: "Link your attendings to program attendings")
                MigrationInfoRow(icon: "building.2.fill", title: "Map Facilities", description: "Link your hospitals to program facilities")
                MigrationInfoRow(icon: "doc.text.fill", title: "Transfer Cases", description: "\(myCases.count) cases will be migrated")
                MigrationInfoRow(icon: "list.clipboard.fill", title: "Custom Procedures", description: "\(myCustomProcedures.count) custom procedures will transfer")
            }
            .padding(.vertical, 20)

            // Warning about attestation
            if currentProgram?.requireAttestationForMigratedCases == true {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Your program requires migrated cases to be attested. They will appear in your queue for attending review.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Select Identity Step

    private var selectIdentityStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 50))
                .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))

            Text("Select Your Identity")
                .font(.title2.bold())

            Text("Choose which fellow account in the program belongs to you. Your cases will be transferred to this account.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if availableFellows.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("No Fellow Accounts")
                        .font(.headline)
                    Text("Ask your program administrator to create your fellow account first.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(availableFellows) { fellow in
                        Button {
                            selectedFellowId = fellow.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fellow.fullName)
                                        .font(.body)
                                        .foregroundColor(Color(UIColor.label))
                                    if !fellow.email.isEmpty {
                                        Text(fellow.email)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedFellowId == fellow.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedFellowId == fellow.id ? Color(red: 0.05, green: 0.35, blue: 0.65).opacity(0.1) : Color(UIColor.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedFellowId == fellow.id ? Color(red: 0.05, green: 0.35, blue: 0.65) : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Map Attendings Step

    private var mapAttendingsStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Map Attendings")
                .font(.title2.bold())

            Text("Match your personal attendings to the program's attendings. Unmapped attendings will have their cases archived but still counted.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if individualAttendings.isEmpty {
                Text("No attendings to map. You can skip this step.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                VStack(spacing: 12) {
                    ForEach(individualAttendings) { attending in
                        AttendingMappingRow(
                            individualAttending: attending,
                            programAttendings: programAttendings,
                            selectedMapping: attendingMappings[attending.id]
                        ) { mapping in
                            if let id = mapping {
                                attendingMappings[attending.id] = id
                            } else {
                                attendingMappings.removeValue(forKey: attending.id)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Map Facilities Step

    private var mapFacilitiesStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 50))
                .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.8))

            Text("Map Facilities")
                .font(.title2.bold())

            Text("Match your personal facilities to the program's training facilities.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if individualFacilities.isEmpty {
                Text("No facilities to map. You can skip this step.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                VStack(spacing: 12) {
                    ForEach(individualFacilities) { facility in
                        FacilityMappingRow(
                            individualFacility: facility,
                            programFacilities: programFacilities,
                            selectedMapping: facilityMappings[facility.id]
                        ) { mapping in
                            if let id = mapping {
                                facilityMappings[facility.id] = id
                            } else {
                                facilityMappings.removeValue(forKey: facility.id)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preview Step

    private var previewStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))

            Text("Review Migration")
                .font(.title2.bold())

            Text("Review what will be migrated to your institutional account.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Summary cards
            VStack(spacing: 12) {
                MigrationSummaryCard(
                    icon: "doc.text.fill",
                    title: "Cases to Migrate",
                    value: "\(casesWithFullMapping.count)",
                    subtitle: "Fully mapped"
                )

                MigrationSummaryCard(
                    icon: "archivebox.fill",
                    title: "Cases to Archive",
                    value: "\(casesToArchive.count)",
                    subtitle: "Unmapped attendings/facilities"
                )

                MigrationSummaryCard(
                    icon: "list.clipboard.fill",
                    title: "Custom Procedures",
                    value: "\(myCustomProcedures.count)",
                    subtitle: "Will transfer"
                )

                MigrationSummaryCard(
                    icon: "chart.bar.fill",
                    title: "Total Procedure Count",
                    value: "\(totalProcedureCount)",
                    subtitle: "All cases preserved"
                )
            }

            // Attestation status info
            if currentProgram?.requireAttestationForMigratedCases == true {
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Attestation Required")
                            .font(.subheadline.bold())
                        Text("Migrated cases will be set to 'Pending' status for attending attestation.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Attestation Required")
                            .font(.subheadline.bold())
                        Text("Migrated cases will retain their original attestation status.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
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

            Text("Please wait while we transfer your cases and settings to the institutional system.")
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

                Text("Your data has been successfully transferred to the institutional system. You can now sign in as a fellow to access your cases.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    Text("What's Next?")
                        .font(.headline)
                    Text("Sign out and sign back in with your institutional credentials to see your migrated cases.")
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
                Button("Get Started") {
                    withAnimation { currentStep = .selectIdentity }
                }
                .buttonStyle(.borderedProminent)

            case .selectIdentity:
                Button("Next") {
                    withAnimation { currentStep = .mapAttendings }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFellowId == nil)

            case .mapAttendings:
                Button("Next") {
                    withAnimation { currentStep = .mapFacilities }
                }
                .buttonStyle(.borderedProminent)

            case .mapFacilities:
                Button("Review") {
                    withAnimation { currentStep = .preview }
                }
                .buttonStyle(.borderedProminent)

            case .preview:
                Button("Start Migration") {
                    startMigration()
                }
                .buttonStyle(.borderedProminent)

            case .migrating:
                EmptyView()

            case .complete:
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Migration Logic

    private var casesWithFullMapping: [CaseEntry] {
        myCases.filter { caseEntry in
            // Has attending and it's mapped
            if let attendingId = caseEntry.attendingId ?? caseEntry.supervisorId {
                if attendingMappings[attendingId] == nil {
                    return false
                }
            }
            // Has facility and it's mapped
            if let facilityId = caseEntry.facilityId ?? caseEntry.hospitalId {
                if facilityMappings[facilityId] == nil {
                    return false
                }
            }
            return true
        }
    }

    private var casesToArchive: [CaseEntry] {
        myCases.filter { caseEntry in
            // Has attending but unmapped
            if let attendingId = caseEntry.attendingId ?? caseEntry.supervisorId {
                if attendingMappings[attendingId] == nil {
                    return true
                }
            }
            // Has facility but unmapped
            if let facilityId = caseEntry.facilityId ?? caseEntry.hospitalId {
                if facilityMappings[facilityId] == nil {
                    return true
                }
            }
            return false
        }
    }

    private var totalProcedureCount: Int {
        myCases.reduce(0) { $0 + $1.procedureTagIds.count }
    }

    private func startMigration() {
        guard let fellowId = selectedFellowId else { return }

        withAnimation {
            currentStep = .migrating
        }

        // Perform migration on background thread
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            performMigration(toFellowId: fellowId)
        }
    }

    private func performMigration(toFellowId fellowId: UUID) {
        do {
            let requireAttestation = currentProgram?.requireAttestationForMigratedCases ?? false

            // 1. Migrate fully mapped cases
            for caseEntry in casesWithFullMapping {
                // Update owner to fellow
                caseEntry.ownerId = fellowId
                caseEntry.fellowId = fellowId

                // Remap attending
                if let oldAttendingId = caseEntry.attendingId ?? caseEntry.supervisorId,
                   let newAttendingId = attendingMappings[oldAttendingId] {
                    caseEntry.attendingId = newAttendingId
                    caseEntry.supervisorId = newAttendingId
                }

                // Remap facility
                if let oldFacilityId = caseEntry.facilityId ?? caseEntry.hospitalId,
                   let newFacilityId = facilityMappings[oldFacilityId] {
                    caseEntry.facilityId = newFacilityId
                    caseEntry.hospitalId = newFacilityId
                }

                // Update attestation status if required
                if requireAttestation && caseEntry.attestationStatus != .rejected {
                    caseEntry.attestationStatus = .pending
                    caseEntry.attestedAt = nil
                }

                // Mark as migrated
                caseEntry.isMigrated = true
                caseEntry.migratedAt = Date()
                caseEntry.updatedAt = Date()
            }

            // 2. Archive unmapped cases (but preserve counts)
            for caseEntry in casesToArchive {
                caseEntry.ownerId = fellowId
                caseEntry.fellowId = fellowId
                caseEntry.isArchived = true
                caseEntry.isMigrated = true
                caseEntry.migratedAt = Date()
                caseEntry.updatedAt = Date()
            }

            // 3. Migrate custom procedures
            for procedure in myCustomProcedures {
                procedure.creatorId = fellowId
                procedure.programId = currentProgram?.id
            }

            // 4. Save all changes
            try modelContext.save()

            // 5. Update app state
            UserDefaults.standard.set(fellowId.uuidString, forKey: "selectedFellowId")

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
}

// MARK: - Supporting Views

struct MigrationInfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct MigrationSummaryCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2.bold())
            }

            Spacer()

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct AttendingMappingRow: View {
    let individualAttending: Attending
    let programAttendings: [Attending]
    let selectedMapping: UUID?
    let onSelect: (UUID?) -> Void

    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.orange)
                Text(individualAttending.name)
                    .font(.subheadline.bold())
                Spacer()
            }

            Button {
                showingPicker = true
            } label: {
                HStack {
                    if let mappedId = selectedMapping,
                       let mapped = programAttendings.first(where: { $0.id == mappedId }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                            Text(mapped.name)
                                .font(.subheadline)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                            Text("Select Program Attending")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingPicker) {
            AttendingPickerSheet(
                programAttendings: programAttendings,
                selectedId: selectedMapping,
                onSelect: { id in
                    onSelect(id)
                    showingPicker = false
                }
            )
        }
    }
}

struct AttendingPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let programAttendings: [Attending]
    let selectedId: UUID?
    let onSelect: (UUID?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onSelect(nil)
                } label: {
                    HStack {
                        Text("Don't Map (Archive Cases)")
                            .foregroundColor(.secondary)
                        Spacer()
                        if selectedId == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))
                        }
                    }
                }

                ForEach(programAttendings) { attending in
                    Button {
                        onSelect(attending.id)
                    } label: {
                        HStack {
                            Text(attending.name)
                                .foregroundColor(Color(UIColor.label))
                            Spacer()
                            if selectedId == attending.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Attending")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct FacilityMappingRow: View {
    let individualFacility: TrainingFacility
    let programFacilities: [TrainingFacility]
    let selectedMapping: UUID?
    let onSelect: (UUID?) -> Void

    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.8))
                Text(individualFacility.name)
                    .font(.subheadline.bold())
                Spacer()
            }

            Button {
                showingPicker = true
            } label: {
                HStack {
                    if let mappedId = selectedMapping,
                       let mapped = programFacilities.first(where: { $0.id == mappedId }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                            Text(mapped.name)
                                .font(.subheadline)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                            Text("Select Program Facility")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingPicker) {
            FacilityPickerSheet(
                programFacilities: programFacilities,
                selectedId: selectedMapping,
                onSelect: { id in
                    onSelect(id)
                    showingPicker = false
                }
            )
        }
    }
}

struct FacilityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let programFacilities: [TrainingFacility]
    let selectedId: UUID?
    let onSelect: (UUID?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onSelect(nil)
                } label: {
                    HStack {
                        Text("Don't Map (Archive Cases)")
                            .foregroundColor(.secondary)
                        Spacer()
                        if selectedId == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))
                        }
                    }
                }

                ForEach(programFacilities) { facility in
                    Button {
                        onSelect(facility.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(facility.name)
                                    .foregroundColor(Color(UIColor.label))
                                if let shortName = facility.shortName {
                                    Text(shortName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if selectedId == facility.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Facility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    IndividualToInstitutionalMigrationView()
        .environment(AppState())
}
