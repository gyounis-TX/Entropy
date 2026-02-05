// AdminDashboardView.swift
// Procedus - Unified V7
// Complete Admin Dashboard with all management and reporting features

import SwiftUI
import SwiftData

// MARK: - Admin Dashboard View

struct AdminDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query private var programs: [Program]
    @Query private var allCases: [CaseEntry]
    @Query private var allUsers: [User]
    @Query private var attendings: [Attending]
    @Query private var facilities: [TrainingFacility]
    @Query private var customCategories: [CustomCategory]
    @Query private var customProcedures: [CustomProcedure]
    @Query private var customAccessSites: [CustomAccessSite]
    @Query private var customComplications: [CustomComplication]
    @Query private var customProcedureDetails: [CustomProcedureDetail]
    @Query private var evaluationFields: [EvaluationField]

    @AppStorage("adminName") private var adminNameStorage = ""
    @AppStorage("selectedAdminId") private var selectedAdminIdString = ""

    @State private var showingInviteCodes = false
    @State private var showingClearDataConfirmation = false
    @State private var showingPopulateDevConfirmation = false
    @State private var devDataPopulated = false
    @State private var showingSpecialtyPacks = false
    @State private var showingCustomProcedures = false
    @State private var showingCustomAccessSites = false
    @State private var showingCustomComplications = false
    @State private var showingCustomProcedureDetails = false
    @State private var showingExportSheet = false
    @State private var showingProgramMessage = false

    private var currentProgram: Program? { programs.first }

    /// Get admin users in the system
    private var adminUsers: [User] {
        allUsers.filter { $0.role == .admin }
    }

    /// Get the currently selected admin user
    private var currentAdmin: User? {
        if let adminId = UUID(uuidString: selectedAdminIdString),
           let admin = adminUsers.first(where: { $0.id == adminId }) {
            return admin
        }
        return adminUsers.first
    }

    private var fellowCount: Int {
        allUsers.filter { $0.role == .fellow && !$0.hasGraduated }.count
    }

    private var attendingCount: Int {
        attendings.filter { !$0.isArchived }.count
    }

    private var facilityCount: Int {
        facilities.filter { !$0.isArchived }.count
    }

    private var customProcedureCount: Int {
        customProcedures.filter { !$0.isArchived }.count
    }

    private var customAccessSiteCount: Int {
        customAccessSites.filter { !$0.isArchived }.count
    }

    private var customComplicationCount: Int {
        customComplications.filter { !$0.isArchived }.count
    }

    private var customProcedureDetailCount: Int {
        customProcedureDetails.filter { !$0.isArchived }.count
    }

    private var enabledPacksCount: Int {
        currentProgram?.specialtyPackIds.count ?? 0
    }

    private var placeholderAttendingCount: Int {
        attendings.filter { $0.isPlaceholder && !$0.isArchived && $0.mergedIntoId == nil }.count
    }

    /// IDs of active (non-graduated) fellows
    private var activeFellowIds: Set<UUID> {
        Set(allUsers.filter { $0.role == .fellow && !$0.hasGraduated }.map { $0.id })
    }

    /// Cases belonging to active fellows only
    private var activeFellowCases: [CaseEntry] {
        allCases.filter { caseEntry in
            if let fellowId = caseEntry.fellowId {
                return activeFellowIds.contains(fellowId)
            }
            if let ownerId = caseEntry.ownerId {
                return activeFellowIds.contains(ownerId)
            }
            return false
        }
    }

    private var totalCases: Int { activeFellowCases.count }

    private var attestedCases: Int {
        activeFellowCases.filter { $0.attestationStatus == .attested || $0.attestationStatus == .proxyAttested }.count
    }

    private var pendingCases: Int {
        activeFellowCases.filter { $0.attestationStatus == .pending || $0.attestationStatus == .requested }.count
    }

    private var rejectedCases: Int {
        activeFellowCases.filter { $0.attestationStatus == .rejected }.count
    }

    private var attestationRate: Double {
        totalCases > 0 ? Double(attestedCases) / Double(totalCases) * 100 : 0
    }

    private var pendingAttendingsAlert: some View {
        NavigationLink(destination: AttendingManagementView()) {
            HStack(spacing: 12) {
                Image(systemName: "person.badge.clock.fill")
                    .font(.title3)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(placeholderAttendingCount) Pending Attending\(placeholderAttendingCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(UIColor.label))
                    Text("Fellows added new attendings that need official accounts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Review")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Pending Attendings Alert
                    if placeholderAttendingCount > 0 {
                        pendingAttendingsAlert
                    }

                    // Statistics Section
                    statisticsSection

                    // Management Section
                    managementSection

                    // Dashboards Section
                    dashboardsSection

                    // Communications Section
                    communicationsSection

                    // Reports Section
                    reportsSection

                    // Access Section
                    accessSection

                    #if DEBUG
                    // Developer Tools Section
                    developerToolsSection
                    #endif
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingInviteCodes) {
                InviteCodesSheet()
            }
            .alert("Clear All Cases & Attestations?", isPresented: $showingClearDataConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) { clearAllCaseData() }
            } message: {
                Text("This will permanently delete ALL cases and attestations. This cannot be undone.")
            }
            .sheet(isPresented: $showingSpecialtyPacks) {
                SpecialtyPackPickerSheet()
            }
            .sheet(isPresented: $showingCustomProcedures) {
                CustomProceduresListSheet()
            }
            .sheet(isPresented: $showingCustomAccessSites) {
                CustomAccessSitesListSheet()
            }
            .sheet(isPresented: $showingCustomComplications) {
                CustomComplicationsListSheet()
            }
            .sheet(isPresented: $showingCustomProcedureDetails) {
                CustomProcedureDetailsListSheet()
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportSheet()
            }
            .sheet(isPresented: $showingProgramMessage) {
                SendProgramUpdateSheet()
            }
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                AdminStatCard(title: "Fellows", value: "\(fellowCount)", icon: "person.fill", color: .blue)
                AdminStatCard(title: "Attendings", value: "\(attendingCount)", icon: "stethoscope", color: .green)
                AdminStatCard(title: "Total Cases", value: "\(totalCases)", icon: "list.clipboard.fill", color: .blue)
                AdminStatCard(title: "Pending", value: "\(pendingCases)", icon: "clock.fill", color: .orange)
                AdminStatCard(title: "Attestation Rate", value: String(format: "%.0f%%", attestationRate), icon: "checkmark.seal.fill", color: .green)
                AdminStatCard(title: "Facilities", value: "\(facilityCount)", icon: "building.2.fill", color: .blue)
            }
        }
    }

    // MARK: - Management Section

    private var managementSection: some View {
        VStack(spacing: 8) {
            // TRAINING PROGRAM Section
            AdminSectionHeader(title: "TRAINING PROGRAM")

            NavigationLink { ManageProgramView() } label: {
                AdminPillRow(icon: "gearshape.fill", iconColor: .gray, title: "Program Settings")
            }

            NavigationLink { FellowManagementView() } label: {
                AdminPillRow(icon: "person.2.fill", iconColor: .blue, title: "Fellows", badge: fellowCount > 0 ? "\(fellowCount)" : nil)
            }

            Button { showingSpecialtyPacks = true } label: {
                AdminPillRow(icon: "square.stack.3d.up.fill", iconColor: .purple, title: "Specialty Packs", badge: enabledPacksCount > 0 ? "\(enabledPacksCount)" : nil)
            }

            NavigationLink { AttendingManagementView() } label: {
                AdminPillRow(icon: "stethoscope", iconColor: .green, title: "Attendings", badge: attendingCount > 0 ? "\(attendingCount)" : nil)
            }

            NavigationLink { FacilityManagementView() } label: {
                AdminPillRow(icon: "building.2.fill", iconColor: Color(red: 0.2, green: 0.4, blue: 0.8), title: "Hospitals", badge: facilityCount > 0 ? "\(facilityCount)" : nil)
            }

            NavigationLink { ManageEvaluationsView() } label: {
                AdminPillRow(icon: "checkmark.seal.fill", iconColor: .green, title: "Evaluations", statusBadge: currentProgram?.evaluationsEnabled == true ? "On" : nil, statusColor: .green)
            }

            NavigationLink { ManageDutyHoursSettingsView() } label: {
                AdminPillRow(icon: "clock.badge.checkmark.fill", iconColor: .orange, title: "Duty Hours", statusBadge: currentProgram?.dutyHoursEnabled == true ? (currentProgram?.allowSimpleDutyHours == true ? "Simple" : "Comprehensive") : "Off", statusColor: currentProgram?.dutyHoursEnabled == true ? .orange : .secondary)
            }

            // PROCEDURES Section
            AdminSectionHeader(title: "PROCEDURES")

            Button { showingCustomProcedures = true } label: {
                AdminPillRow(icon: "list.clipboard.fill", iconColor: Color(red: 0.9, green: 0.4, blue: 0.5), title: "Custom Procedures", badge: customProcedureCount > 0 ? "\(customProcedureCount)" : nil)
            }

            Button { showingCustomAccessSites = true } label: {
                AdminPillRow(icon: "arrow.triangle.branch", iconColor: .gray, title: "Custom Access Sites", badge: customAccessSiteCount > 0 ? "\(customAccessSiteCount)" : nil)
            }

            Button { showingCustomComplications = true } label: {
                AdminPillRow(icon: "exclamationmark.triangle.fill", iconColor: .yellow, title: "Custom Complications", badge: customComplicationCount > 0 ? "\(customComplicationCount)" : nil)
            }

            Button { showingCustomProcedureDetails = true } label: {
                AdminPillRow(icon: "slider.horizontal.3", iconColor: .cyan, title: "Custom Details", badge: customProcedureDetailCount > 0 ? "\(customProcedureDetailCount)" : nil)
            }
        }
    }

    // MARK: - Dashboards Section

    private var dashboardsSection: some View {
        VStack(spacing: 8) {
            AdminSectionHeader(title: "DASHBOARDS")

            NavigationLink { AttestationDashboardView() } label: {
                AdminPillRow(icon: "checkmark.seal.fill", iconColor: .green, title: "Attestation Dashboard", statusBadge: pendingCases > 0 ? "\(pendingCases) pending" : nil, statusColor: .orange)
            }

            NavigationLink { EvaluationSummaryView() } label: {
                AdminPillRow(icon: "star.fill", iconColor: .yellow, title: "Evaluation Dashboard")
            }

            if currentProgram?.dutyHoursEnabled == true {
                NavigationLink { DutyHoursDashboardView() } label: {
                    AdminPillRow(icon: "clock.badge.checkmark.fill", iconColor: .orange, title: "Duty Hours Dashboard")
                }
            }
        }
    }

    // MARK: - Communications Section

    private var communicationsSection: some View {
        VStack(spacing: 8) {
            AdminSectionHeader(title: "COMMUNICATIONS")

            Button { showingProgramMessage = true } label: {
                AdminPillRow(icon: "paperplane.fill", iconColor: .blue, title: "Send Message")
            }
        }
    }

    // MARK: - Reports Section

    private var reportsSection: some View {
        VStack(spacing: 8) {
            AdminSectionHeader(title: "REPORTS")

            NavigationLink { AdminCaseLogView() } label: {
                AdminPillRow(icon: "doc.text.fill", iconColor: .blue, title: "Case Log")
            }

            NavigationLink { ProcedureCountsView() } label: {
                AdminPillRow(icon: "number.circle.fill", iconColor: .green, title: "Procedure Counts")
            }

            NavigationLink { ReportsByFellowView() } label: {
                AdminPillRow(icon: "person.2.fill", iconColor: .blue, title: "Reports by Fellow")
            }

            NavigationLink { ExportDataView() } label: {
                AdminPillRow(icon: "square.and.arrow.up.fill", iconColor: .purple, title: "Export Data")
            }
        }
    }

    // MARK: - Access Section

    private var accessSection: some View {
        VStack(spacing: 8) {
            AdminSectionHeader(title: "ACCESS")

            Button { showingInviteCodes = true } label: {
                AdminPillRow(icon: "qrcode", iconColor: .purple, title: "Manage Invite Codes")
            }
        }
    }

    // MARK: - Developer Tools Section

    #if DEBUG
    @State private var showingResetDevConfirmation = false

    private var developerToolsSection: some View {
        VStack(spacing: 8) {
            AdminSectionHeader(title: "DEVELOPER TOOLS", icon: "hammer.fill", iconColor: .orange)

            // Populate Dev Program
            Button { showingPopulateDevConfirmation = true } label: {
                AdminPillRow(
                    icon: "wand.and.stars",
                    iconColor: .purple,
                    title: "Populate Dev Program",
                    statusBadge: devDataPopulated || currentProgram?.name == "My Great Fellowship" ? "Active" : nil,
                    statusColor: .green,
                    showChevron: false
                )
            }
            .disabled(currentProgram?.name == "My Great Fellowship")

            // Reset Dev Program (only show if dev program is active)
            if currentProgram?.name == "My Great Fellowship" {
                Button { showingResetDevConfirmation = true } label: {
                    AdminPillRow(
                        icon: "arrow.counterclockwise",
                        iconColor: .orange,
                        title: "Reset Dev Program",
                        showChevron: false
                    )
                }
            }

            // Clear All Cases
            Button { showingClearDataConfirmation = true } label: {
                AdminPillRow(icon: "trash.fill", iconColor: .red, title: "Clear All Cases & Attestations", subtitle: "\(totalCases) cases", showChevron: false)
            }

            Text("Dev program includes: 3 cardiology packs, 6 fellows (3 active PGY4-6, 3 graduated), 4 attendings, 2 facilities, mandatory evaluations, duty hours, and realistic procedure counts for badge testing.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
        .alert("Populate Dev Program?", isPresented: $showingPopulateDevConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Populate") { populateDevProgram() }
        } message: {
            Text("This will create 'My Great Fellowship' with test data including 3 fellows, 4 attendings, 2 facilities, cardiology specialty packs, and evaluations enabled.")
        }
        .alert("Reset Dev Program?", isPresented: $showingResetDevConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetDevProgram() }
        } message: {
            Text("This will delete all dev program data including fellows, attendings, facilities, cases, and custom procedures. You will start with a fresh program.")
        }
    }

    private func resetDevProgram() {
        // Clear AppState identity references BEFORE deleting users
        // This prevents data corruption from orphaned references
        appState.selectedFellowId = nil
        appState.selectedAttendingId = nil
        appState.currentUser = nil

        // Delete all cases
        for caseEntry in allCases {
            modelContext.delete(caseEntry)
        }

        // Delete all fellows (users with role .fellow)
        for user in allUsers where user.role == .fellow {
            modelContext.delete(user)
        }

        // Delete attending users
        for user in allUsers where user.role == .attending {
            modelContext.delete(user)
        }

        // Delete attendings
        for attending in attendings {
            modelContext.delete(attending)
        }

        // Delete facilities
        for facility in facilities {
            modelContext.delete(facility)
        }

        // Delete custom categories and procedures
        for category in customCategories {
            modelContext.delete(category)
        }
        for procedure in customProcedures {
            modelContext.delete(procedure)
        }

        // Delete evaluation fields
        for field in evaluationFields {
            modelContext.delete(field)
        }

        // Delete duty hours entries
        let dutyHoursDescriptor = FetchDescriptor<DutyHoursEntry>()
        if let dutyHours = try? modelContext.fetch(dutyHoursDescriptor) {
            for entry in dutyHours {
                modelContext.delete(entry)
            }
        }

        // Delete duty hours shifts
        let dutyShiftsDescriptor = FetchDescriptor<DutyHoursShift>()
        if let dutyShifts = try? modelContext.fetch(dutyShiftsDescriptor) {
            for shift in dutyShifts {
                modelContext.delete(shift)
            }
        }

        // Delete badges
        let badgesDescriptor = FetchDescriptor<BadgeEarned>()
        if let badges = try? modelContext.fetch(badgesDescriptor) {
            for badge in badges {
                modelContext.delete(badge)
            }
        }

        // Delete case media (local files first, then SwiftData records)
        let mediaDescriptor = FetchDescriptor<CaseMedia>()
        if let mediaItems = try? modelContext.fetch(mediaDescriptor) {
            for media in mediaItems {
                MediaStorageService.shared.deleteMedia(localPath: media.localPath, thumbnailPath: media.thumbnailPath)
                modelContext.delete(media)
            }
        }

        // Delete notifications (especially badge notifications from dev data)
        let notificationsDescriptor = FetchDescriptor<Procedus.Notification>()
        if let allNotifications = try? modelContext.fetch(notificationsDescriptor) {
            for notification in allNotifications {
                modelContext.delete(notification)
            }
        }

        // Reset program to fresh state
        if let program = currentProgram {
            program.name = ""
            program.institutionName = ""
            program.specialtyPackIds = []
            program.evaluationsEnabled = false
            program.evaluationsRequired = false
            program.dutyHoursEnabled = true
            program.updatedAt = Date()
        }

        devDataPopulated = false
        try? modelContext.save()
    }
    #endif

    private func clearAllCaseData() {
        try? modelContext.delete(model: CaseEntry.self)
        try? modelContext.save()
    }

    #if DEBUG
    private func populateDevProgram() {
        // Create or update program
        let program: Program
        if let existing = currentProgram {
            program = existing
            program.name = "My Great Fellowship"
            program.institutionName = "Springfield Medical Center"
        } else {
            program = Program(
                programCode: Program.generateProgramCode(),
                name: "My Great Fellowship",
                institutionName: "Springfield Medical Center",
                specialtyPackIds: []
            )
            modelContext.insert(program)
        }

        // Set specialty packs (3 cardiology)
        program.specialtyPackIds = [
            "interventional-cardiology",
            "electrophysiology",
            "cardiac-imaging"
        ]

        // Set fellowship specialty to Cardiology
        program.fellowshipSpecialty = .cardiology

        // Enable evaluations with MANDATORY at attestation
        program.evaluationsEnabled = true
        program.evaluationsRequired = true  // Mandatory evaluations at attestation
        program.updatedAt = Date()

        let calendar = Calendar.current

        // Create facilities
        var createdFacilityIds: [UUID] = []
        let facilityNames = [
            ("University Hospital", "UH"),
            ("Outpatient Lab", "OPL")
        ]
        for (name, shortName) in facilityNames {
            if let existing = facilities.first(where: { $0.name == name }) {
                createdFacilityIds.append(existing.id)
            } else {
                let facility = TrainingFacility(name: name)
                facility.shortName = shortName
                facility.programId = program.id
                modelContext.insert(facility)
                createdFacilityIds.append(facility.id)
            }
        }

        // Create admin users
        let adminData = [
            ("Cindy", "Crabapple", "crabapple@springfield.com"),
            ("Lionel", "Hutz", "hutz@springfield.com")
        ]
        for (first, last, email) in adminData {
            if let existingAdmin = allUsers.first(where: { $0.email == email }) {
                existingAdmin.firstName = first
                existingAdmin.lastName = last
                existingAdmin.role = .admin
            } else {
                let admin = User(
                    email: email,
                    firstName: first,
                    lastName: last,
                    role: .admin,
                    accountMode: .institutional,
                    programId: program.id
                )
                modelContext.insert(admin)
            }
        }

        // Create attendings (active)
        var createdAttendingIds: [UUID] = []
        let attendingData = [
            ("Dr. Nick", "Riviera", "drnick@springfield.com"),
            ("Ned", "Flanders", "ned@springfield.com"),
            ("Moe", "Szyslak", "moe@springfield.com"),
            ("Apu", "Nahasapeemapetilon", "apu@springfield.com")
        ]
        for (first, last, email) in attendingData {
            if let existing = attendings.first(where: { $0.firstName == first && $0.lastName == last }) {
                createdAttendingIds.append(existing.id)
            } else {
                let attending = Attending(firstName: first, lastName: last)
                attending.programId = program.id
                modelContext.insert(attending)
                createdAttendingIds.append(attending.id)

                if !allUsers.contains(where: { $0.email == email }) {
                    let user = User(
                        email: email,
                        firstName: first,
                        lastName: last,
                        role: .attending,
                        accountMode: .institutional,
                        programId: program.id
                    )
                    modelContext.insert(user)
                    attending.userId = user.id
                }
            }
        }

        // Create archived Simpson attendings (for historical cases)
        var archivedAttendingIds: [UUID] = []
        let archivedAttendingData = [
            ("Leo", "Simpson", "leo@springfield.com"),
            ("Homer", "Simpson", "homer@springfield.com")
        ]
        for (first, last, email) in archivedAttendingData {
            if let existing = attendings.first(where: { $0.firstName == first && $0.lastName == last }) {
                archivedAttendingIds.append(existing.id)
            } else {
                let attending = Attending(firstName: first, lastName: last)
                attending.programId = program.id
                attending.isArchived = true  // Archived
                modelContext.insert(attending)
                archivedAttendingIds.append(attending.id)

                if !allUsers.contains(where: { $0.email == email }) {
                    let user = User(
                        email: email,
                        firstName: first,
                        lastName: last,
                        role: .attending,
                        accountMode: .institutional,
                        programId: program.id
                    )
                    user.isArchived = true  // Archived user as well
                    modelContext.insert(user)
                    attending.userId = user.id
                }
            }
        }

        // =========================================
        // DELETE EXISTING DEV DATA
        // =========================================
        let existingCases = allCases.filter { $0.programId == program.id }
        for existingCase in existingCases { modelContext.delete(existingCase) }

        let badgesDescriptor = FetchDescriptor<BadgeEarned>()
        if let existingBadges = try? modelContext.fetch(badgesDescriptor) {
            for badge in existingBadges { modelContext.delete(badge) }
        }

        let dutyHoursDescriptor = FetchDescriptor<DutyHoursEntry>()
        if let existingHours = try? modelContext.fetch(dutyHoursDescriptor) {
            for entry in existingHours where entry.programId == program.id { modelContext.delete(entry) }
        }

        let dutyShiftsDescriptor = FetchDescriptor<DutyHoursShift>()
        if let existingShifts = try? modelContext.fetch(dutyShiftsDescriptor) {
            for shift in existingShifts where shift.programId == program.id { modelContext.delete(shift) }
        }

        // Delete existing evaluation responses
        // (Note: EvaluationResponse would need to be fetched and deleted if the model exists)

        // Delete CaseMedia from prior dev mode test fellows (@springfield.com)
        let priorDevUserIds = allUsers
            .filter { $0.email.hasSuffix("@springfield.com") }
            .map { $0.id }
        if !priorDevUserIds.isEmpty {
            let allMediaDescriptor = FetchDescriptor<CaseMedia>()
            if let allMedia = try? modelContext.fetch(allMediaDescriptor) {
                for media in allMedia where priorDevUserIds.contains(media.ownerId) {
                    MediaStorageService.shared.deleteMedia(localPath: media.localPath, thumbnailPath: media.thumbnailPath)
                    modelContext.delete(media)
                }
            }
        }

        // Delete ALL existing fellows to prevent mixing with dev data
        // This ensures a clean slate even without calling resetDevProgram first
        appState.selectedFellowId = nil
        appState.currentUser = nil
        for user in allUsers where user.role == .fellow {
            modelContext.delete(user)
        }

        // Delete ALL existing non-admin users to ensure clean dev environment
        // (Attendings are recreated below, admins are preserved)
        for user in allUsers where user.role == .attending {
            modelContext.delete(user)
        }

        // Save deletions before creating new users
        try? modelContext.save()

        // =========================================
        // CREATE 3 ACTIVE FELLOWS: PGY4, PGY5, PGY6
        // =========================================
        var activeFellowIds: [UUID] = []
        let activeFellowData: [(first: String, last: String, email: String, pgy: Int)] = [
            ("Lisa", "Simpson", "lisa@springfield.com", 4),     // PGY4 - Beginner
            ("Maggie", "Simpson", "maggie@springfield.com", 5), // PGY5 - 249 PCI
            ("Bart", "Simpson", "bart@springfield.com", 6)      // PGY6 - 249 PCI
        ]

        for (first, last, email, pgy) in activeFellowData {
            // Always create fresh fellows (all existing were deleted above)
            let fellow = User(
                email: email,
                firstName: first,
                lastName: last,
                role: .fellow,
                accountMode: .institutional,
                programId: program.id,
                trainingYear: pgy
            )
            modelContext.insert(fellow)
            activeFellowIds.append(fellow.id)
        }

        // =========================================
        // CREATE 3 GRADUATED FELLOWS (Simpson characters with specializations)
        // =========================================
        var graduatedFellowIds: [UUID] = []
        let graduatedFellowData: [(first: String, last: String, email: String, specialty: String)] = [
            ("Seymour", "Skinner", "skinner@springfield.com", "EP"),        // EP Specialist
            ("Groundskeeper", "Willie", "willie@springfield.com", "PCI"),   // Coronary Intervention
            ("Milhouse", "VanHouten", "milhouse@springfield.com", "Echo")   // Noninvasive Cardio
        ]

        for (first, last, email, _) in graduatedFellowData {
            // Always create fresh fellows (all existing were deleted above)
            let fellow = User(
                email: email,
                firstName: first,
                lastName: last,
                role: .fellow,
                accountMode: .institutional,
                programId: program.id,
                trainingYear: 6  // All graduated at PGY6
            )
            fellow.hasGraduated = true
            fellow.graduatedAt = calendar.date(byAdding: .month, value: -6, to: Date())
            modelContext.insert(fellow)
            graduatedFellowIds.append(fellow.id)
        }

        // Create default evaluation fields if not exist, and capture their IDs for rating generation
        let programIdForPredicate: UUID? = program.id
        let existingEvalFieldsDescriptor = FetchDescriptor<EvaluationField>(
            predicate: #Predicate<EvaluationField> { $0.programId == programIdForPredicate }
        )
        let existingEvalFields = (try? modelContext.fetch(existingEvalFieldsDescriptor)) ?? []
        var evaluationFieldIds: [UUID] = []

        if existingEvalFields.isEmpty {
            let defaultFields: [(title: String, description: String)] = [
                ("Procedural Competence", "Technical skill execution and equipment handling."),
                ("Clinical Judgment", "Patient selection and complication recognition."),
                ("Documentation", "Accurate and complete procedure documentation."),
                ("Professionalism", "Communication with team and patients."),
                ("Communication", "Clear handoffs and patient education.")
            ]
            for (i, fieldInfo) in defaultFields.enumerated() {
                let field = EvaluationField(
                    title: fieldInfo.title,
                    descriptionText: fieldInfo.description,
                    fieldType: .rating,
                    isRequired: true,
                    displayOrder: i,
                    programId: program.id,
                    isDefault: true
                )
                modelContext.insert(field)
                evaluationFieldIds.append(field.id)
            }
        } else {
            evaluationFieldIds = existingEvalFields.map { $0.id }
        }

        try? modelContext.save()

        // Round-robin counter for distributing cases across all attendings
        var attendingRoundRobinIndex = 0
        func getNextAttendingId() -> UUID {
            let id = createdAttendingIds[attendingRoundRobinIndex % createdAttendingIds.count]
            attendingRoundRobinIndex += 1
            return id
        }

        // =========================================
        // HELPER FUNCTION: Create attested case with evaluation
        // =========================================
        func createAttestedCase(
            fellowId: UUID,
            procedureIds: [String],
            caseDate: Date,
            caseType: CaseType,
            notes: String,
            accessSites: [String] = [],
            complications: [String] = [],
            operatorPosition: OperatorPosition = .primary
        ) {
            let weekBucket = CaseEntry.makeWeekBucket(for: caseDate)
            // Use archived Simpson attendings for older cases (>2 years old)
            let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: Date()) ?? Date()
            let attendingId: UUID
            if caseDate < twoYearsAgo && !archivedAttendingIds.isEmpty {
                // 70% chance of archived attending for old cases
                attendingId = Int.random(in: 0..<10) < 7 ? archivedAttendingIds.randomElement()! : getNextAttendingId()
            } else {
                // Round-robin through all active attendings for even distribution
                attendingId = getNextAttendingId()
            }

            let newCase = CaseEntry(
                fellowId: fellowId,
                ownerId: fellowId,
                attendingId: attendingId,
                weekBucket: weekBucket,
                facilityId: createdFacilityIds.randomElement()
            )
            newCase.programId = program.id
            newCase.procedureTagIds = procedureIds
            newCase.createdAt = caseDate
            newCase.caseTypeRaw = caseType.rawValue
            newCase.notes = notes
            newCase.accessSiteIds = accessSites
            newCase.complicationIds = complications
            newCase.operatorPositionRaw = operatorPosition.rawValue

            // 10% chance to leave case unattested (pending)
            let shouldLeavePending = Int.random(in: 0..<10) == 0

            if shouldLeavePending {
                // Leave as pending attestation
                newCase.attestationStatusRaw = AttestationStatus.pending.rawValue
            } else {
                // Mark as attested - set attestorId to the attending who attested
                newCase.attestationStatusRaw = AttestationStatus.attested.rawValue
                newCase.attestedAt = caseDate.addingTimeInterval(3600)
                newCase.attestorId = attendingId  // Critical: set attestorId for attending dashboard and evaluations

                // Add random evaluations (1-5 rating for each field)
                var evalResponses: [String: String] = [:]
                for fieldId in evaluationFieldIds {
                    let randomRating = Int.random(in: 3...5)  // Realistic ratings 3-5
                    evalResponses[fieldId.uuidString] = String(randomRating)
                }
                if let jsonData = try? JSONEncoder().encode(evalResponses),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    newCase.evaluationResponsesJson = jsonString
                }
                newCase.evaluationComment = "Good performance on this case."
            }

            modelContext.insert(newCase)
        }

        func createPendingCase(
            fellowId: UUID,
            fellowLastName: String,
            procedureIds: [String],
            caseDate: Date,
            caseType: CaseType,
            notes: String,
            accessSites: [String] = [],
            complications: [String] = [],
            operatorPosition: OperatorPosition = .primary
        ) {
            let weekBucket = CaseEntry.makeWeekBucket(for: caseDate)
            // Round-robin through all active attendings for even distribution
            let attendingId = getNextAttendingId()

            let newCase = CaseEntry(
                fellowId: fellowId,
                ownerId: fellowId,
                attendingId: attendingId,
                weekBucket: weekBucket,
                facilityId: createdFacilityIds.randomElement()
            )
            newCase.programId = program.id
            newCase.procedureTagIds = procedureIds
            newCase.createdAt = caseDate
            newCase.caseTypeRaw = caseType.rawValue
            newCase.notes = notes
            newCase.accessSiteIds = accessSites
            newCase.complicationIds = complications
            newCase.operatorPositionRaw = operatorPosition.rawValue
            newCase.attestationStatusRaw = AttestationStatus.pending.rawValue

            modelContext.insert(newCase)

            // Create attestation notification for attending
            let procedureCount = procedureIds.count
            let message = "\(fellowLastName) submitted a case of \(procedureCount) procedure(s) for your attestation."
            let notification = Notification(
                userId: attendingId,
                title: "New Case for Attestation",
                message: message,
                notificationType: NotificationType.attestationRequested.rawValue,
                caseId: newCase.id,
                attendingId: attendingId
            )
            modelContext.insert(notification)
        }

        // =========================================
        // ACCESS SITES & NOTES
        // =========================================
        let pciNotes = ["Successful PCI with DES.", "Complex intervention, good result.", "Elective PCI, no complications."]
        let cathNotes = ["Diagnostic cath, normal coronaries.", "Moderate disease, medical management.", "Severe 3VD, referred to surgery."]
        let echoNotes = ["TTE showing preserved EF.", "Stress echo negative for ischemia.", "TEE for structural assessment."]
        let epNotes = ["EP study completed.", "Successful ablation.", "Device implant, good parameters."]

        // =========================================
        // PROCEDURE-SPECIFIC ACCESS SITES
        // =========================================
        // IC (Diagnostic Cath, PCI) - primarily radial (70%) or femoral (30%)
        func randomICAccessSites() -> [String] {
            return Int.random(in: 1...10) <= 7 ? ["Radial"] : ["Femoral"]
        }

        // EP Ablations - femoral for venous access, sometimes jugular
        func randomEPAblationAccessSites() -> [String] {
            return Int.random(in: 1...10) <= 8 ? ["Femoral"] : ["Femoral", "Jugular"]
        }

        // EP Devices (pacemakers, ICDs) - subclavian or axillary approach
        func randomEPDeviceAccessSites() -> [String] {
            let choices: [[String]] = [["Subclavian"], ["Axillary"], ["Subclavian", "Jugular"]]
            return choices.randomElement()!
        }

        // =========================================
        // PROCEDURE-SPECIFIC COMPLICATIONS
        // =========================================
        // PCI complications - 5% chance
        let pciComplications = ["Bleeding", "Vascular Injury", "Hematoma", "MI", "Arrhythmia", "Renal/AKI", "Stroke/TIA"]
        // Diagnostic cath complications - lighter (access site related)
        let cathComplications = ["Bleeding", "Vascular Injury", "Hematoma", "Renal/AKI", "Allergic Reaction"]
        // EP ablation complications
        let epAblationComplications = ["Tamponade", "Stroke/TIA", "Arrhythmia", "Vascular Injury", "Bleeding", "Hematoma"]
        // EP device complications
        let epDeviceComplications = ["Pneumothorax", "Infection", "Hematoma", "Bleeding", "Arrhythmia"]

        // Helper to get random complications with 5% chance
        func maybeAddComplications(from pool: [String]) -> [String] {
            if Int.random(in: 1...100) <= 5 {
                // Pick 1-2 complications
                let count = Int.random(in: 1...2)
                return Array(pool.shuffled().prefix(count))
            }
            return []
        }

        // =========================================
        // PGY4 BEGINNER - Lisa Simpson (few procedures)
        // Fellowship year 1 (PGY4) - just starting (started 3 months ago)
        // =========================================
        let lisaId = activeFellowIds[0]

        // 15 diagnostic caths (spread over 3 months)
        for i in 0..<15 {
            let weeksAgo = i / 2
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: Date()) ?? Date()
            let isPending = i < 1  // Last 5% pending (1 of 15)
            let accessSites = randomICAccessSites()
            let complications = maybeAddComplications(from: cathComplications)
            if isPending {
                createPendingCase(fellowId: lisaId, fellowLastName: "Simpson", procedureIds: ["ic-dx-lhc", "ic-dx-coro"], caseDate: caseDate, caseType: .invasive, notes: cathNotes.randomElement()!, accessSites: accessSites, complications: complications)
            } else {
                createAttestedCase(fellowId: lisaId, procedureIds: ["ic-dx-lhc", "ic-dx-coro"], caseDate: caseDate, caseType: .invasive, notes: cathNotes.randomElement()!, accessSites: accessSites, complications: complications)
            }
        }

        // 5 PCI cases
        for i in 0..<5 {
            let weeksAgo = i
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: Date()) ?? Date()
            let accessSites = randomICAccessSites()
            let complications = maybeAddComplications(from: pciComplications)
            createAttestedCase(fellowId: lisaId, procedureIds: ["ic-pci-stent"], caseDate: caseDate, caseType: .invasive, notes: pciNotes.randomElement()!, accessSites: accessSites, complications: complications)
        }

        // 20 echo cases (noninvasive - no access sites or complications)
        for i in 0..<20 {
            let weeksAgo = i / 3
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: Date()) ?? Date()
            let isPending = i < 1
            let procId = i % 2 == 0 ? "ci-echo-tte" : "ci-echo-stress"
            if isPending {
                createPendingCase(fellowId: lisaId, fellowLastName: "Simpson", procedureIds: [procId], caseDate: caseDate, caseType: .noninvasive, notes: echoNotes.randomElement()!)
            } else {
                createAttestedCase(fellowId: lisaId, procedureIds: [procId], caseDate: caseDate, caseType: .noninvasive, notes: echoNotes.randomElement()!)
            }
        }

        // =========================================
        // PGY5 - Maggie Simpson (249 PCI + scattered procedures)
        // Fellowship years 1-2 (started 15 months ago)
        // =========================================
        let maggieId = activeFellowIds[1]

        // 249 PCI cases spread over ~15 months (about 4 per week)
        for i in 0..<249 {
            let weeksAgo = i / 4
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 65), to: Date()) ?? Date()
            let isPending = i < 12  // Last 5% pending (12 of 249)
            let procId = i % 5 == 0 ? "ic-pci-rotablator" : (i % 3 == 0 ? "ic-pci-dcb" : "ic-pci-stent")
            let accessSites = randomICAccessSites()
            let complications = maybeAddComplications(from: pciComplications)
            if isPending {
                createPendingCase(fellowId: maggieId, fellowLastName: "Simpson", procedureIds: [procId], caseDate: caseDate, caseType: .invasive, notes: pciNotes.randomElement()!, accessSites: accessSites, complications: complications)
            } else {
                createAttestedCase(fellowId: maggieId, procedureIds: [procId], caseDate: caseDate, caseType: .invasive, notes: pciNotes.randomElement()!, accessSites: accessSites, complications: complications)
            }
        }

        // 200 diagnostic caths
        for i in 0..<200 {
            let weeksAgo = i / 4
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 65), to: Date()) ?? Date()
            let accessSites = randomICAccessSites()
            let complications = maybeAddComplications(from: cathComplications)
            createAttestedCase(fellowId: maggieId, procedureIds: ["ic-dx-lhc", "ic-dx-coro"], caseDate: caseDate, caseType: .invasive, notes: cathNotes.randomElement()!, accessSites: accessSites, complications: complications)
        }

        // 150 TTE + 50 TEE (noninvasive - no access sites or complications)
        for i in 0..<150 {
            let weeksAgo = i / 3
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 65), to: Date()) ?? Date()
            createAttestedCase(fellowId: maggieId, procedureIds: ["ci-echo-tte"], caseDate: caseDate, caseType: .noninvasive, notes: echoNotes.randomElement()!)
        }
        for i in 0..<50 {
            let weeksAgo = i / 2
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 65), to: Date()) ?? Date()
            createAttestedCase(fellowId: maggieId, procedureIds: ["ci-echo-tee"], caseDate: caseDate, caseType: .noninvasive, notes: "TEE for procedure guidance.")
        }

        // 30 EP cases (scattered) - mix of devices and ablations
        for i in 0..<30 {
            let weeksAgo = i * 2
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 65), to: Date()) ?? Date()
            let procId = ["ep-dev-ppm-dp", "ep-abl-svt", "ep-dx-eps"].randomElement()!
            let isDevice = procId.contains("dev")
            let accessSites = isDevice ? randomEPDeviceAccessSites() : randomEPAblationAccessSites()
            let complications = maybeAddComplications(from: isDevice ? epDeviceComplications : epAblationComplications)
            createAttestedCase(fellowId: maggieId, procedureIds: [procId], caseDate: caseDate, caseType: .invasive, notes: epNotes.randomElement()!, accessSites: accessSites, complications: complications)
        }

        // =========================================
        // PGY6 - Bart Simpson (249 PCI)
        // Fellowship years 1-3 (about to graduate)
        // =========================================
        let bartId = activeFellowIds[2]

        // 249 PCI cases spread over ~27 months
        for i in 0..<249 {
            let weeksAgo = i / 3
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 117), to: Date()) ?? Date()
            let isPending = i < 12  // Last ~5% pending
            let procId = ["ic-pci-stent", "ic-pci-dcb", "ic-pci-rotablator", "ic-pci-ivl"].randomElement()!
            let accessSites = randomICAccessSites()
            let complications = maybeAddComplications(from: pciComplications)
            if isPending {
                createPendingCase(fellowId: bartId, fellowLastName: "Simpson", procedureIds: [procId], caseDate: caseDate, caseType: .invasive, notes: pciNotes.randomElement()!, accessSites: accessSites, complications: complications)
            } else {
                createAttestedCase(fellowId: bartId, procedureIds: [procId], caseDate: caseDate, caseType: .invasive, notes: pciNotes.randomElement()!, accessSites: accessSites, complications: complications)
            }
        }

        // 250 diagnostic caths
        for i in 0..<250 {
            let weeksAgo = i / 3
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 117), to: Date()) ?? Date()
            let accessSites = randomICAccessSites()
            let complications = maybeAddComplications(from: cathComplications)
            createAttestedCase(fellowId: bartId, procedureIds: ["ic-dx-lhc", "ic-dx-coro"], caseDate: caseDate, caseType: .invasive, notes: cathNotes.randomElement()!, accessSites: accessSites, complications: complications)
        }

        // 200 TTE + 60 TEE (noninvasive - no access sites or complications)
        for i in 0..<200 {
            let weeksAgo = i / 3
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 117), to: Date()) ?? Date()
            createAttestedCase(fellowId: bartId, procedureIds: ["ci-echo-tte"], caseDate: caseDate, caseType: .noninvasive, notes: echoNotes.randomElement()!)
        }
        for i in 0..<60 {
            let weeksAgo = i * 2
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 117), to: Date()) ?? Date()
            createAttestedCase(fellowId: bartId, procedureIds: ["ci-echo-tee"], caseDate: caseDate, caseType: .noninvasive, notes: "TEE for structural guidance.")
        }

        // =========================================
        // GRADUATED FELLOWS WITH COCATS LEVEL 2 SPECIALIZATIONS
        // =========================================

        // Skinner - EP Specialist (COCATS Level 2 EP: 100+ procedures)
        let skinnerId = graduatedFellowIds[0]
        // EP: 150 ablations + 80 device implants = 230 EP procedures
        for i in 0..<150 {
            let weeksAgo = i / 2
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 156), to: Date()) ?? Date()
            let procId = ["ep-abl-pvi", "ep-abl-svt", "ep-abl-cti", "ep-abl-avnrt", "ep-abl-vt-idio"].randomElement()!
            let accessSites = randomEPAblationAccessSites()
            let complications = maybeAddComplications(from: epAblationComplications)
            createAttestedCase(fellowId: skinnerId, procedureIds: [procId], caseDate: caseDate, caseType: .invasive, notes: "Successful ablation procedure.", accessSites: accessSites, complications: complications)
        }
        for i in 0..<80 {
            let weeksAgo = i
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 156), to: Date()) ?? Date()
            let procId = ["ep-dev-ppm-dp", "ep-dev-icd", "ep-dev-crt-d", "ep-dev-leadless"].randomElement()!
            let accessSites = randomEPDeviceAccessSites()
            let complications = maybeAddComplications(from: epDeviceComplications)
            createAttestedCase(fellowId: skinnerId, procedureIds: [procId], caseDate: caseDate, caseType: .invasive, notes: "Device implant, good parameters.", accessSites: accessSites, complications: complications)
        }
        // Level 2 Echo (150 TTE + 50 TEE) - noninvasive
        for i in 0..<150 {
            let weeksAgo = i / 2
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 156), to: Date()) ?? Date()
            createAttestedCase(fellowId: skinnerId, procedureIds: ["ci-echo-tte"], caseDate: caseDate, caseType: .noninvasive, notes: echoNotes.randomElement()!)
        }
        for i in 0..<50 {
            let weeksAgo = i * 3
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 156), to: Date()) ?? Date()
            createAttestedCase(fellowId: skinnerId, procedureIds: ["ci-echo-tee"], caseDate: caseDate, caseType: .noninvasive, notes: "TEE for device guidance.")
        }
        // Some diagnostic caths (100)
        for i in 0..<100 {
            let weeksAgo = i
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 156), to: Date()) ?? Date()
            let accessSites = randomICAccessSites()
            let complications = maybeAddComplications(from: cathComplications)
            createAttestedCase(fellowId: skinnerId, procedureIds: ["ic-dx-lhc"], caseDate: caseDate, caseType: .invasive, notes: cathNotes.randomElement()!, accessSites: accessSites, complications: complications)
        }

        // Willie - Coronary Intervention Specialist (COCATS Level 2 PCI: 200+)
        let willieId = graduatedFellowIds[1]
        // 280 PCI cases
        for i in 0..<280 {
            let weeksAgo = i / 3
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 156), to: Date()) ?? Date()
            let procId = ["ic-pci-stent", "ic-pci-rotablator", "ic-pci-ivl", "ic-pci-dcb"].randomElement()!
            let accessSites = randomICAccessSites()
            let complications = maybeAddComplications(from: pciComplications)
            createAttestedCase(fellowId: willieId, procedureIds: [procId], caseDate: caseDate, caseType: .invasive, notes: pciNotes.randomElement()!, accessSites: accessSites, complications: complications)
        }
        // 300 diagnostic caths
        for i in 0..<300 {
            let weeksAgo = i / 3
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 156), to: Date()) ?? Date()
            let accessSites = randomICAccessSites()
            let complications = maybeAddComplications(from: cathComplications)
            createAttestedCase(fellowId: willieId, procedureIds: ["ic-dx-lhc", "ic-dx-coro"], caseDate: caseDate, caseType: .invasive, notes: cathNotes.randomElement()!, accessSites: accessSites, complications: complications)
        }
        // Level 2 Echo - noninvasive
        for i in 0..<150 {
            let weeksAgo = i / 2
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 156), to: Date()) ?? Date()
            createAttestedCase(fellowId: willieId, procedureIds: ["ci-echo-tte"], caseDate: caseDate, caseType: .noninvasive, notes: echoNotes.randomElement()!)
        }
        for i in 0..<50 {
            let weeksAgo = i * 3
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 156), to: Date()) ?? Date()
            createAttestedCase(fellowId: willieId, procedureIds: ["ci-echo-tee"], caseDate: caseDate, caseType: .noninvasive, notes: "TEE for PCI guidance.")
        }

        // Milhouse - Noninvasive Cardio Specialist (COCATS Level 2 Echo)
        let milhouseId = graduatedFellowIds[2]
        // Heavy echo volume: 400 TTE + 100 TEE + 100 stress echo - all noninvasive
        for i in 0..<400 {
            let weeksAgo = i / 4
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 156), to: Date()) ?? Date()
            createAttestedCase(fellowId: milhouseId, procedureIds: ["ci-echo-tte"], caseDate: caseDate, caseType: .noninvasive, notes: echoNotes.randomElement()!)
        }
        for i in 0..<100 {
            let weeksAgo = i
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 156), to: Date()) ?? Date()
            createAttestedCase(fellowId: milhouseId, procedureIds: ["ci-echo-tee"], caseDate: caseDate, caseType: .noninvasive, notes: "TEE structural assessment.")
        }
        for i in 0..<100 {
            let weeksAgo = i
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 156), to: Date()) ?? Date()
            createAttestedCase(fellowId: milhouseId, procedureIds: ["ci-echo-stress"], caseDate: caseDate, caseType: .noninvasive, notes: "Stress echo negative.")
        }
        // Nuclear and CT imaging - noninvasive
        for i in 0..<120 {
            let weeksAgo = i
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 156), to: Date()) ?? Date()
            let procId = ["ci-nuc-spect", "ci-nuc-pet", "ci-ct-cta"].randomElement()!
            createAttestedCase(fellowId: milhouseId, procedureIds: [procId], caseDate: caseDate, caseType: .noninvasive, notes: "Advanced imaging study.")
        }
        // Minimal invasive (100 caths for level 2)
        for i in 0..<100 {
            let weeksAgo = i
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -min(weeksAgo, 156), to: Date()) ?? Date()
            let accessSites = randomICAccessSites()
            let complications = maybeAddComplications(from: cathComplications)
            createAttestedCase(fellowId: milhouseId, procedureIds: ["ic-dx-lhc"], caseDate: caseDate, caseType: .invasive, notes: cathNotes.randomElement()!, accessSites: accessSites, complications: complications)
        }

        // =========================================
        // DUTY HOURS FOR ALL FELLOWS (based on academic year start July 1)
        // =========================================

        // Helper: Calculate weeks since academic year start for a PGY level
        // PGY4 = fellowship year 1 (started most recent July 1)
        // PGY5 = fellowship year 2 (started July 1 one year ago)
        // PGY6 = fellowship year 3 (started July 1 two years ago)
        func academicYearStart(for pgyLevel: Int) -> Date {
            let now = Date()
            let currentYear = calendar.component(.year, from: now)
            let currentMonth = calendar.component(.month, from: now)

            // Fellowship years since PGY4
            let fellowshipYears = pgyLevel - 4

            // If we're before July, academic year started last calendar year
            let academicStartYear = currentMonth >= 7 ? currentYear - fellowshipYears : currentYear - 1 - fellowshipYears

            var components = DateComponents()
            components.year = academicStartYear
            components.month = 7
            components.day = 1
            return calendar.date(from: components) ?? now
        }

        func weeksSince(_ startDate: Date) -> Int {
            let now = Date()
            let weeks = calendar.dateComponents([.weekOfYear], from: startDate, to: now).weekOfYear ?? 0
            return max(0, weeks)
        }

        // DUTY HOURS FOR ACTIVE FELLOWS
        let activeFellowPGYLevels = [4, 5, 6]  // Lisa PGY4, Maggie PGY5, Bart PGY6

        for (index, fellowId) in activeFellowIds.enumerated() {
            let pgyLevel = activeFellowPGYLevels[index]
            let startDate = academicYearStart(for: pgyLevel)
            let weeksInFellowship = weeksSince(startDate)

            for weekOffset in 0..<weeksInFellowship {
                let weekDate = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()) ?? Date()
                let weekBucket = CaseEntry.makeWeekBucket(for: weekDate)

                // Vary hours realistically: most weeks 55-75, occasional light weeks (vacation/conference)
                let isVacationWeek = Int.random(in: 0..<20) == 0  // ~5% chance
                let isConferenceWeek = Int.random(in: 0..<25) == 0  // ~4% chance
                let hours: Double
                if isVacationWeek {
                    hours = 0  // Vacation
                } else if isConferenceWeek {
                    hours = Double.random(in: 20...35)  // Conference/light week
                } else {
                    hours = Double.random(in: 55...75)  // Normal work week
                }

                let dutyEntry = DutyHoursEntry(
                    userId: fellowId,
                    programId: program.id,
                    weekBucket: weekBucket,
                    hours: hours,
                    notes: isVacationWeek ? "Vacation" : (isConferenceWeek ? "Conference" : nil)
                )
                modelContext.insert(dutyEntry)

                // Create comprehensive shift records for recent 12 weeks
                if weekOffset < 12 && !isVacationWeek {
                    let shiftsPerWeek = isConferenceWeek ? 3 : 5
                    for dayIndex in 0..<shiftsPerWeek {
                        guard let shiftDate = calendar.date(byAdding: .day, value: dayIndex, to: calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekDate))!) else { continue }

                        // Start time: 6-7 AM
                        let startHour = Int.random(in: 6...7)
                        guard let startTime = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: shiftDate) else { continue }

                        // Shift type: mostly regular, occasional call
                        let shiftType: DutyHoursShiftType
                        if dayIndex == 4 && Int.random(in: 0..<3) == 0 {
                            shiftType = .call  // ~33% Friday call
                        } else if dayIndex == 3 && Int.random(in: 0..<5) == 0 {
                            shiftType = .nightFloat
                        } else {
                            shiftType = .regular
                        }

                        let shift = DutyHoursShift(
                            userId: fellowId,
                            programId: program.id,
                            shiftDate: shiftDate,
                            startTime: startTime,
                            shiftType: shiftType,
                            location: .inHouse
                        )

                        // Clock out: 10-14 hours later
                        let shiftHours = shiftType == .call ? Double.random(in: 20...24) : Double.random(in: 10...14)
                        let endTime = startTime.addingTimeInterval(shiftHours * 3600)
                        shift.clockOut(at: endTime)
                        shift.breakMinutes = Int.random(in: 15...45)
                        shift.effectiveHours = shiftHours - Double(shift.breakMinutes) / 60.0

                        modelContext.insert(shift)
                    }
                }
            }
        }

        // DUTY HOURS FOR GRADUATED FELLOWS (3 years of fellowship, ended 6 months ago)
        let graduatedFellowshipWeeks = 156  // 3 years

        for fellowId in graduatedFellowIds {
            // Graduated 6 months ago, so their duty hours ended 6 months back
            let graduationOffset = 26  // ~6 months in weeks

            for weekOffset in graduationOffset..<(graduationOffset + graduatedFellowshipWeeks) {
                let weekDate = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()) ?? Date()
                let weekBucket = CaseEntry.makeWeekBucket(for: weekDate)

                // Vary hours realistically
                let isVacationWeek = Int.random(in: 0..<20) == 0
                let hours: Double = isVacationWeek ? 0 : Double.random(in: 55...75)

                let dutyEntry = DutyHoursEntry(
                    userId: fellowId,
                    programId: program.id,
                    weekBucket: weekBucket,
                    hours: hours,
                    notes: isVacationWeek ? "Vacation" : nil
                )
                modelContext.insert(dutyEntry)
            }
        }

        try? modelContext.save()

        // Add sample images (10 per fellow) with titles, labels, and comments
        addSampleImagesToDevCases(activeFellowIds: activeFellowIds, fellows: [
            (id: activeFellowIds[0], name: "Lisa Simpson"),
            (id: activeFellowIds[1], name: "Maggie Simpson"),
            (id: activeFellowIds[2], name: "Bart Simpson")
        ], attendingIds: createdAttendingIds, attendingNames: attendingData.map { "\($0.0) \($0.1)" })

        // Check and award badges for all fellows
        let allFellowIds = activeFellowIds + graduatedFellowIds
        for fellowId in allFellowIds {
            checkAndAwardBadgesForFellow(fellowId, programId: program.id)
        }

        devDataPopulated = true
    }

    private func addSampleImagesToDevCases(activeFellowIds: [UUID], fellows: [(id: UUID, name: String)], attendingIds: [UUID], attendingNames: [String]) {
        // Fetch all cases for active fellows
        let casesDescriptor = FetchDescriptor<CaseEntry>()
        guard let allCases = try? modelContext.fetch(casesDescriptor) else { return }

        // Sample titles (≤12 chars)
        let sampleTitles = [
            "RCA Lesion", "LAD Stent", "Echo View", "EP Map",
            "Stress ECG", "CXR Finding", "Holter Data", "LV Function",
            "Valve Study", "Cath Result", "ASD Closure", "PCI Result"
        ]

        // Sample labels for Teaching Files
        let teachingLabels = [
            "Teaching Example", "Interesting Case", "Classic Finding",
            "Rare Finding", "Good Outcome", "Complex Anatomy",
            "Board Review", "Unusual Approach", "Complications",
            "Technical Challenge"
        ]
        let privateLabels = ["Personal Reference", "Follow-up", "To Review"]

        // Sample comments from various perspectives
        let fellowComments = [
            "Great teaching example!",
            "Similar to a case I had last month",
            "This anatomy is really well demonstrated",
            "Perfect example for board prep",
            "Can you clarify the wire position?",
            "Interesting approach, thanks for sharing",
            "I've seen this finding before on rotation",
            "What was the final outcome?",
            "Very helpful for my upcoming exam"
        ]
        let attendingComments = [
            "Well documented case",
            "The approach looks excellent",
            "Would have considered alternative access",
            "Classic textbook finding, well captured",
            "Nice work on this one",
            "Consider reviewing the ACC guidelines for this",
            "This is a great discussion point for conference",
            "Rare finding, well identified"
        ]

        // Real medical images from asset catalog, mapped by case type
        let coronaryImages = ["DevCoronary1", "DevCoronary2", "DevCoronary3"]
        let echoImages = ["DevEcho1", "DevEcho2", "DevEcho3"]
        let ctImages = ["DevCardiacCT", "DevCT1"]
        let allDevImages = coronaryImages + echoImages + ctImages

        // Determine which images to use based on procedure tags
        func devImagesForCase(_ caseEntry: CaseEntry) -> [String] {
            let tags = caseEntry.procedureTagIds
            let hasCoronary = tags.contains { $0.hasPrefix("ic-dx-") || $0.hasPrefix("ic-pci-") }
            let hasEcho = tags.contains { $0.hasPrefix("ci-echo-") }
            let hasCT = tags.contains { $0.hasPrefix("ci-ct-") }

            if hasCoronary { return coronaryImages }
            if hasEcho { return echoImages }
            if hasCT { return ctImages }
            // EP, nuclear, or other → cycle through all
            return allDevImages
        }

        // All people who can comment (fellows + attendings)
        let allCommenters: [(id: UUID, name: String, role: UserRole)] =
            fellows.map { (id: $0.id, name: $0.name, role: .fellow) } +
            zip(attendingIds, attendingNames).map { (id: $0.0, name: $0.1, role: .attending) }

        for fellowInfo in fellows {
            let fellowCases = allCases.filter { $0.ownerId == fellowInfo.id || $0.fellowId == fellowInfo.id }
            guard !fellowCases.isEmpty else { continue }

            // Select exactly 10 cases (or fewer if not enough cases)
            let selectedCases = fellowCases.shuffled().prefix(10)

            for (index, caseEntry) in selectedCases.enumerated() {
                // Pick a real medical image from asset catalog based on case type
                let imagePool = devImagesForCase(caseEntry)
                let imageName = imagePool[index % imagePool.count]

                // Load from asset catalog
                guard let realImage = UIImage(named: imageName) else { continue }

                // Save the image using MediaStorageService
                guard let savedResult = MediaStorageService.shared.saveImage(realImage, forCaseId: caseEntry.id) else { continue }

                // Create media entry with actual saved path
                let media = CaseMedia(
                    caseEntryId: caseEntry.id,
                    ownerId: fellowInfo.id,
                    ownerName: fellowInfo.name,
                    mediaType: .image,
                    fileName: "\(imageName)_\(index + 1).jpg",
                    localPath: savedResult.localPath
                )

                // Set title
                media.title = sampleTitles[index % sampleTitles.count]

                // Set metadata from actual saved image
                media.fileSizeBytes = savedResult.fileSize
                media.contentHash = savedResult.contentHash
                media.width = savedResult.width
                media.height = savedResult.height
                media.thumbnailPath = savedResult.thumbnailPath
                media.caseDate = caseEntry.createdAt
                media.textDetectionRan = true
                media.textWasDetected = false
                media.userConfirmedNoPHI = true
                media.userConfirmedAt = caseEntry.createdAt
                media.createdAt = caseEntry.createdAt
                media.updatedAt = caseEntry.createdAt

                // Share 7 out of 10 to Teaching Files
                let isShared = index < 7
                media.isSharedWithFellowship = isShared

                // Add labels
                if isShared {
                    let labelCount = Int.random(in: 2...4)
                    let imageLabel = imageName.hasPrefix("DevCoronary") ? "Coronary Angiogram" :
                                     imageName.hasPrefix("DevEcho") ? "Echocardiogram" : "Cardiac CT"
                    var labels = [imageLabel]
                    labels += teachingLabels.shuffled().prefix(labelCount - 1)
                    media.searchTerms = labels
                    media.comment = "Teaching case - \(imageLabel)"
                } else {
                    media.searchTerms = [privateLabels.randomElement()!]
                }

                modelContext.insert(media)

                // Add sample comments to shared images (1-5 comments each)
                if isShared {
                    let commentCount = Int.random(in: 1...5)

                    // First comment is always from the owner (initial submission comment)
                    let ownerComment = MediaComment(
                        mediaId: media.id,
                        authorId: fellowInfo.id,
                        authorName: fellowInfo.name,
                        authorRole: .fellow,
                        text: media.comment ?? "Sharing this for the group"
                    )
                    ownerComment.createdAt = caseEntry.createdAt
                    modelContext.insert(ownerComment)

                    // Additional discussion comments from other users
                    let otherCommenters = allCommenters.filter { $0.id != fellowInfo.id }.shuffled()
                    for commentIndex in 0..<min(commentCount, otherCommenters.count) {
                        let commenter = otherCommenters[commentIndex]
                        let commentText: String
                        if commenter.role == .attending {
                            commentText = attendingComments.randomElement()!
                        } else {
                            commentText = fellowComments.randomElement()!
                        }

                        let comment = MediaComment(
                            mediaId: media.id,
                            authorId: commenter.id,
                            authorName: commenter.name,
                            authorRole: commenter.role,
                            text: commentText
                        )
                        // Stagger comment timestamps
                        comment.createdAt = caseEntry.createdAt.addingTimeInterval(Double((commentIndex + 1) * 3600 * Int.random(in: 1...24)))
                        modelContext.insert(comment)
                    }
                }
            }

            // --- Video attachments: 1 procedure video on ~3 random cases per fellow ---
            if let videoURL = Bundle.main.url(forResource: "DevProcedureVideo1", withExtension: "mov") {
                let videoCases = fellowCases.shuffled().prefix(3)
                let videoTitles = ["Procedure", "Fluoro Clip", "Cath Review"]

                for (vIndex, caseEntry) in videoCases.enumerated() {
                    guard let savedResult = MediaStorageService.shared.saveVideoSync(from: videoURL, forCaseId: caseEntry.id) else { continue }

                    let media = CaseMedia(
                        caseEntryId: caseEntry.id,
                        ownerId: fellowInfo.id,
                        ownerName: fellowInfo.name,
                        mediaType: .video,
                        fileName: "procedure_\(vIndex + 1).mov",
                        localPath: savedResult.localPath
                    )

                    media.title = videoTitles[vIndex % videoTitles.count]
                    media.fileSizeBytes = savedResult.fileSize
                    media.contentHash = savedResult.contentHash
                    media.thumbnailPath = savedResult.thumbnailPath
                    media.caseDate = caseEntry.createdAt
                    media.textDetectionRan = false
                    media.textWasDetected = false
                    media.userConfirmedNoPHI = true
                    media.userConfirmedAt = caseEntry.createdAt
                    media.createdAt = caseEntry.createdAt
                    media.updatedAt = caseEntry.createdAt

                    // Share 2 of 3 videos to Teaching Files
                    let isShared = vIndex < 2
                    media.isSharedWithFellowship = isShared

                    if isShared {
                        media.searchTerms = ["Procedure Video", teachingLabels.randomElement() ?? "Cardiology"]
                        media.comment = "Procedure recording for review"
                    } else {
                        media.searchTerms = [privateLabels.randomElement() ?? "Personal"]
                    }

                    modelContext.insert(media)

                    // Add sample comments to shared videos
                    if isShared {
                        let commentCount = Int.random(in: 1...3)
                        let ownerComment = MediaComment(
                            mediaId: media.id,
                            authorId: fellowInfo.id,
                            authorName: fellowInfo.name,
                            authorRole: .fellow,
                            text: media.comment ?? "Sharing this procedure video"
                        )
                        ownerComment.createdAt = caseEntry.createdAt
                        modelContext.insert(ownerComment)

                        let otherCommenters = allCommenters.filter { $0.id != fellowInfo.id }.shuffled()
                        for commentIndex in 0..<min(commentCount, otherCommenters.count) {
                            let commenter = otherCommenters[commentIndex]
                            let commentText = commenter.role == .attending
                                ? attendingComments.randomElement()!
                                : fellowComments.randomElement()!

                            let comment = MediaComment(
                                mediaId: media.id,
                                authorId: commenter.id,
                                authorName: commenter.name,
                                authorRole: commenter.role,
                                text: commentText
                            )
                            comment.createdAt = caseEntry.createdAt.addingTimeInterval(Double((commentIndex + 1) * 3600 * Int.random(in: 1...24)))
                            modelContext.insert(comment)
                        }
                    }
                }
            }
        }

        try? modelContext.save()
    }

    private func checkAndAwardBadgesForFellow(_ fellowId: UUID, programId: UUID) {
        // Fetch all cases
        let casesDescriptor = FetchDescriptor<CaseEntry>()
        guard let allCasesForCheck = try? modelContext.fetch(casesDescriptor) else { return }

        // Fetch existing badges for this fellow
        let badgesDescriptor = FetchDescriptor<BadgeEarned>(
            predicate: #Predicate<BadgeEarned> { $0.fellowId == fellowId }
        )
        let existingBadges = (try? modelContext.fetch(badgesDescriptor)) ?? []

        // Get the most recent attested case for this fellow to use as the triggering case
        let fellowAttestedCases = allCasesForCheck.filter {
            ($0.ownerId == fellowId || $0.fellowId == fellowId) &&
            $0.attestationStatus == .attested &&
            !$0.isArchived
        }.sorted { $0.createdAt > $1.createdAt }

        guard let triggeringCase = fellowAttestedCases.first else { return }

        // Check and award new badges
        let newBadges = BadgeService.shared.checkAndAwardBadges(
            for: fellowId,
            attestedCase: triggeringCase,
            allCases: allCasesForCheck,
            existingBadges: existingBadges,
            modelContext: modelContext
        )

        // Create notifications for earned badges
        for earned in newBadges {
            if let badge = BadgeCatalog.badge(withId: earned.badgeId) {
                let notification = Procedus.Notification(
                    userId: fellowId,
                    title: "Achievement Unlocked!",
                    message: "You earned the \"\(badge.title)\" badge!",
                    notificationType: NotificationType.badgeEarned.rawValue,
                    caseId: nil
                )
                modelContext.insert(notification)
            }
        }

        if !newBadges.isEmpty {
            try? modelContext.save()
        }
    }
    #endif
}

// MARK: - Admin Section Header

struct AdminSectionHeader: View {
    let title: String
    var icon: String? = nil
    var iconColor: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(iconColor)
            }

            Spacer()
        }
        .padding(.leading, 4)
        .padding(.top, 8)
    }
}

// MARK: - Admin Pill Row (matches SettingsPillRow)

struct AdminPillRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var badge: String? = nil
    var statusBadge: String? = nil
    var statusColor: Color = .green
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)

            // Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color(UIColor.label))

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Count badge (gray pill)
            if let badge = badge {
                Text(badge)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(Capsule())
            }

            // Status badge (colored pill)
            if let statusBadge = statusBadge {
                Text(statusBadge)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Chevron
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .contentShape(Rectangle())
    }
}

// MARK: - Admin Menu Row (legacy - kept for compatibility)

struct AdminMenuRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var badge: String? = nil
    var badgeColor: Color = .secondary
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(Color(UIColor.label))

            Spacer()

            if let badge = badge {
                Text(badge)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(badgeColor == .secondary ? .secondary : badgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeColor == .secondary ? Color(UIColor.tertiarySystemFill) : badgeColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Admin Stat Card

struct AdminStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(UIColor.label))

            Text(title)
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Procedure Counts View (New)

struct ProcedureCountsView: View {
    @Query private var allCases: [CaseEntry]
    @Query private var allUsers: [User]
    @Query(filter: #Predicate<Attending> { !$0.isArchived }) private var attendings: [Attending]
    @Query(filter: #Predicate<TrainingFacility> { !$0.isArchived }) private var facilities: [TrainingFacility]
    @Query(filter: #Predicate<CustomAccessSite> { !$0.isArchived }) private var customAccessSites: [CustomAccessSite]
    @Query(filter: #Predicate<CustomComplication> { !$0.isArchived }) private var customComplications: [CustomComplication]

    @State private var expandedProcedures: Set<String> = []

    private var fellows: [User] {
        allUsers.filter { $0.role == .fellow && !$0.hasGraduated }
    }

    private var procedureData: [(procedureId: String, procedureTitle: String, cases: [CaseEntry])] {
        var procCases: [String: (title: String, cases: [CaseEntry])] = [:]
        for caseEntry in allCases {
            for procedureId in caseEntry.procedureTagIds {
                let title = SpecialtyPackCatalog.findProcedureTitle(for: procedureId) ?? procedureId
                if procCases[procedureId] == nil {
                    procCases[procedureId] = (title: title, cases: [])
                }
                procCases[procedureId]?.cases.append(caseEntry)
            }
        }
        return procCases.map { (procedureId: $0.key, procedureTitle: $0.value.title, cases: $0.value.cases) }
            .sorted { $0.cases.count > $1.cases.count }
    }

    var body: some View {
        List {
            if procedureData.isEmpty {
                ContentUnavailableView(
                    "No Procedures",
                    systemImage: "list.clipboard",
                    description: Text("No procedures have been logged yet.")
                )
            } else {
                ForEach(procedureData, id: \.procedureId) { item in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedProcedures.contains(item.procedureId) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedProcedures.insert(item.procedureId)
                                } else {
                                    expandedProcedures.remove(item.procedureId)
                                }
                            }
                        )
                    ) {
                        ForEach(item.cases.sorted { $0.createdAt > $1.createdAt }) { caseEntry in
                            ProcedureCaseDetailRow(
                                caseEntry: caseEntry,
                                fellows: fellows,
                                attendings: attendings,
                                facilities: facilities,
                                customAccessSites: customAccessSites,
                                customComplications: customComplications
                            )
                        }
                    } label: {
                        HStack {
                            Text(item.procedureTitle)
                                .font(.subheadline)
                            Spacer()
                            Text("\(item.cases.count)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Procedure Counts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Procedure Case Detail Row (Read-Only)

private struct ProcedureCaseDetailRow: View {
    let caseEntry: CaseEntry
    let fellows: [User]
    let attendings: [Attending]
    let facilities: [TrainingFacility]
    let customAccessSites: [CustomAccessSite]
    let customComplications: [CustomComplication]

    private var fellowName: String {
        if let fellow = fellows.first(where: { $0.id == caseEntry.ownerId }) {
            return fellow.displayName
        }
        return "Unknown Fellow"
    }

    private var attendingName: String {
        guard let attendingId = caseEntry.attendingId else { return "Not assigned" }
        if let attending = attendings.first(where: { $0.id == attendingId }) {
            return attending.name
        }
        return "Unknown"
    }

    private var facilityName: String {
        guard let facilityId = caseEntry.facilityId else { return "Not specified" }
        if let facility = facilities.first(where: { $0.id == facilityId }) {
            return facility.name
        }
        return "Unknown"
    }

    private var accessSiteNames: [String] {
        caseEntry.accessSiteIds.compactMap { siteId in
            if let builtIn = AccessSite(rawValue: siteId) {
                return builtIn.rawValue
            } else if let custom = customAccessSites.first(where: { $0.id.uuidString == siteId }) {
                return custom.title
            }
            return nil
        }
    }

    private var complicationNames: [String] {
        caseEntry.complicationIds.compactMap { compId in
            if let builtIn = Complication(rawValue: compId) {
                return builtIn.rawValue
            } else if let custom = customComplications.first(where: { $0.id.uuidString == compId }) {
                return custom.title
            }
            return nil
        }
    }

    private var caseDate: String {
        caseEntry.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Fellow + Date
            HStack {
                Text(fellowName)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text(caseDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Attending & Facility
            HStack(spacing: 12) {
                Label(attendingName, systemImage: "person.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Label(facilityName, systemImage: "building.2.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Access Sites
            if !accessSiteNames.isEmpty {
                HStack {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(accessSiteNames.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Complications
            if !complicationNames.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(complicationNames.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            // Operator Position
            if let position = caseEntry.operatorPosition {
                HStack {
                    Image(systemName: "person.badge.key.fill")
                        .font(.caption2)
                        .foregroundColor(.purple)
                    Text(position.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Notes preview
            if let notes = caseEntry.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .italic()
            }
        }
        .padding(.vertical, 4)
        .padding(.leading, 8)
    }
}

// Keep old SettingsRow for backward compatibility
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var badge: String? = nil
    var badgeColor: Color = Color(UIColor.secondaryLabel)

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(iconColor)
                .cornerRadius(6)

            Text(title)
                .font(.subheadline)

            Spacer()

            if let badge = badge {
                Text(badge)
                    .font(.caption)
                    .foregroundColor(badgeColor)
            }
        }
    }
}

// Keep old StatCard for backward compatibility
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(UIColor.label))
            Text(title)
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Manage Program View

struct ManageProgramView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var programs: [Program]
    @Query private var allUsers: [User]
    @Query private var attendings: [Attending]
    @Query private var facilities: [TrainingFacility]
    @Query private var allCases: [CaseEntry]

    @State private var showingEditProgram = false
    @State private var showingCreateProgram = false
    @State private var selectedPackToView: SpecialtyPack?

    private var program: Program? { programs.first }

    private var activeFellowCount: Int {
        allUsers.filter { $0.role == .fellow && !$0.hasGraduated }.count
    }

    private var activeAttendingCount: Int {
        attendings.filter { !$0.isArchived }.count
    }

    private var activeFacilityCount: Int {
        facilities.filter { !$0.isArchived }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Program Details & Invite Codes Section (combined into one box)
                programDetailsAndInviteCodesSection

                // Settings Section
                settingsSection

                // Installed Specialty Packs Section (READ-ONLY)
                installedPacksSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Manage Program")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditProgram) {
            EditProgramSheet()
        }
        .sheet(isPresented: $showingCreateProgram) {
            CreateProgramSheet()
        }
        .sheet(item: $selectedPackToView) { pack in
            SpecialtyPackDetailView(pack: pack)
        }
    }

    // MARK: - Program Details & Invite Codes Section (Combined)

    private var programDetailsAndInviteCodesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Program Details")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                if let program = program {
                    // Program Name
                    ProgramDetailRow(label: "Program Name", value: program.name.isEmpty ? "Not Set" : program.name)
                    Divider().padding(.leading, 16)

                    // Institution
                    ProgramDetailRow(label: "Institution", value: program.institutionName.isEmpty ? "Not Set" : program.institutionName)
                    Divider().padding(.leading, 16)

                    // Program Specialty
                    HStack {
                        Text("Specialty")
                            .font(.body)
                            .foregroundColor(Color(UIColor.label))
                        Spacer()
                        if let specialty = program.fellowshipSpecialty {
                            Label(specialty.displayName, systemImage: specialty.iconName)
                                .font(.body)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not Set")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    Divider().padding(.leading, 16)

                    // Program Code (auto-generated)
                    ProgramCodeRow(label: "Program Code", code: program.programCode)
                    Divider().padding(.leading, 16)

                    // Edit Details Button (compact, right-aligned)
                    HStack {
                        Spacer()
                        Button { showingEditProgram = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                Text("Edit")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    Divider().padding(.leading, 16)

                    // Invite Codes Header
                    HStack {
                        Text("Invite Codes")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(UIColor.label))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.tertiarySystemBackground))

                    // Fellow Invite Code
                    InviteCodeRowNew(label: "Fellow Code", code: program.fellowInviteCode, color: .green) {
                        regenerateFellowCode()
                    }
                    Divider().padding(.leading, 16)

                    // Attending Invite Code
                    InviteCodeRowNew(label: "Attending Code", code: program.attendingInviteCode, color: .cyan) {
                        regenerateAttendingCode()
                    }
                    Divider().padding(.leading, 16)

                    // Admin Invite Code
                    InviteCodeRowNew(label: "Admin Code", code: program.adminInviteCode, color: .purple) {
                        regenerateAdminCode()
                    }
                } else {
                    // No program - show create option
                    VStack(spacing: 12) {
                        Image(systemName: "building.2.crop.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No Program Configured")
                            .font(.headline)
                            .foregroundColor(Color(UIColor.label))
                        Text("Create a program to get started with institutional features.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button { showingCreateProgram = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                Text("Create Program")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    .padding(24)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            if program != nil {
                Text("Tap the refresh icon to generate a new invite code. Old codes will no longer work.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                if let program = program {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Allow Comments")
                                .font(.body)
                                .foregroundColor(Color(UIColor.label))
                            Text("Fellows can add comments to cases")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { program.allowComments },
                            set: { program.allowComments = $0; program.updatedAt = Date() }
                        ))
                        .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider().padding(.leading, 16)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Require Attestation for Migrated Cases")
                                .font(.body)
                                .foregroundColor(Color(UIColor.label))
                            Text("Fellows migrating from individual mode must have cases attested")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { program.requireAttestationForMigratedCases },
                            set: { program.requireAttestationForMigratedCases = $0; program.updatedAt = Date() }
                        ))
                        .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider().padding(.leading, 16)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Training Program Length")
                                .font(.body)
                                .foregroundColor(Color(UIColor.label))
                            Text("Number of years in training (e.g., 3 for fellowship)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: Binding(
                            get: { program.trainingProgramLength },
                            set: { program.trainingProgramLength = $0; program.updatedAt = Date() }
                        )) {
                            ForEach(1...10, id: \.self) { years in
                                Text("\(years) year\(years == 1 ? "" : "s")").tag(years)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider().padding(.leading, 16)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Earliest PGY Level")
                                .font(.body)
                                .foregroundColor(Color(UIColor.label))
                            Text("First year of fellowship (e.g., PGY4 after 3-year residency)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: Binding(
                            get: { program.earliestPGYLevel },
                            set: { program.earliestPGYLevel = $0; program.updatedAt = Date() }
                        )) {
                            ForEach(1...10, id: \.self) { pgy in
                                Text("PGY\(pgy)").tag(pgy)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                StatisticRow(label: "Active Fellows", value: "\(activeFellowCount)")
                Divider().padding(.leading, 16)
                StatisticRow(label: "Active Attendings", value: "\(activeAttendingCount)")
                Divider().padding(.leading, 16)
                StatisticRow(label: "Training Facilities", value: "\(activeFacilityCount)")
                Divider().padding(.leading, 16)
                StatisticRow(label: "Total Cases", value: "\(allCases.count)")
                Divider().padding(.leading, 16)
                StatisticRow(label: "Specialty Packs", value: "\(program?.specialtyPackIds.count ?? 0)")
                Divider().padding(.leading, 16)
                StatisticRow(label: "Created", value: program?.createdAt.formatted(date: .abbreviated, time: .omitted) ?? "-")
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Installed Packs Section (READ-ONLY)

    private var installedPacksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Installed Specialty Packs")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                if let program = program, !program.specialtyPackIds.isEmpty {
                    ForEach(Array(program.specialtyPackIds.enumerated()), id: \.element) { index, packId in
                        if let pack = SpecialtyPackCatalog.pack(for: packId) {
                            Button {
                                selectedPackToView = pack
                            } label: {
                                HStack(spacing: 12) {
                                    // Short name badge
                                    Text(pack.shortName)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .background(packColor(for: index))
                                        .cornerRadius(8)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pack.name)
                                            .font(.body)
                                            .foregroundColor(Color(UIColor.label))
                                        Text("\(pack.categories.count) categories • \(procedureCount(for: pack)) procedures")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(UIColor.tertiaryLabel))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }

                            if index < program.specialtyPackIds.count - 1 {
                                Divider().padding(.leading, 60)
                            }
                        }
                    }
                } else {
                    Text("No specialty packs installed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(16)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            Text("Tap a specialty pack to view categories and procedures.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Helper Functions

    private func procedureCount(for pack: SpecialtyPack) -> Int {
        pack.categories.reduce(0) { $0 + $1.procedures.count }
    }

    private func packColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan, .indigo, .mint]
        return colors[index % colors.count]
    }

    private func regenerateFellowCode() {
        program?.fellowInviteCode = generateInviteCode()
        program?.updatedAt = Date()
        try? modelContext.save()
    }

    private func regenerateAttendingCode() {
        program?.attendingInviteCode = generateInviteCode()
        program?.updatedAt = Date()
        try? modelContext.save()
    }

    private func regenerateAdminCode() {
        program?.adminInviteCode = generateInviteCode()
        program?.updatedAt = Date()
        try? modelContext.save()
    }

    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

// MARK: - Program Detail Row

struct ProgramDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(Color(UIColor.label))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Program Code Row (with copy button)

struct ProgramCodeRow: View {
    let label: String
    let code: String

    @State private var copied = false

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
            Text(code)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(Color(UIColor.label))

            Button {
                UIPasteboard.general.string = code
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundColor(copied ? .green : .blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Invite Code Row (New Style)

struct InviteCodeRowNew: View {
    let label: String
    let code: String
    let color: Color
    let onRefresh: () -> Void

    @State private var copied = false

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(Color(UIColor.label))

            Spacer()

            Text(code)
                .font(.system(.body, design: .monospaced, weight: .semibold))
                .foregroundColor(color)

            Button {
                UIPasteboard.general.string = code
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundColor(copied ? .green : color)
            }

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Statistic Row

struct StatisticRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(Color(UIColor.label))
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Invite Code Row

struct InviteCodeRow: View {
    let label: String
    let code: String
    let color: Color

    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = code
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.label))
                Spacer()
                Text(code)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(color)
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(copied ? .green : Color(UIColor.tertiaryLabel))
            }
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Color(UIColor.secondaryLabel))
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Edit Program Sheet

struct EditProgramSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var programs: [Program]

    @State private var name = ""
    @State private var institutionName = ""
    @State private var selectedSpecialty: FellowshipSpecialty = .cardiology

    private var program: Program? { programs.first }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Program Name", text: $name)
                        .autocapitalization(.words)
                    TextField("Institution Name", text: $institutionName)
                        .autocapitalization(.words)
                } footer: {
                    Text("Enter your program and institution name.")
                }

                Section {
                    Picker("Program Specialty", selection: $selectedSpecialty) {
                        ForEach(FellowshipSpecialty.allCases) { specialty in
                            Label(specialty.displayName, systemImage: specialty.iconName)
                                .tag(specialty)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color(UIColor.label))
                } header: {
                    Text("Specialty")
                } footer: {
                    if selectedSpecialty.isCardiology {
                        Text("Will auto-enable: Interventional Cardiology, Electrophysiology, and Cardiac Imaging packs")
                    } else {
                        Text("Will auto-enable: \(selectedSpecialty.displayName) specialty pack")
                    }
                }

                // Show program code (read-only)
                if let program = program {
                    Section {
                        HStack {
                            Text("Program Code")
                            Spacer()
                            Text(program.programCode)
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                    } footer: {
                        Text("This code is auto-generated and cannot be changed.")
                    }
                }
            }
            .navigationTitle("Edit Program Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let program = program {
                    name = program.name
                    institutionName = program.institutionName
                    selectedSpecialty = program.fellowshipSpecialty ?? .cardiology
                }
            }
        }
    }

    private func save() {
        if let program = program {
            program.name = name.trimmingCharacters(in: .whitespaces)
            program.institutionName = institutionName.trimmingCharacters(in: .whitespaces)

            // Update specialty and auto-enable packs if specialty changed
            if program.fellowshipSpecialty != selectedSpecialty {
                program.fellowshipSpecialty = selectedSpecialty
                program.specialtyPackIds = selectedSpecialty.defaultPackIds
            }

            program.updatedAt = Date()
            try? modelContext.save()
        }
        dismiss()
    }
}

// MARK: - Create Program Sheet

struct CreateProgramSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var institutionName = ""
    @State private var selectedSpecialty: FellowshipSpecialty = .cardiology
    @State private var generatedCode = Program.generateProgramCode()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Program Name", text: $name)
                        .autocapitalization(.words)
                    TextField("Institution Name", text: $institutionName)
                        .autocapitalization(.words)
                } footer: {
                    Text("Enter your fellowship or residency program name and institution.")
                }

                Section {
                    Picker("Program Specialty", selection: $selectedSpecialty) {
                        ForEach(FellowshipSpecialty.allCases) { specialty in
                            Label(specialty.displayName, systemImage: specialty.iconName)
                                .tag(specialty)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .tint(Color(UIColor.label))
                } header: {
                    Text("Specialty")
                } footer: {
                    if selectedSpecialty.isCardiology {
                        Text("Will auto-enable: Interventional Cardiology, Electrophysiology, and Cardiac Imaging packs")
                    } else {
                        Text("Will auto-enable: \(selectedSpecialty.displayName) specialty pack")
                    }
                }

                Section {
                    HStack {
                        Text("Program Code")
                        Spacer()
                        Text(generatedCode)
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .monospaced))
                        Button {
                            generatedCode = Program.generateProgramCode()
                        } label: {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                } footer: {
                    Text("This code uniquely identifies your program. Tap refresh to generate a new one.")
                }
            }
            .navigationTitle("Create Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createProgram() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func createProgram() {
        let newProgram = Program(
            programCode: generatedCode,
            name: name.trimmingCharacters(in: .whitespaces),
            institutionName: institutionName.trimmingCharacters(in: .whitespaces),
            specialtyPackIds: selectedSpecialty.defaultPackIds
        )
        newProgram.fellowshipSpecialty = selectedSpecialty
        modelContext.insert(newProgram)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Specialty Pack Detail View

struct SpecialtyPackDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let pack: SpecialtyPack

    @State private var expandedCategories: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                packInfoSection
                categoriesSection
            }
            .navigationTitle(pack.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var packInfoSection: some View {
        Section {
            StatRow(label: "Short Name", value: pack.shortName)
            StatRow(label: "Type", value: pack.type.rawValue)
            StatRow(label: "Categories", value: "\(pack.categories.count)")
            let totalProcs = pack.categories.reduce(0) { $0 + $1.procedures.count }
            StatRow(label: "Total Procedures", value: "\(totalProcs)")
        }
    }

    private var categoriesSection: some View {
        Section {
            ForEach(pack.categories, id: \.category) { packCategory in
                categoryDisclosureGroup(for: packCategory)
            }
        } header: {
            Text("Categories & Procedures")
        }
    }

    private func categoryDisclosureGroup(for packCategory: PackCategory) -> some View {
        let categoryKey = packCategory.category.rawValue
        let isExpandedBinding = Binding<Bool>(
            get: { expandedCategories.contains(categoryKey) },
            set: { newValue in
                if newValue {
                    expandedCategories.insert(categoryKey)
                } else {
                    expandedCategories.remove(categoryKey)
                }
            }
        )

        return DisclosureGroup(isExpanded: isExpandedBinding) {
            ForEach(packCategory.procedures) { procedure in
                ProcedureDetailRow(procedure: procedure)
            }
        } label: {
            CategoryLabelRow(packCategory: packCategory)
        }
    }
}

// MARK: - Procedure Detail Row

private struct ProcedureDetailRow: View {
    let procedure: ProcedureTag

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(procedure.title)
                .font(.subheadline)
            if let subOptions = procedure.subOptions, !subOptions.isEmpty {
                Text("Options: \(subOptions.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Category Label Row

private struct CategoryLabelRow: View {
    let packCategory: PackCategory

    var body: some View {
        HStack {
            CategoryBubble(category: packCategory.category, size: 24)
            Text(packCategory.category.rawValue)
                .font(.subheadline)
            Spacer()
            Text("\(packCategory.procedures.count)")
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
    }
}

// MARK: - Specialty Pack Picker Sheet

struct SpecialtyPackPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var programs: [Program]

    @State private var selectedPackIds: Set<String> = []
    @State private var selectedPackToPreview: SpecialtyPack?

    private var program: Program? { programs.first }

    private var fellowshipPacks: [SpecialtyPack] {
        SpecialtyPackCatalog.packs(for: .fellowship)
    }

    private var residencyPacks: [SpecialtyPack] {
        SpecialtyPackCatalog.packs(for: .residency)
    }

    var body: some View {
        NavigationStack {
            List {
                // Fellowships Section
                Section {
                    ForEach(fellowshipPacks) { pack in
                        packRow(pack)
                    }
                } header: {
                    Text("Fellowships")
                }

                // Residencies Section
                Section {
                    ForEach(residencyPacks) { pack in
                        packRow(pack)
                    }
                } header: {
                    Text("Residencies")
                }
            }
            .navigationTitle("Specialty Packs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSelection()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Initialize with currently installed packs
                if let program = program {
                    selectedPackIds = Set(program.specialtyPackIds)
                }
            }
            .sheet(item: $selectedPackToPreview) { pack in
                SpecialtyPackPreviewSheet(pack: pack)
            }
        }
    }

    private func packRow(_ pack: SpecialtyPack) -> some View {
        HStack(spacing: 12) {
            // Selection circle
            Button {
                toggleSelection(pack)
            } label: {
                Image(systemName: selectedPackIds.contains(pack.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selectedPackIds.contains(pack.id) ? .blue : Color(UIColor.tertiaryLabel))
            }
            .buttonStyle(.plain)

            // Pack info - tappable to preview
            Button {
                selectedPackToPreview = pack
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.name)
                        .font(.body)
                        .foregroundColor(Color(UIColor.label))
                    Text("\(pack.categories.count) categories")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .contentShape(Rectangle())
    }

    private func toggleSelection(_ pack: SpecialtyPack) {
        if selectedPackIds.contains(pack.id) {
            selectedPackIds.remove(pack.id)
        } else {
            selectedPackIds.insert(pack.id)
        }
    }

    private func saveSelection() {
        guard let program = program else { return }
        program.specialtyPackIds = Array(selectedPackIds)
        program.updatedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Specialty Pack Preview Sheet (Read-only view of pack contents)

struct SpecialtyPackPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pack: SpecialtyPack

    var body: some View {
        NavigationStack {
            List {
                ForEach(pack.categories, id: \.category) { packCategory in
                    Section {
                        ForEach(packCategory.procedures) { procedure in
                            Text(procedure.title)
                                .font(.body)
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Text(packCategory.category.rawValue)
                            CategoryBubble(category: packCategory.category, size: 20)
                        }
                    }
                }
            }
            .navigationTitle(pack.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Fellow Management View

struct FellowManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allUsers: [User]
    @Query private var allCases: [CaseEntry]
    @Query private var programs: [Program]

    @State private var showingAddFellow = false
    @State private var selectedFellow: User?
    @State private var showingGraduateConfirm = false
    @State private var fellowToGraduate: User?
    @State private var selectedTab = 0  // 0 = Active, 1 = Graduated
    @State private var sortByPGY = true  // Default to sorting by PGY level

    private var currentProgram: Program? { programs.first }

    private var activeFellows: [User] {
        let fellows = allUsers.filter { $0.role == .fellow && !$0.hasGraduated }
        if sortByPGY {
            return fellows.sorted { ($0.trainingYear ?? 99) < ($1.trainingYear ?? 99) }
        } else {
            return fellows.sorted { $0.displayName < $1.displayName }
        }
    }

    private var fellowsByPGY: [(pgyYear: Int?, fellows: [User])] {
        let fellows = allUsers.filter { $0.role == .fellow && !$0.hasGraduated }
        let grouped = Dictionary(grouping: fellows) { $0.trainingYear }
        return grouped.sorted { ($0.key ?? 99) < ($1.key ?? 99) }
            .map { (pgyYear: $0.key, fellows: $0.value.sorted { $0.displayName < $1.displayName }) }
    }

    private var graduatedFellows: [User] {
        allUsers.filter { $0.role == .fellow && $0.hasGraduated }.sorted { $0.displayName < $1.displayName }
    }

    private func caseCount(for fellow: User) -> Int {
        allCases.filter { $0.fellowId == fellow.id || $0.ownerId == fellow.id }.count
    }

    private func procedureCount(for fellow: User) -> Int {
        allCases.filter { $0.fellowId == fellow.id || $0.ownerId == fellow.id }
            .reduce(0) { $0 + $1.procedureTagIds.count }
    }

    private func canDelete(fellow: User) -> Bool {
        caseCount(for: fellow) == 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Segmented Control
                Picker("View", selection: $selectedTab) {
                    Text("Active (\(activeFellows.count))").tag(0)
                    Text("Graduated (\(graduatedFellows.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                // Fellows List
                VStack(spacing: 0) {
                    if selectedTab == 0 {
                        // Active Fellows
                        if activeFellows.isEmpty {
                            emptyStateView(message: "No active fellows")
                        } else if sortByPGY {
                            // Grouped by PGY Year
                            VStack(spacing: 16) {
                                ForEach(fellowsByPGY, id: \.pgyYear) { group in
                                    VStack(alignment: .leading, spacing: 0) {
                                        // PGY Header
                                        Text(group.pgyYear != nil ? "PGY-\(group.pgyYear!)" : "Unassigned")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(Color(UIColor.secondaryLabel))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)

                                        // Fellows in this PGY group
                                        VStack(spacing: 0) {
                                            ForEach(Array(group.fellows.enumerated()), id: \.element.id) { index, fellow in
                                                Button {
                                                    selectedFellow = fellow
                                                } label: {
                                                    FellowRowNew(
                                                        fellow: fellow,
                                                        procedureCount: procedureCount(for: fellow)
                                                    )
                                                }
                                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                    if canDelete(fellow: fellow) {
                                                        Button(role: .destructive) {
                                                            modelContext.delete(fellow)
                                                            try? modelContext.save()
                                                        } label: {
                                                            Label("Delete", systemImage: "trash")
                                                        }
                                                    }
                                                    Button {
                                                        fellowToGraduate = fellow
                                                        showingGraduateConfirm = true
                                                    } label: {
                                                        Label("Graduate", systemImage: "graduationcap")
                                                    }
                                                    .tint(.blue)
                                                }

                                                if index < group.fellows.count - 1 {
                                                    Divider().padding(.leading, 16)
                                                }
                                            }
                                        }
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        } else {
                            // Sorted by name (flat list)
                            ForEach(Array(activeFellows.enumerated()), id: \.element.id) { index, fellow in
                                Button {
                                    selectedFellow = fellow
                                } label: {
                                    FellowRowNew(
                                        fellow: fellow,
                                        procedureCount: procedureCount(for: fellow)
                                    )
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if canDelete(fellow: fellow) {
                                        Button(role: .destructive) {
                                            modelContext.delete(fellow)
                                            try? modelContext.save()
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    Button {
                                        fellowToGraduate = fellow
                                        showingGraduateConfirm = true
                                    } label: {
                                        Label("Graduate", systemImage: "graduationcap")
                                    }
                                    .tint(.blue)
                                }

                                if index < activeFellows.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                    } else {
                        // Graduated Fellows
                        if graduatedFellows.isEmpty {
                            emptyStateView(message: "No graduated fellows")
                        } else {
                            ForEach(Array(graduatedFellows.enumerated()), id: \.element.id) { index, fellow in
                                Button {
                                    selectedFellow = fellow
                                } label: {
                                    FellowRowNew(
                                        fellow: fellow,
                                        procedureCount: procedureCount(for: fellow)
                                    )
                                }

                                if index < graduatedFellows.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Fellows")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    // Sort toggle
                    Menu {
                        Button {
                            sortByPGY = true
                        } label: {
                            Label("Sort by PGY Level", systemImage: sortByPGY ? "checkmark" : "")
                        }
                        Button {
                            sortByPGY = false
                        } label: {
                            Label("Sort by Name", systemImage: !sortByPGY ? "checkmark" : "")
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }

                    Button {
                        showingAddFellow = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddFellow) {
            AddEditFellowSheet(fellow: nil, maxTrainingYear: currentProgram?.trainingProgramLength ?? 10, earliestPGYLevel: currentProgram?.earliestPGYLevel ?? 4)
        }
        .sheet(item: $selectedFellow) { fellow in
            AddEditFellowSheet(fellow: fellow, maxTrainingYear: currentProgram?.trainingProgramLength ?? 10, earliestPGYLevel: currentProgram?.earliestPGYLevel ?? 4)
        }
        .alert("Graduate Fellow?", isPresented: $showingGraduateConfirm) {
            Button("Cancel", role: .cancel) { fellowToGraduate = nil }
            Button("Graduate") {
                if let fellow = fellowToGraduate {
                    fellow.hasGraduated = true
                    fellow.graduatedAt = Date()
                    fellow.trainingYear = nil  // Clear PGY year when graduated
                    fellow.updatedAt = Date()
                    try? modelContext.save()
                }
                fellowToGraduate = nil
            }
        } message: {
            if let fellow = fellowToGraduate {
                Text("Are you sure you want to graduate \(fellow.displayName)? They will no longer be able to log new cases.")
            }
        }
    }

    private func emptyStateView(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .italic()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }
}

// MARK: - Fellow Row (New Design)

struct FellowRowNew: View {
    let fellow: User
    let procedureCount: Int

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(fellow.displayName)
                        .font(.body)
                        .foregroundColor(Color(UIColor.label))

                    if fellow.hasGraduated {
                        HStack(spacing: 4) {
                            Image(systemName: "graduationcap.fill")
                                .font(.caption2)
                            Text("Graduated")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    } else if let year = fellow.trainingYear {
                        Text("PGY-\(year)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(UIColor.tertiarySystemFill))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            Text("\(procedureCount)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Fellow Row

struct FellowRow: View {
    let fellow: User
    let caseCount: Int
    let procedureCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(fellow.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if fellow.hasGraduated {
                    Image(systemName: "graduationcap.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Spacer()
                if let year = fellow.trainingYear {
                    Text("PGY-\(year)")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(UIColor.tertiarySystemFill))
                        .cornerRadius(4)
                }
            }
            Text("\(caseCount) cases, \(procedureCount) procedures")
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add/Edit Fellow Sheet

struct AddEditFellowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allCases: [CaseEntry]

    let fellow: User?
    let maxTrainingYear: Int
    let earliestPGYLevel: Int

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var trainingYear = 1
    @State private var showingGraduateConfirm = false
    @State private var showingUngraduateConfirm = false

    init(fellow: User?, maxTrainingYear: Int = 10, earliestPGYLevel: Int = 4) {
        self.fellow = fellow
        self.maxTrainingYear = maxTrainingYear
        self.earliestPGYLevel = earliestPGYLevel
        _trainingYear = State(initialValue: earliestPGYLevel)
    }

    private var totalCases: Int {
        guard let fellow = fellow else { return 0 }
        return allCases.filter { $0.fellowId == fellow.id || $0.ownerId == fellow.id }.count
    }

    private var totalProcedures: Int {
        guard let fellow = fellow else { return 0 }
        return allCases.filter { $0.fellowId == fellow.id || $0.ownerId == fellow.id }
            .reduce(0) { $0 + $1.procedureTagIds.count }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Fellow Information Section
                Section {
                    if fellow?.hasGraduated == true {
                        // Graduated fellows are view-only
                        HStack {
                            Text("Name")
                            Spacer()
                            Text("\(firstName) \(lastName)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(email.isEmpty ? "Not set" : email)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Status")
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "graduationcap.fill")
                                    .foregroundColor(.blue)
                                Text("Graduated")
                                    .foregroundColor(.blue)
                            }
                        }
                    } else {
                        TextField("First Name", text: $firstName)
                        TextField("Last Name", text: $lastName)
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        Picker("Training Year", selection: $trainingYear) {
                            ForEach(earliestPGYLevel...10, id: \.self) { year in
                                Text("PGY-\(year)").tag(year)
                            }
                        }
                    }
                } header: {
                    Text("Fellow Information")
                } footer: {
                    if fellow?.hasGraduated == true {
                        Text("Graduated fellows cannot be edited. Reinstate to make changes.")
                    } else {
                        Text("Email is required for the fellow to join the program with an invite code.")
                    }
                }

                // Statistics Section (only for existing fellows)
                if fellow != nil {
                    Section {
                        HStack {
                            Text("Total Cases")
                            Spacer()
                            Text("\(totalCases)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Total Procedures")
                            Spacer()
                            Text("\(totalProcedures)")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Statistics")
                    }

                    // Graduate/Ungraduate Section
                    Section {
                        if fellow?.hasGraduated == true {
                            Button {
                                showingUngraduateConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("Reinstate Fellow")
                                        .foregroundColor(.orange)
                                }
                            }
                        } else {
                            Button {
                                showingGraduateConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "graduationcap.fill")
                                        .foregroundColor(.green)
                                    Text("Graduate Fellow")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    } footer: {
                        if fellow?.hasGraduated == true {
                            Text("Reinstating a fellow will allow them to add new cases again.")
                        } else {
                            Text("Graduating a fellow will mark them as completed and they will no longer be able to add new cases.")
                        }
                    }
                }
            }
            .navigationTitle(fellow == nil ? "Add Fellow" : "Edit Fellow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(fellow?.hasGraduated == true ? "Done" : "Cancel") { dismiss() }
                }
                if fellow?.hasGraduated != true {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .disabled(firstName.isEmpty || lastName.isEmpty)
                    }
                }
            }
            .onAppear {
                if let fellow = fellow {
                    firstName = fellow.firstName
                    lastName = fellow.lastName
                    email = fellow.email
                    trainingYear = fellow.trainingYear ?? earliestPGYLevel
                }
            }
            .alert("Graduate Fellow?", isPresented: $showingGraduateConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Graduate") {
                    graduateFellow()
                }
            } message: {
                Text("Are you sure you want to graduate \(firstName) \(lastName)? They will no longer be able to log new cases.")
            }
            .alert("Reinstate Fellow?", isPresented: $showingUngraduateConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reinstate") {
                    reinstateFellow()
                }
            } message: {
                Text("Are you sure you want to reinstate \(firstName) \(lastName)? They will be able to log new cases again.")
            }
        }
    }

    private func save() {
        if let fellow = fellow {
            fellow.firstName = firstName
            fellow.lastName = lastName
            fellow.displayName = "\(firstName) \(lastName)"
            fellow.email = email
            fellow.trainingYear = trainingYear
            fellow.updatedAt = Date()
        } else {
            let newFellow = User(email: email, firstName: firstName, lastName: lastName, role: .fellow, trainingYear: trainingYear)
            modelContext.insert(newFellow)
        }
        try? modelContext.save()
        dismiss()
    }

    private func graduateFellow() {
        guard let fellow = fellow else { return }
        fellow.hasGraduated = true
        fellow.graduatedAt = Date()
        fellow.trainingYear = nil  // Clear PGY year when graduated
        fellow.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }

    private func reinstateFellow() {
        guard let fellow = fellow else { return }
        fellow.hasGraduated = false
        fellow.graduatedAt = nil
        fellow.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Attending Management View

struct AttendingManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var attendings: [Attending]
    @Query private var allCases: [CaseEntry]
    @Query private var allUsers: [User]

    @State private var showingAddAttending = false
    @State private var selectedAttending: Attending?
    @State private var selectedPlaceholder: Attending?
    @State private var selectedTab = 0  // 0 = Active, 1 = Pending, 2 = Archived

    private var activeAttendings: [Attending] {
        attendings.filter { !$0.isArchived && !$0.isPlaceholder }.sorted { $0.lastName < $1.lastName }
    }

    private var placeholderAttendings: [Attending] {
        attendings.filter { $0.isPlaceholder && !$0.isArchived && $0.mergedIntoId == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var archivedAttendings: [Attending] {
        attendings.filter { $0.isArchived }.sorted { $0.lastName < $1.lastName }
    }

    private func caseCount(for attending: Attending) -> Int {
        allCases.filter { $0.attendingId == attending.id }.count
    }

    private func canDelete(attending: Attending) -> Bool {
        caseCount(for: attending) == 0
    }

    private func creatorName(for attending: Attending) -> String {
        guard let fellowId = attending.createdByFellowId,
              let fellow = allUsers.first(where: { $0.id == fellowId }) else {
            return "Unknown"
        }
        return fellow.displayName
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Segmented Control
                Picker("View", selection: $selectedTab) {
                    Text("Active (\(activeAttendings.count))").tag(0)
                    if !placeholderAttendings.isEmpty {
                        Text("Pending (\(placeholderAttendings.count))").tag(1)
                    }
                    Text("Archived (\(archivedAttendings.count))").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                // Attendings List
                VStack(spacing: 0) {
                    if selectedTab == 0 {
                        // Active Attendings
                        if activeAttendings.isEmpty {
                            emptyStateView(message: "No active attendings")
                        } else {
                            ForEach(Array(activeAttendings.enumerated()), id: \.element.id) { index, attending in
                                Button {
                                    selectedAttending = attending
                                } label: {
                                    AttendingRowNew(
                                        attending: attending,
                                        caseCount: caseCount(for: attending)
                                    )
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if canDelete(attending: attending) {
                                        Button(role: .destructive) {
                                            modelContext.delete(attending)
                                            try? modelContext.save()
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    Button {
                                        attending.isArchived = true
                                        try? modelContext.save()
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }
                                    .tint(.orange)
                                }

                                if index < activeAttendings.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                    } else if selectedTab == 1 {
                        // Pending (Placeholder) Attendings
                        if placeholderAttendings.isEmpty {
                            emptyStateView(message: "No pending attendings")
                        } else {
                            ForEach(Array(placeholderAttendings.enumerated()), id: \.element.id) { index, attending in
                                Button {
                                    selectedPlaceholder = attending
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(attending.name)
                                                    .font(.body)
                                                    .foregroundColor(Color(UIColor.label))

                                                Text("Pending")
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.orange.opacity(0.15))
                                                    .foregroundColor(.orange)
                                                    .cornerRadius(4)
                                            }

                                            Text("Added by \(creatorName(for: attending)) · \(caseCount(for: attending)) cases")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Color(UIColor.tertiaryLabel))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }

                                if index < placeholderAttendings.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                    } else {
                        // Archived Attendings
                        if archivedAttendings.isEmpty {
                            emptyStateView(message: "No archived attendings")
                        } else {
                            ForEach(Array(archivedAttendings.enumerated()), id: \.element.id) { index, attending in
                                Button {
                                    selectedAttending = attending
                                } label: {
                                    AttendingRowNew(
                                        attending: attending,
                                        caseCount: caseCount(for: attending),
                                        isArchived: true
                                    )
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        attending.isArchived = false
                                        try? modelContext.save()
                                    } label: {
                                        Label("Restore", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.green)
                                }

                                if index < archivedAttendings.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Attendings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddAttending = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAddAttending) {
            AdminAddEditAttendingSheet(attending: nil)
        }
        .sheet(item: $selectedAttending) { attending in
            AdminAddEditAttendingSheet(attending: attending)
        }
        .sheet(item: $selectedPlaceholder) { placeholder in
            PlaceholderAttendingMergeSheet(placeholder: placeholder)
        }
    }

    private func emptyStateView(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .italic()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }
}

// MARK: - Attending Row (New Design)

struct AttendingRowNew: View {
    let attending: Attending
    let caseCount: Int
    var isArchived: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text(attending.name)
                    .font(.body)
                    .foregroundColor(Color(UIColor.label))

                if attending.isPlaceholder {
                    Text("Pending")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }

            Spacer()

            Text("\(caseCount)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Placeholder Attending Merge Sheet

struct PlaceholderAttendingMergeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let placeholder: Attending

    @Query private var allAttendings: [Attending]
    @Query private var allCases: [CaseEntry]
    @Query private var allNotifications: [Notification]
    @Query private var allUsers: [User]

    @State private var createNewOfficial = true
    @State private var selectedOfficialId: UUID?
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var enableLogin = true
    @State private var showingConfirmation = false
    @State private var isMerging = false

    private var officialAttendings: [Attending] {
        allAttendings.filter { !$0.isPlaceholder && !$0.isArchived }
            .sorted { $0.lastName < $1.lastName }
    }

    private var casesToMigrate: [CaseEntry] {
        allCases.filter { $0.attendingId == placeholder.id || $0.supervisorId == placeholder.id }
    }

    private var canMerge: Bool {
        if createNewOfficial {
            return !firstName.trimmingCharacters(in: .whitespaces).isEmpty ||
                   !lastName.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return selectedOfficialId != nil
        }
    }

    private func creatorName() -> String {
        guard let fellowId = placeholder.createdByFellowId,
              let fellow = allUsers.first(where: { $0.id == fellowId }) else {
            return "Unknown"
        }
        return fellow.displayName
    }

    var body: some View {
        NavigationStack {
            Form {
                // Placeholder Info Section
                Section {
                    LabeledContent("Name", value: placeholder.name)
                    LabeledContent("Cases", value: "\(casesToMigrate.count)")
                    LabeledContent("Added by", value: creatorName())
                    LabeledContent("Created", value: placeholder.createdAt.formatted(date: .abbreviated, time: .omitted))
                } header: {
                    Text("Placeholder Attending")
                }

                // Action Section
                Section {
                    Picker("Action", selection: $createNewOfficial) {
                        Text("Create Official Account").tag(true)
                        Text("Link to Existing").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                if createNewOfficial {
                    // Create new official attending
                    Section {
                        TextField("First Name", text: $firstName)
                            .textInputAutocapitalization(.words)
                        TextField("Last Name", text: $lastName)
                            .textInputAutocapitalization(.words)
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        Toggle("Enable Login Access", isOn: $enableLogin)
                    } header: {
                        Text("Official Account Details")
                    } footer: {
                        Text("This will create the official attending account and migrate all \(casesToMigrate.count) case(s).")
                    }
                } else {
                    // Link to existing attending
                    Section {
                        if officialAttendings.isEmpty {
                            Text("No official attendings available")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            Picker("Link To", selection: $selectedOfficialId) {
                                Text("Select Attending").tag(nil as UUID?)
                                ForEach(officialAttendings) { attending in
                                    Text(attending.name).tag(attending.id as UUID?)
                                }
                            }
                        }
                    } header: {
                        Text("Select Existing Attending")
                    } footer: {
                        Text("All \(casesToMigrate.count) case(s) will be migrated to the selected attending.")
                    }
                }

                // Preview Section
                if !casesToMigrate.isEmpty {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.blue)
                            Text("\(casesToMigrate.count) case(s) will be migrated")
                                .font(.subheadline)
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.orange)
                            Text("Attestation notifications will be created")
                                .font(.subheadline)
                        }
                    } header: {
                        Text("Migration Preview")
                    }
                }
            }
            .navigationTitle("Setup Official Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isMerging)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Merge") {
                        showingConfirmation = true
                    }
                    .disabled(!canMerge || isMerging)
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Confirm Migration", isPresented: $showingConfirmation, titleVisibility: .visible) {
                Button("Migrate \(casesToMigrate.count) Case(s)") {
                    performMerge()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will migrate all cases from '\(placeholder.name)' to the official account. This action cannot be undone.")
            }
            .onAppear {
                firstName = placeholder.firstName
                lastName = placeholder.lastName
            }
            .overlay {
                if isMerging {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Migrating cases...")
                                .font(.headline)
                        }
                        .padding(32)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(16)
                    }
                }
            }
        }
    }

    private func performMerge() {
        isMerging = true

        let targetAttendingId: UUID

        if createNewOfficial {
            // Create new official attending
            let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
            let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)
            let official = Attending(
                firstName: trimmedFirst,
                lastName: trimmedLast,
                programId: placeholder.programId
            )
            modelContext.insert(official)

            if enableLogin && !email.trimmingCharacters(in: .whitespaces).isEmpty {
                let newUser = User(
                    email: email.trimmingCharacters(in: .whitespaces),
                    firstName: trimmedFirst,
                    lastName: trimmedLast,
                    role: .attending,
                    accountMode: .institutional,
                    programId: placeholder.programId
                )
                modelContext.insert(newUser)
                official.userId = newUser.id
            }

            targetAttendingId = official.id
        } else {
            targetAttendingId = selectedOfficialId!
        }

        // Migrate all cases
        for caseEntry in casesToMigrate {
            if caseEntry.attendingId == placeholder.id {
                caseEntry.attendingId = targetAttendingId
            }
            if caseEntry.supervisorId == placeholder.id {
                caseEntry.supervisorId = targetAttendingId
            }
        }

        // Clear old notifications for placeholder
        let oldNotifications = allNotifications.filter { $0.attendingId == placeholder.id }
        for notification in oldNotifications {
            notification.isCleared = true
            notification.autoCleared = true
            notification.autoClearReason = "Attending migrated to official account"
            notification.clearedAt = Date()
        }

        // Create new notifications for pending cases
        let pendingCases = casesToMigrate.filter {
            $0.attestationStatusRaw == AttestationStatus.pending.rawValue ||
            $0.attestationStatusRaw == AttestationStatus.requested.rawValue
        }

        for caseEntry in pendingCases {
            let notification = Notification(
                userId: targetAttendingId,
                title: "Case Pending Attestation",
                message: "A case has been migrated to your account and requires attestation.",
                notificationType: NotificationType.attestationRequested.rawValue,
                caseId: caseEntry.id,
                attendingId: targetAttendingId
            )
            modelContext.insert(notification)
        }

        // Mark placeholder as merged
        placeholder.mergedIntoId = targetAttendingId
        placeholder.mergedAt = Date()
        placeholder.isArchived = true

        do {
            try modelContext.save()
        } catch {
            print("Failed to save merge: \(error)")
        }

        isMerging = false
        dismiss()
    }
}

// MARK: - Admin Add/Edit Attending Sheet

struct AdminAddEditAttendingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allCases: [CaseEntry]
    @Query private var allUsers: [User]

    let attending: Attending?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var enableLogin = true  // Creates User record for login

    // Find linked User if exists
    private var linkedUser: User? {
        guard let attending = attending, let userId = attending.userId else { return nil }
        return allUsers.first { $0.id == userId }
    }

    private var totalCases: Int {
        guard let attending = attending else { return 0 }
        return allCases.filter { $0.attendingId == attending.id }.count
    }

    private var totalProcedures: Int {
        guard let attending = attending else { return 0 }
        return allCases.filter { $0.attendingId == attending.id }
            .reduce(0) { $0 + $1.procedureTagIds.count }
    }

    private var canBeDeleted: Bool {
        totalCases == 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Attending Information Section
                Section {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                } header: {
                    Text("Attending Information")
                } footer: {
                    Text("Email is required for the attending to join the program with an invite code.")
                }

                // Login Access Section
                Section {
                    Toggle("Enable Login Access", isOn: $enableLogin)
                } footer: {
                    if enableLogin {
                        Text("This attending will be able to log in using the attending invite code and access the attestation queue.")
                    } else {
                        Text("This attending will only appear in the supervisor dropdown for cases.")
                    }
                }

                // Statistics Section (only for existing attendings)
                if attending != nil {
                    Section {
                        HStack {
                            Text("Total Cases")
                            Spacer()
                            Text("\(totalCases)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Total Procedures")
                            Spacer()
                            Text("\(totalProcedures)")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Statistics")
                    }

                    // Archive/Delete Section
                    if attending?.isArchived == false {
                        Section {
                            // Show delete button if no cases
                            if canBeDeleted {
                                Button(role: .destructive) {
                                    deleteAttending()
                                } label: {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                        Text("Delete Attending")
                                    }
                                }
                            }

                            // Always show archive option
                            Button {
                                archiveAttending()
                            } label: {
                                HStack {
                                    Image(systemName: "archivebox.fill")
                                        .foregroundColor(.orange)
                                    Text("Archive Attending")
                                        .foregroundColor(.orange)
                                }
                            }
                        } footer: {
                            if canBeDeleted {
                                Text("This attending has no cases and can be deleted or archived.")
                            } else {
                                Text("This attending has \(totalCases) case(s) and can only be archived, not deleted.")
                            }
                        }
                    } else {
                        Section {
                            Button {
                                unarchiveAttending()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Restore Attending")
                                        .foregroundColor(.green)
                                }
                            }
                        } footer: {
                            Text("Restoring will make this attending available for selection again.")
                        }
                    }
                }
            }
            .navigationTitle(attending == nil ? "Add Attending" : "Edit Attending")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(firstName.isEmpty && lastName.isEmpty)
                }
            }
            .onAppear {
                if let attending = attending {
                    firstName = attending.firstName
                    lastName = attending.lastName
                    // Load email from linked user if exists
                    if let user = linkedUser {
                        email = user.email
                        enableLogin = true
                    } else {
                        enableLogin = attending.userId != nil
                    }
                }
            }
        }
    }

    private func save() {
        if let attending = attending {
            // Update existing attending
            attending.firstName = firstName
            attending.lastName = lastName
            attending.name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)

            // Update or create linked user
            if enableLogin {
                if let user = linkedUser {
                    // Update existing user
                    user.firstName = firstName
                    user.lastName = lastName
                    user.displayName = "\(firstName) \(lastName)"
                    user.email = email
                    user.updatedAt = Date()
                } else {
                    // Create new user and link
                    let newUser = User(email: email, firstName: firstName, lastName: lastName, role: .attending)
                    modelContext.insert(newUser)
                    attending.userId = newUser.id
                }
            } else if let user = linkedUser {
                // Remove login access - archive the user
                user.isArchived = true
                attending.userId = nil
            }
        } else {
            // Create new attending
            let newAttending = Attending(firstName: firstName, lastName: lastName)
            modelContext.insert(newAttending)

            // Create user for login if enabled
            if enableLogin && !email.isEmpty {
                let newUser = User(email: email, firstName: firstName, lastName: lastName, role: .attending)
                modelContext.insert(newUser)
                newAttending.userId = newUser.id
            }
        }
        try? modelContext.save()
        dismiss()
    }

    private func archiveAttending() {
        guard let attending = attending else { return }
        attending.isArchived = true
        try? modelContext.save()
        dismiss()
    }

    private func unarchiveAttending() {
        guard let attending = attending else { return }
        attending.isArchived = false
        try? modelContext.save()
        dismiss()
    }

    private func deleteAttending() {
        guard let attending = attending else { return }
        modelContext.delete(attending)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Facility Management View

struct FacilityManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var facilities: [TrainingFacility]
    @Query private var allCases: [CaseEntry]

    @State private var showingAddFacility = false
    @State private var selectedFacility: TrainingFacility?
    @State private var selectedTab = 0  // 0 = Active, 1 = Archived

    private var activeFacilities: [TrainingFacility] {
        facilities.filter { !$0.isArchived }.sorted { $0.name < $1.name }
    }

    private var archivedFacilities: [TrainingFacility] {
        facilities.filter { $0.isArchived }.sorted { $0.name < $1.name }
    }

    private func caseCount(for facility: TrainingFacility) -> Int {
        allCases.filter { $0.facilityId == facility.id }.count
    }

    private func canDelete(facility: TrainingFacility) -> Bool {
        caseCount(for: facility) == 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Segmented Control
                Picker("View", selection: $selectedTab) {
                    Text("Active (\(activeFacilities.count))").tag(0)
                    Text("Archived (\(archivedFacilities.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                // Facilities List
                VStack(spacing: 0) {
                    if selectedTab == 0 {
                        // Active Facilities
                        if activeFacilities.isEmpty {
                            emptyStateView(message: "No active facilities")
                        } else {
                            ForEach(Array(activeFacilities.enumerated()), id: \.element.id) { index, facility in
                                Button {
                                    selectedFacility = facility
                                } label: {
                                    FacilityRowNew(
                                        facility: facility,
                                        caseCount: caseCount(for: facility)
                                    )
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if canDelete(facility: facility) {
                                        Button(role: .destructive) {
                                            modelContext.delete(facility)
                                            try? modelContext.save()
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    Button {
                                        facility.isArchived = true
                                        try? modelContext.save()
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }
                                    .tint(.orange)
                                }

                                if index < activeFacilities.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                    } else {
                        // Archived Facilities
                        if archivedFacilities.isEmpty {
                            emptyStateView(message: "No archived facilities")
                        } else {
                            ForEach(Array(archivedFacilities.enumerated()), id: \.element.id) { index, facility in
                                Button {
                                    selectedFacility = facility
                                } label: {
                                    FacilityRowNew(
                                        facility: facility,
                                        caseCount: caseCount(for: facility),
                                        isArchived: true
                                    )
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        facility.isArchived = false
                                        try? modelContext.save()
                                    } label: {
                                        Label("Restore", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.green)
                                }

                                if index < archivedFacilities.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Facilities")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddFacility = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAddFacility) {
            AdminAddEditFacilitySheet(facility: nil)
        }
        .sheet(item: $selectedFacility) { facility in
            AdminAddEditFacilitySheet(facility: facility)
        }
    }

    private func emptyStateView(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .italic()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }
}

// MARK: - Facility Row (New Design)

struct FacilityRowNew: View {
    let facility: TrainingFacility
    let caseCount: Int
    var isArchived: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(facility.name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIColor.label))

                if let shortName = facility.shortName, !shortName.isEmpty {
                    Text(shortName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text("\(caseCount) cases")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Admin Add/Edit Facility Sheet

struct AdminAddEditFacilitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allCases: [CaseEntry]

    let facility: TrainingFacility?

    @State private var name = ""
    @State private var shortName = ""

    private var totalCases: Int {
        guard let facility = facility else { return 0 }
        return allCases.filter { $0.facilityId == facility.id }.count
    }

    private var totalProcedures: Int {
        guard let facility = facility else { return 0 }
        return allCases.filter { $0.facilityId == facility.id }
            .reduce(0) { $0 + $1.procedureTagIds.count }
    }

    private var canBeDeleted: Bool {
        totalCases == 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Facility Information Section
                Section {
                    TextField("Facility Name", text: $name)
                    TextField("Short Name (e.g. TMC)", text: $shortName)
                } header: {
                    Text("Facility Information")
                }

                // Statistics Section (only for existing facilities)
                if facility != nil {
                    Section {
                        HStack {
                            Text("Total Cases")
                            Spacer()
                            Text("\(totalCases)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Total Procedures")
                            Spacer()
                            Text("\(totalProcedures)")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Statistics")
                    }

                    // Archive/Restore Section
                    if facility?.isArchived == false {
                        Section {
                            Button {
                                archiveFacility()
                            } label: {
                                HStack {
                                    Image(systemName: "archivebox.fill")
                                        .foregroundColor(.orange)
                                    Text("Archive Facility")
                                        .foregroundColor(.orange)
                                }
                            }
                        } footer: {
                            if canBeDeleted {
                                Text("This facility has no cases and can be archived or deleted.")
                            } else {
                                Text("This facility has \(totalCases) case(s) and can only be archived, not deleted.")
                            }
                        }
                    } else {
                        Section {
                            Button {
                                unarchiveFacility()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Restore Facility")
                                        .foregroundColor(.green)
                                }
                            }
                        } footer: {
                            Text("Restoring will make this facility available for selection again.")
                        }
                    }
                }
            }
            .navigationTitle(facility == nil ? "Add Facility" : "Edit Facility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || shortName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let facility = facility {
                    name = facility.name
                    shortName = facility.shortName ?? ""
                }
            }
        }
    }

    private func save() {
        if let facility = facility {
            facility.name = name
            facility.shortName = shortName.isEmpty ? nil : shortName
        } else {
            let newFacility = TrainingFacility(name: name, shortName: shortName.isEmpty ? nil : shortName)
            modelContext.insert(newFacility)
        }
        try? modelContext.save()
        dismiss()
    }

    private func archiveFacility() {
        guard let facility = facility else { return }
        facility.isArchived = true
        try? modelContext.save()
        dismiss()
    }

    private func unarchiveFacility() {
        guard let facility = facility else { return }
        facility.isArchived = false
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Manage Procedures View

struct ManageProceduresView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var programs: [Program]
    @Query private var customCategories: [CustomCategory]
    @Query private var customProcedures: [CustomProcedure]
    @Query private var customAccessSites: [CustomAccessSite]
    @Query private var customComplications: [CustomComplication]
    @Query private var allCases: [CaseEntry]

    @State private var showingAddCategory = false
    @State private var showingAddProcedure = false
    @State private var showingAddSpecialtyPack = false
    @State private var showingAddAccessSite = false
    @State private var showingAddComplication = false
    @State private var selectedCategory: CustomCategory?
    @State private var selectedProcedure: CustomProcedure?
    @State private var selectedPackToView: SpecialtyPack?
    @State private var selectedAccessSite: CustomAccessSite?
    @State private var selectedComplication: CustomComplication?

    private var program: Program? { programs.first }

    // Check if any installed specialty pack has access sites
    private var hasAccessSitesInPacks: Bool {
        guard let program = program else { return false }
        for packId in program.specialtyPackIds {
            if let pack = SpecialtyPackCatalog.pack(for: packId) {
                if !pack.defaultAccessSites.isEmpty {
                    return true
                }
            }
        }
        return false
    }

    private var activeAccessSites: [CustomAccessSite] {
        customAccessSites.filter { !$0.isArchived }.sorted { $0.title < $1.title }
    }

    private var activeComplications: [CustomComplication] {
        customComplications.filter { !$0.isArchived }.sorted { $0.title < $1.title }
    }

    // Check if any installed specialty pack has complications
    private var hasComplicationsInPacks: Bool {
        guard let program = program else { return false }
        for packId in program.specialtyPackIds {
            if let pack = SpecialtyPackCatalog.pack(for: packId) {
                if !pack.defaultComplications.isEmpty {
                    return true
                }
            }
        }
        return false
    }

    private var activeCategories: [CustomCategory] {
        customCategories.filter { !$0.isArchived }.sorted { $0.name < $1.name }
    }

    private var activeProcedures: [CustomProcedure] {
        customProcedures.filter { !$0.isArchived }.sorted { $0.title < $1.title }
    }

    private func isProcedureUsed(_ procedure: CustomProcedure) -> Bool {
        allCases.contains { $0.procedureTagIds.contains(procedure.tagId) }
    }

    private func isCategoryUsed(_ category: CustomCategory) -> Bool {
        customProcedures.contains { $0.customCategoryId == category.id }
    }

    private func isComplicationUsed(_ complication: CustomComplication) -> Bool {
        allCases.contains { $0.complicationIds.contains(complication.id.uuidString) }
    }

    private func procedureCount(for pack: SpecialtyPack) -> Int {
        pack.categories.reduce(0) { $0 + $1.procedures.count }
    }

    private func categoryProcedureCount(for category: CustomCategory) -> Int {
        customProcedures.filter { $0.customCategoryId == category.id && !$0.isArchived }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Specialty Packs Section
                specialtyPacksSection

                // Custom Categories Section
                customCategoriesSection

                // Admin Custom Procedures Section
                adminProceduresSection

                // Custom Access Sites Section (only if packs have access sites)
                if hasAccessSitesInPacks {
                    customAccessSitesSection
                }

                // Custom Complications Section (only if packs have complications)
                if hasComplicationsInPacks {
                    customComplicationsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Manage Procedures")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAddSpecialtyPack) {
            SpecialtyPackPickerSheet()
        }
        .sheet(isPresented: $showingAddCategory) {
            AddEditCustomCategorySheet(category: nil)
        }
        .sheet(item: $selectedCategory) { category in
            CustomCategoryDetailSheet(category: category)
        }
        .sheet(isPresented: $showingAddProcedure) {
            AddEditCustomProcedureSheet(procedure: nil)
        }
        .sheet(item: $selectedProcedure) { procedure in
            AddEditCustomProcedureSheet(procedure: procedure)
        }
        .sheet(item: $selectedPackToView) { pack in
            SpecialtyPackDetailView(pack: pack)
        }
        .sheet(isPresented: $showingAddAccessSite) {
            AddEditCustomAccessSiteSheet(accessSite: nil)
        }
        .sheet(item: $selectedAccessSite) { site in
            AddEditCustomAccessSiteSheet(accessSite: site)
        }
        .sheet(isPresented: $showingAddComplication) {
            AddEditCustomComplicationSheet(complication: nil)
        }
        .sheet(item: $selectedComplication) { complication in
            AddEditCustomComplicationSheet(complication: complication)
        }
    }

    // MARK: - Specialty Packs Section

    private var specialtyPacksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Specialty Packs")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                if let program = program, !program.specialtyPackIds.isEmpty {
                    ForEach(Array(program.specialtyPackIds.enumerated()), id: \.element) { index, packId in
                        if let pack = SpecialtyPackCatalog.pack(for: packId) {
                            Button {
                                selectedPackToView = pack
                            } label: {
                                HStack {
                                    Text(pack.name)
                                        .font(.body)
                                        .foregroundColor(Color(UIColor.label))
                                    Spacer()
                                    Text("\(procedureCount(for: pack)) procedures")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(UIColor.tertiaryLabel))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }

                            if index < program.specialtyPackIds.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }

                    Divider().padding(.leading, 16)
                }

                Button { showingAddSpecialtyPack = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                        Text("Add Specialty Pack")
                            .font(.body)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            Text("Specialty packs define available procedures. Swipe left to remove.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Custom Categories Section

    private var customCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Categories")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                if !activeCategories.isEmpty {
                    ForEach(Array(activeCategories.enumerated()), id: \.element.id) { index, category in
                        Button {
                            selectedCategory = category
                        } label: {
                            HStack {
                                CustomCategoryBubble(category: category, size: 24)
                                Text(category.name)
                                    .font(.body)
                                    .foregroundColor(Color(UIColor.label))
                                Spacer()
                                Text("\(categoryProcedureCount(for: category)) procedures")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        if index < activeCategories.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }

                    Divider().padding(.leading, 16)
                }

                Button { showingAddCategory = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                        Text("Create Custom Category")
                            .font(.body)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            Text("Custom categories are available to all fellows throughout the program. Categories with procedures or used in cases cannot be deleted.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Admin Custom Procedures Section

    private var adminProceduresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Admin Custom Procedures")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                if !activeProcedures.isEmpty {
                    ForEach(Array(activeProcedures.enumerated()), id: \.element.id) { index, procedure in
                        Button {
                            selectedProcedure = procedure
                        } label: {
                            HStack {
                                Text(procedure.title)
                                    .font(.body)
                                    .foregroundColor(Color(UIColor.label))
                                Spacer()
                                Text(procedure.categoryRaw ?? "Uncategorized")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        if index < activeProcedures.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }

                    Divider().padding(.leading, 16)
                }

                Button { showingAddProcedure = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                        Text("Create Custom Procedure")
                            .font(.body)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            Text("These procedures are available to all fellows.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Custom Access Sites Section

    private var customAccessSitesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Access Sites")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                if !activeAccessSites.isEmpty {
                    ForEach(Array(activeAccessSites.enumerated()), id: \.element.id) { index, site in
                        Button {
                            selectedAccessSite = site
                        } label: {
                            HStack {
                                Text(site.title)
                                    .font(.body)
                                    .foregroundColor(Color(UIColor.label))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        if index < activeAccessSites.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }

                    Divider().padding(.leading, 16)
                }

                Button { showingAddAccessSite = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                        Text("Add Custom Access Site")
                            .font(.body)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            Text("Custom access sites are available when logging cases. They will appear alongside the default access sites from your specialty packs.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Custom Complications Section

    private var customComplicationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Complications")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                if !activeComplications.isEmpty {
                    ForEach(Array(activeComplications.enumerated()), id: \.element.id) { index, complication in
                        Button {
                            selectedComplication = complication
                        } label: {
                            HStack {
                                Text(complication.title)
                                    .font(.body)
                                    .foregroundColor(Color(UIColor.label))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        if index < activeComplications.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }

                    Divider().padding(.leading, 16)
                }

                Button { showingAddComplication = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                        Text("Add Custom Complication")
                            .font(.body)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            Text("Custom complications are available when logging cases. They will appear alongside the default complications from your specialty packs.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private func removeSpecialtyPack(_ packId: String) {
        guard let program = program else { return }
        program.specialtyPackIds.removeAll { $0 == packId }
        program.updatedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Custom Category Detail Sheet

struct CustomCategoryDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var customProcedures: [CustomProcedure]

    let category: CustomCategory

    private var proceduresInCategory: [CustomProcedure] {
        customProcedures.filter { $0.customCategoryId == category.id && !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            List {
                if proceduresInCategory.isEmpty {
                    Text("No procedures in this category")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(proceduresInCategory) { procedure in
                        Text(procedure.title)
                            .font(.body)
                    }
                }
            }
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Custom Category Bubble

struct CustomCategoryBubble: View {
    let category: CustomCategory
    let size: CGFloat

    var body: some View {
        Text(category.letter)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(category.color)
            .clipShape(Circle())
    }
}

// MARK: - Add/Edit Custom Category Sheet

struct AddEditCustomCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let category: CustomCategory?

    @State private var name = ""
    @State private var letter = "A"
    @State private var selectedColorHex = "#FF6B6B"

    private let availableColors = CustomCategory.availableColors
    private let availableLetters = CustomCategory.availableLetters

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category Name", text: $name)
                }

                Section {
                    Picker("Letter", selection: $letter) {
                        ForEach(availableLetters, id: \.self) { letter in
                            Text(letter).tag(letter)
                        }
                    }
                } header: {
                    Text("Bubble Letter")
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(availableColors, id: \.self) { colorHex in
                            Button {
                                selectedColorHex = colorHex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: colorHex) ?? .gray)
                                        .frame(width: 44, height: 44)
                                    if selectedColorHex == colorHex {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 3)
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Bubble Color")
                }

                Section {
                    HStack {
                        Spacer()
                        Text(letter)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Color(hex: selectedColorHex) ?? .gray)
                            .clipShape(Circle())
                        Spacer()
                    }
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle(category == nil ? "Add Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let category = category {
                    name = category.name
                    letter = category.letter
                    selectedColorHex = category.colorHex
                }
            }
        }
    }

    private func save() {
        if let category = category {
            category.name = name
            category.letter = letter
            category.colorHex = selectedColorHex
        } else {
            let newCategory = CustomCategory(name: name, letter: letter, colorHex: selectedColorHex)
            modelContext.insert(newCategory)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Add/Edit Custom Procedure Sheet

struct AddEditCustomProcedureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var programs: [Program]
    @Query private var customCategories: [CustomCategory]

    let procedure: CustomProcedure?

    @State private var title = ""
    // Combined selection - either a pack category string or "custom:UUID" for custom categories
    @State private var selectedCategoryKey: String = ""

    private var program: Program? { programs.first }

    private var activeCustomCategories: [CustomCategory] {
        customCategories.filter { !$0.isArchived }
    }

    // Structure to hold pack name and its categories
    private struct PackWithCategories: Identifiable, PackWithCategoriesProtocol {
        let id: String
        let name: String
        let categories: [ProcedureCategory]

        var packName: String { name }
    }

    // Get categories grouped by specialty pack
    private var categoriesByPack: [PackWithCategories] {
        guard let program = program else { return [] }
        var result: [PackWithCategories] = []

        for packId in program.specialtyPackIds {
            if let pack = SpecialtyPackCatalog.pack(for: packId) {
                let categories = pack.categories.map { $0.category }
                result.append(PackWithCategories(id: packId, name: pack.name, categories: categories))
            }
        }
        return result
    }

    // Check if any pack categories exist
    private var hasPackCategories: Bool {
        !categoriesByPack.isEmpty
    }

    // Check if a selection is a custom category
    private var isCustomCategorySelected: Bool {
        selectedCategoryKey.hasPrefix("custom:")
    }

    private var selectedCustomCategoryId: UUID? {
        guard isCustomCategorySelected else { return nil }
        let uuidString = String(selectedCategoryKey.dropFirst(7))
        return UUID(uuidString: uuidString)
    }

    private var selectedPackCategory: ProcedureCategory? {
        guard !isCustomCategorySelected else { return nil }
        return ProcedureCategory(rawValue: selectedCategoryKey)
    }

    private var selectedCategoryDisplayName: String {
        if selectedCategoryKey.isEmpty {
            return "Select"
        }
        if isCustomCategorySelected {
            if let customId = selectedCustomCategoryId,
               let category = activeCustomCategories.first(where: { $0.id == customId }) {
                return category.name
            }
            return "Custom"
        }
        return selectedCategoryKey
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Procedure Name", text: $title)
                        .autocapitalization(.words)
                }

                Section {
                    if !hasPackCategories && activeCustomCategories.isEmpty {
                        Text("No categories available. Install a specialty pack or create custom categories.")
                            .font(.caption)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    } else {
                        NavigationLink {
                            CategorySelectionView(
                                selectedCategoryKey: $selectedCategoryKey,
                                categoriesByPack: categoriesByPack,
                                customCategories: activeCustomCategories
                            )
                        } label: {
                            HStack {
                                Text("Category")
                                Spacer()
                                Text(selectedCategoryDisplayName)
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                            }
                        }
                    }
                } header: {
                    Text("Category")
                }
            }
            .navigationTitle(procedure == nil ? "Add Procedure" : "Edit Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || selectedCategoryKey.isEmpty)
                }
            }
            .onAppear {
                if let procedure = procedure {
                    title = procedure.title
                    if let customCatId = procedure.customCategoryId {
                        selectedCategoryKey = "custom:\(customCatId.uuidString)"
                    } else {
                        selectedCategoryKey = procedure.categoryRaw ?? ProcedureCategory.diagnostic.rawValue
                    }
                } else {
                    // Default to first available category
                    if let firstPack = categoriesByPack.first,
                       let firstCategory = firstPack.categories.first {
                        selectedCategoryKey = firstCategory.rawValue
                    } else if let firstCustom = activeCustomCategories.first {
                        selectedCategoryKey = "custom:\(firstCustom.id.uuidString)"
                    }
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        if let procedure = procedure {
            procedure.title = trimmedTitle
            if let customId = selectedCustomCategoryId {
                procedure.customCategoryId = customId
                procedure.categoryRaw = ProcedureCategory.other.rawValue
            } else if let packCategory = selectedPackCategory {
                procedure.customCategoryId = nil
                procedure.category = packCategory
            }
        } else {
            let newProcedure = CustomProcedure(
                title: trimmedTitle,
                category: selectedPackCategory ?? .other,
                customCategoryId: selectedCustomCategoryId
            )
            modelContext.insert(newProcedure)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Category Selection View

struct CategorySelectionView<T: Identifiable>: View where T: PackWithCategoriesProtocol {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategoryKey: String

    let categoriesByPack: [T]
    let customCategories: [CustomCategory]

    var body: some View {
        List {
            // Pack categories
            ForEach(categoriesByPack) { packData in
                Section {
                    ForEach(packData.categories, id: \.rawValue) { category in
                        Button {
                            selectedCategoryKey = category.rawValue
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                CategoryBubble(category: category, size: 24)
                                Text(category.rawValue)
                                    .foregroundColor(Color(UIColor.label))
                                Spacer()
                                if selectedCategoryKey == category.rawValue {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text(packData.packName)
                }
            }

            // Custom categories
            if !customCategories.isEmpty {
                Section {
                    ForEach(customCategories) { category in
                        let tagKey = "custom:\(category.id.uuidString)"
                        Button {
                            selectedCategoryKey = tagKey
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                CustomCategoryBubble(category: category, size: 24)
                                Text(category.name)
                                    .foregroundColor(Color(UIColor.label))
                                Spacer()
                                if selectedCategoryKey == tagKey {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Custom Categories")
                }
            }
        }
        .navigationTitle("Select Category")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Protocol for pack with categories
protocol PackWithCategoriesProtocol {
    var packName: String { get }
    var categories: [ProcedureCategory] { get }
}

// MARK: - Add/Edit Custom Access Site Sheet

struct AddEditCustomAccessSiteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var programs: [Program]
    @Query private var allCases: [CaseEntry]

    let accessSite: CustomAccessSite?

    @State private var title = ""
    @State private var showingArchiveConfirm = false

    private var program: Program? { programs.first }

    private var isUsedInCases: Bool {
        guard let site = accessSite else { return false }
        return allCases.contains { $0.accessSiteIds.contains(site.id.uuidString) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Access Site Name", text: $title)
                        .autocapitalization(.words)
                } footer: {
                    Text("Enter a name for the custom access site (e.g., \"Left Internal Jugular\")")
                }

                // Archive/Restore Section (only for existing sites)
                if let site = accessSite {
                    Section {
                        if site.isArchived {
                            Button {
                                site.isArchived = false
                                try? modelContext.save()
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Restore Access Site")
                                        .foregroundColor(.green)
                                }
                            }
                        } else {
                            if isUsedInCases {
                                Button { showingArchiveConfirm = true } label: {
                                    HStack {
                                        Image(systemName: "archivebox.fill")
                                            .foregroundColor(.orange)
                                        Text("Archive Access Site")
                                            .foregroundColor(.orange)
                                    }
                                }
                            } else {
                                Button(role: .destructive) {
                                    modelContext.delete(site)
                                    try? modelContext.save()
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                        Text("Delete Access Site")
                                    }
                                }
                            }
                        }
                    } footer: {
                        if isUsedInCases && !site.isArchived {
                            Text("This access site is used in existing cases and can only be archived, not deleted.")
                        }
                    }
                }
            }
            .navigationTitle(accessSite == nil ? "Add Access Site" : "Edit Access Site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let site = accessSite {
                    title = site.title
                }
            }
            .alert("Archive Access Site?", isPresented: $showingArchiveConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Archive", role: .destructive) {
                    accessSite?.isArchived = true
                    try? modelContext.save()
                    dismiss()
                }
            } message: {
                Text("This access site is used in existing cases. Archiving will hide it from future use but preserve historical data.")
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        if let site = accessSite {
            site.title = trimmedTitle
        } else {
            let newSite = CustomAccessSite(
                title: trimmedTitle,
                programId: program?.id
            )
            modelContext.insert(newSite)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Add/Edit Custom Complication Sheet

struct AddEditCustomComplicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var programs: [Program]
    @Query private var allCases: [CaseEntry]

    let complication: CustomComplication?

    @State private var title = ""
    @State private var showingArchiveConfirm = false

    private var program: Program? { programs.first }

    private var isUsedInCases: Bool {
        guard let comp = complication else { return false }
        return allCases.contains { $0.complicationIds.contains(comp.id.uuidString) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Complication Name", text: $title)
                        .autocapitalization(.sentences)
                } footer: {
                    Text("Enter a name for the custom complication (e.g., \"Prolonged procedural time\")")
                }

                // Archive/Restore Section (only for existing complications)
                if let comp = complication {
                    Section {
                        if comp.isArchived {
                            Button {
                                comp.isArchived = false
                                try? modelContext.save()
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Restore Complication")
                                        .foregroundColor(.green)
                                }
                            }
                        } else {
                            if isUsedInCases {
                                Button { showingArchiveConfirm = true } label: {
                                    HStack {
                                        Image(systemName: "archivebox.fill")
                                            .foregroundColor(.orange)
                                        Text("Archive Complication")
                                            .foregroundColor(.orange)
                                    }
                                }
                            } else {
                                Button(role: .destructive) {
                                    modelContext.delete(comp)
                                    try? modelContext.save()
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                        Text("Delete Complication")
                                    }
                                }
                            }
                        }
                    } footer: {
                        if isUsedInCases && !comp.isArchived {
                            Text("This complication is used in existing cases and can only be archived, not deleted.")
                        }
                    }
                }
            }
            .navigationTitle(complication == nil ? "Add Complication" : "Edit Complication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let comp = complication {
                    title = comp.title
                }
            }
            .alert("Archive Complication?", isPresented: $showingArchiveConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Archive", role: .destructive) {
                    complication?.isArchived = true
                    try? modelContext.save()
                    dismiss()
                }
            } message: {
                Text("This complication is used in existing cases. Archiving will hide it from future use but preserve historical data.")
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        if let comp = complication {
            comp.title = trimmedTitle
        } else {
            let newComplication = CustomComplication(
                title: trimmedTitle,
                programId: program?.id
            )
            modelContext.insert(newComplication)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Manage Evaluations View

struct ManageEvaluationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var programs: [Program]
    @Query private var evaluationFields: [EvaluationField]

    @State private var showingAddField = false
    @State private var fieldToEdit: EvaluationField?

    private var program: Program? { programs.first }

    /// All active evaluation fields for this program, sorted by display order
    private var activeFields: [EvaluationField] {
        evaluationFields
            .filter { !$0.isArchived && $0.programId == program?.id }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    private var maxDisplayOrder: Int {
        activeFields.map { $0.displayOrder }.max() ?? 0
    }

    var body: some View {
        Group {
            if program == nil {
                // No program - show create message
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "checklist")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No Program Configured")
                        .font(.headline)
                    Text("Create a program in Manage Program to configure evaluations.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    // Enable Evaluations Toggle
                    Section {
                        if let program = program {
                            Toggle(isOn: Binding(
                                get: { program.evaluationsEnabled },
                                set: { program.evaluationsEnabled = $0; program.updatedAt = Date(); try? modelContext.save() }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Enable Evaluations")
                                        .font(.subheadline)
                                    Text("Attendings can evaluate fellows during attestation")
                                        .font(.caption)
                                        .foregroundColor(Color(UIColor.secondaryLabel))
                                }
                            }

                            if program.evaluationsEnabled {
                                Toggle(isOn: Binding(
                                    get: { program.evaluationsRequired },
                                    set: { program.evaluationsRequired = $0; program.updatedAt = Date(); try? modelContext.save() }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Require for Attestation")
                                            .font(.subheadline)
                                        Text("Attendings must complete evaluation to attest")
                                            .font(.caption)
                                            .foregroundColor(Color(UIColor.secondaryLabel))
                                    }
                                }

                                Toggle(isOn: Binding(
                                    get: { program.evaluationFreeTextEnabled },
                                    set: { program.evaluationFreeTextEnabled = $0; program.updatedAt = Date(); try? modelContext.save() }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Free Text Comments")
                                            .font(.subheadline)
                                        Text("Allow optional written feedback")
                                            .font(.caption)
                                            .foregroundColor(Color(UIColor.secondaryLabel))
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Evaluation Settings")
                    }

                    // Evaluation Fields (unified list - no more dual source)
                    if program?.evaluationsEnabled == true {
                        Section {
                            if activeFields.isEmpty {
                                Text("No evaluation criteria configured")
                                    .font(.subheadline)
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                    .italic()
                            } else {
                                ForEach(activeFields) { field in
                                    EvaluationFieldRow(field: field)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            fieldToEdit = field
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                field.isArchived = true
                                                try? modelContext.save()
                                            } label: {
                                                Label("Archive", systemImage: "archivebox")
                                            }
                                        }
                                }
                                .onMove { from, to in
                                    reorderFields(from: from, to: to)
                                }
                            }

                            Button { showingAddField = true } label: {
                                Label("Add Evaluation Criteria", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        } header: {
                            Text("Evaluation Criteria")
                        } footer: {
                            Text("Checkboxes are marked as met/not met. Ratings use a 1-5 scale.")
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Evaluations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if program?.evaluationsEnabled == true && !activeFields.isEmpty {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddField) {
            AddEvaluationFieldSheet(programId: program?.id, nextDisplayOrder: maxDisplayOrder + 1)
        }
        .sheet(item: $fieldToEdit) { field in
            EditEvaluationFieldSheet(field: field)
        }
    }

    private func reorderFields(from source: IndexSet, to destination: Int) {
        var fields = activeFields
        fields.move(fromOffsets: source, toOffset: destination)
        for (index, field) in fields.enumerated() {
            field.displayOrder = index
        }
        try? modelContext.save()
    }
}

// MARK: - Manage Duty Hours Settings View

struct ManageDutyHoursSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var programs: [Program]

    private var program: Program? { programs.first }

    var body: some View {
        Group {
            if program == nil {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Program Configured")
                        .font(.headline)
                    Text("Create a program in Program Settings to configure duty hours.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    // Duty Hours Feature Toggle Section
                    Section {
                        if let program = program {
                            Toggle(isOn: Binding(
                                get: { program.dutyHoursEnabled },
                                set: { program.dutyHoursEnabled = $0; program.updatedAt = Date(); try? modelContext.save() }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Enable Duty Hours")
                                        .font(.subheadline)
                                    Text("When disabled, fellows will not see the Hours tab or any duty hours features")
                                        .font(.caption)
                                        .foregroundColor(Color(UIColor.secondaryLabel))
                                }
                            }
                        }
                    } header: {
                        Text("Duty Hours Feature")
                    } footer: {
                        Text("Toggle the entire duty hours tracking feature for your fellowship program.")
                    }

                    if program?.dutyHoursEnabled == true {
                        // Logging Mode Section
                        Section {
                            if let program = program {
                                Toggle(isOn: Binding(
                                    get: { program.allowSimpleDutyHours },
                                    set: { program.allowSimpleDutyHours = $0; program.updatedAt = Date(); try? modelContext.save() }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Allow Simple Mode")
                                            .font(.subheadline)
                                        Text("Fellows can log weekly hours totals instead of individual shifts")
                                            .font(.caption)
                                            .foregroundColor(Color(UIColor.secondaryLabel))
                                    }
                                }
                            }
                        } header: {
                            Text("Logging Mode")
                        } footer: {
                            Text("When disabled, fellows must use comprehensive shift-by-shift tracking.")
                        }

                        // Shift Types Section
                        Section {
                            if let program = program {
                                Toggle(isOn: Binding(
                                    get: { program.dutyHoursCallEnabled },
                                    set: { program.dutyHoursCallEnabled = $0; program.updatedAt = Date(); try? modelContext.save() }
                                )) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "phone.fill")
                                            .foregroundColor(.orange)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Call")
                                                .font(.subheadline)
                                            Text("In-hospital call shifts")
                                                .font(.caption)
                                                .foregroundColor(Color(UIColor.secondaryLabel))
                                        }
                                    }
                                }

                                Toggle(isOn: Binding(
                                    get: { program.dutyHoursNightFloatEnabled },
                                    set: { program.dutyHoursNightFloatEnabled = $0; program.updatedAt = Date(); try? modelContext.save() }
                                )) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "moon.fill")
                                            .foregroundColor(.purple)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Night Float")
                                                .font(.subheadline)
                                            Text("Overnight coverage rotations")
                                                .font(.caption)
                                                .foregroundColor(Color(UIColor.secondaryLabel))
                                        }
                                    }
                                }

                                Toggle(isOn: Binding(
                                    get: { program.dutyHoursMoonlightingEnabled },
                                    set: { program.dutyHoursMoonlightingEnabled = $0; program.updatedAt = Date(); try? modelContext.save() }
                                )) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "moon.stars.fill")
                                            .foregroundColor(.indigo)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Moonlighting")
                                                .font(.subheadline)
                                            Text("External or internal moonlighting shifts")
                                                .font(.caption)
                                                .foregroundColor(Color(UIColor.secondaryLabel))
                                        }
                                    }
                                }

                                Toggle(isOn: Binding(
                                    get: { program.dutyHoursAtHomeCallEnabled },
                                    set: { program.dutyHoursAtHomeCallEnabled = $0; program.updatedAt = Date(); try? modelContext.save() }
                                )) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "house.fill")
                                            .foregroundColor(.green)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("At-Home Call")
                                                .font(.subheadline)
                                            Text("Home call with potential callback")
                                                .font(.caption)
                                                .foregroundColor(Color(UIColor.secondaryLabel))
                                        }
                                    }
                                }
                            }
                        } header: {
                            Text("Enabled Shift Types")
                        } footer: {
                            Text("Disabled shift types will not appear in fellows' duty hours logging options. Regular shifts and Day Off are always available.")
                        }
                    }
                }
            }
        }
        .navigationTitle("Duty Hours")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Evaluation Field Row

struct EvaluationFieldRow: View {
    let field: EvaluationField

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(field.title)
                    .font(.subheadline)

                HStack(spacing: 8) {
                    // Field type badge
                    Text(field.fieldType.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(field.fieldType == .rating ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                        .foregroundColor(field.fieldType == .rating ? .orange : .blue)
                        .cornerRadius(4)

                    if field.isRequired {
                        Text("Required")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Evaluation Field Sheet

struct AddEvaluationFieldSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let programId: UUID?
    let nextDisplayOrder: Int

    @State private var title = ""
    @State private var descriptionText = ""
    @State private var fieldType: EvaluationFieldType = .checkbox
    @State private var isRequired = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Evaluation Criteria", text: $title)
                } footer: {
                    Text("Enter the criteria that attendings will assess for each case.")
                }

                Section {
                    TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)
                } footer: {
                    Text("Optional description that attendings can expand to see more details about this criteria.")
                }

                Section {
                    Picker("Type", selection: $fieldType) {
                        Text("Checkbox").tag(EvaluationFieldType.checkbox)
                        Text("Rating (1-5)").tag(EvaluationFieldType.rating)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Field Type")
                } footer: {
                    if fieldType == .checkbox {
                        Text("Attendings will check this box if the criteria is met.")
                    } else {
                        Text("Attendings will select a rating from 1 (needs improvement) to 5 (excellent).")
                    }
                }

                Section {
                    Toggle("Required for Attestation", isOn: $isRequired)
                } footer: {
                    Text("If enabled, attendings must complete this field before they can attest the case.")
                }
            }
            .navigationTitle("Add Evaluation Criteria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let field = EvaluationField(
                            title: title,
                            descriptionText: descriptionText.isEmpty ? nil : descriptionText,
                            fieldType: fieldType,
                            isRequired: isRequired,
                            displayOrder: nextDisplayOrder,
                            programId: programId
                        )
                        modelContext.insert(field)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Evaluation Field Sheet

struct EditEvaluationFieldSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let field: EvaluationField

    @State private var title: String = ""
    @State private var descriptionText: String = ""
    @State private var fieldType: EvaluationFieldType = .checkbox
    @State private var isRequired: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Evaluation Criteria", text: $title)
                }

                Section {
                    TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)
                } footer: {
                    Text("Optional description that attendings can expand to see more details about this criteria.")
                }

                Section {
                    Picker("Type", selection: $fieldType) {
                        Text("Checkbox").tag(EvaluationFieldType.checkbox)
                        Text("Rating (1-5)").tag(EvaluationFieldType.rating)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Field Type")
                } footer: {
                    if fieldType == .checkbox {
                        Text("Attendings will check this box if the criteria is met.")
                    } else {
                        Text("Attendings will select a rating from 1 (needs improvement) to 5 (excellent).")
                    }
                }

                Section {
                    Toggle("Required for Attestation", isOn: $isRequired)
                }
            }
            .navigationTitle("Edit Evaluation Criteria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        field.title = title
                        field.descriptionText = descriptionText.isEmpty ? nil : descriptionText
                        field.fieldType = fieldType
                        field.isRequired = isRequired
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                title = field.title
                descriptionText = field.descriptionText ?? ""
                fieldType = field.fieldType
                isRequired = field.isRequired
            }
        }
    }
}

// MARK: - Attestation Dashboard View

struct AttestationDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var allCases: [CaseEntry]
    @Query private var allUsers: [User]
    @Query private var attendings: [Attending]
    @Query private var evaluationFields: [EvaluationField]
    @Query private var evaluationSettings: [ProgramEvaluationSettings]
    @Query private var programs: [Program]

    @State private var filterStatus: AttestationStatus? = nil
    @State private var filterFellowId: UUID? = nil
    @State private var filterAttendingId: UUID? = nil
    @State private var filterAttestorType: String = "all"  // "all", "attending", "proxy"
    @State private var showingProxyAttestation = false
    @State private var caseForProxy: CaseEntry?
    @State private var selectedProxyRating: Int? = nil

    private var pendingCount: Int {
        allCases.filter { $0.attestationStatus == .pending || $0.attestationStatus == .requested }.count
    }

    private var attestedCount: Int {
        allCases.filter { $0.attestationStatus == .attested || $0.attestationStatus == .proxyAttested }.count
    }

    private var rejectedCount: Int {
        allCases.filter { $0.attestationStatus == .rejected }.count
    }

    private var filteredCases: [CaseEntry] {
        var cases = allCases

        if let status = filterStatus {
            cases = cases.filter { $0.attestationStatus == status }
        }
        if let fellowId = filterFellowId {
            cases = cases.filter { $0.fellowId == fellowId || $0.ownerId == fellowId }
        }
        if let attendingId = filterAttendingId {
            cases = cases.filter { $0.attendingId == attendingId || $0.supervisorId == attendingId }
        }

        // Filter by attestor type (attending vs proxy)
        switch filterAttestorType {
        case "attending":
            cases = cases.filter { !$0.isProxyAttestation && ($0.attestationStatus == .attested) }
        case "proxy":
            cases = cases.filter { $0.isProxyAttestation }
        default:
            break // "all" - no additional filter
        }

        return cases.sorted { $0.createdAt > $1.createdAt }
    }

    private var fellows: [User] {
        allUsers.filter { $0.role == .fellow && !$0.hasGraduated }.sorted { $0.displayName < $1.displayName }
    }

    private var activeAttendings: [Attending] {
        attendings.filter { !$0.isArchived }.sorted { $0.lastName < $1.lastName }
    }

    private var proxyAttestedCases: [CaseEntry] {
        allCases.filter { $0.isProxyAttestation }
    }

    /// Current program
    private var currentProgram: Program? {
        programs.first
    }

    /// Check if evaluations are required for proxy attestation
    private var evaluationsRequired: Bool {
        guard let program = currentProgram else { return false }
        if let settings = evaluationSettings.first(where: { $0.programId == program.id }) {
            return settings.isEnabled && settings.isRequired
        }
        return program.evaluationsEnabled && program.evaluationsRequired
    }

    /// Active evaluation fields (non-archived rating fields)
    private var activeRatingFields: [EvaluationField] {
        evaluationFields.filter { !$0.isArchived && $0.fieldType == .rating }
    }

    var body: some View {
        List {
            statusOverviewSection
            filtersSection
            casesListSection
            proxyAttestationsSection
        }
        .navigationTitle("Attestation Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingProxyAttestation) {
            ProxyAttestationSheet(
                caseEntry: caseForProxy,
                attendings: Array(attendings),
                evaluationsRequired: evaluationsRequired,
                selectedRating: $selectedProxyRating,
                onCancel: {
                    caseForProxy = nil
                    selectedProxyRating = nil
                    showingProxyAttestation = false
                },
                onAttest: {
                    performProxyAttestation()
                    showingProxyAttestation = false
                },
                onDeferAndAttest: {
                    performProxyAttestation(deferEvaluation: true)
                    showingProxyAttestation = false
                }
            )
        }
    }

    private var statusOverviewSection: some View {
        Section {
            HStack(spacing: 16) {
                StatusBadge(label: "Pending", count: pendingCount, color: .orange)
                StatusBadge(label: "Attested", count: attestedCount, color: .green)
                StatusBadge(label: "Rejected", count: rejectedCount, color: .red)
            }
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
    }

    private var filtersSection: some View {
        Section {
            Picker("Status", selection: $filterStatus) {
                Text("All").tag(nil as AttestationStatus?)
                Text("Pending").tag(AttestationStatus.pending as AttestationStatus?)
                Text("Attested").tag(AttestationStatus.attested as AttestationStatus?)
                Text("Rejected").tag(AttestationStatus.rejected as AttestationStatus?)
            }

            Picker("Fellow", selection: $filterFellowId) {
                Text("All Fellows").tag(nil as UUID?)
                ForEach(fellows) { fellow in
                    Text(fellow.displayName).tag(fellow.id as UUID?)
                }
            }

            Picker("Attending", selection: $filterAttendingId) {
                Text("All Attendings").tag(nil as UUID?)
                ForEach(activeAttendings) { attending in
                    Text(attending.name).tag(attending.id as UUID?)
                }
            }

            Picker("Attested By", selection: $filterAttestorType) {
                Text("All").tag("all")
                Text("Attending").tag("attending")
                Text("Proxy").tag("proxy")
            }
        } header: {
            Text("Filters")
        }
    }

    private var casesListSection: some View {
        Section {
            if filteredCases.isEmpty {
                Text("No cases match the current filters")
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .italic()
            } else {
                ForEach(filteredCases) { caseEntry in
                    caseRowWithSwipeActions(caseEntry: caseEntry)
                }
            }
        } header: {
            Text("Cases (\(filteredCases.count))")
        } footer: {
            if filteredCases.contains(where: { $0.attestationStatus == .pending || $0.attestationStatus == .requested }) {
                Text("Tip: Long-press or swipe right on a pending case to proxy attest on behalf of an attending.")
                    .font(.caption2)
            }
        }
    }

    private func caseRowWithSwipeActions(caseEntry: CaseEntry) -> some View {
        AdminAttestationCaseRow(caseEntry: caseEntry, users: fellows, attendings: activeAttendings)
            .swipeActions(edge: .leading) {
                if caseEntry.attestationStatus == .pending || caseEntry.attestationStatus == .requested {
                    Button {
                        caseForProxy = caseEntry
                        showingProxyAttestation = true
                    } label: {
                        Label("Proxy Attest", systemImage: "checkmark.seal")
                    }
                    .tint(.blue)
                }
            }
            .contextMenu {
                if caseEntry.attestationStatus == .pending || caseEntry.attestationStatus == .requested {
                    Button {
                        caseForProxy = caseEntry
                        showingProxyAttestation = true
                    } label: {
                        Label("Proxy Attest", systemImage: "checkmark.seal")
                    }
                }
            }
    }

    @ViewBuilder
    private var proxyAttestationsSection: some View {
        if !proxyAttestedCases.isEmpty {
            Section {
                ForEach(proxyAttestedCases) { caseEntry in
                    AdminAttestationCaseRow(caseEntry: caseEntry, users: fellows, attendings: activeAttendings, showProxy: true)
                }
            } header: {
                Text("Proxy Attestations")
            } footer: {
                Text("Cases attested by admin on behalf of attendings.")
            }
        }
    }

    private func performProxyAttestation(deferEvaluation: Bool = false) {
        if let caseEntry = caseForProxy {
            caseEntry.attestationStatus = .proxyAttested
            caseEntry.isProxyAttestation = true
            caseEntry.attestedAt = Date()

            if deferEvaluation {
                // Record evaluation deferral
                caseEntry.evaluationDeferred = true
                caseEntry.evaluationDeferredById = appState.currentUser?.id
                caseEntry.evaluationDeferredAt = Date()
            } else if evaluationsRequired, let rating = selectedProxyRating {
                // Apply evaluation ratings
                var responses: [String: String] = [:]
                for field in activeRatingFields {
                    responses[field.id.uuidString] = String(rating)
                }
                caseEntry.evaluationResponses = responses
            }

            try? modelContext.save()
        }
        caseForProxy = nil
        selectedProxyRating = nil
    }
}

// MARK: - Proxy Attestation Sheet

struct ProxyAttestationSheet: View {
    let caseEntry: CaseEntry?
    let attendings: [Attending]
    let evaluationsRequired: Bool
    @Binding var selectedRating: Int?
    let onCancel: () -> Void
    let onAttest: () -> Void
    let onDeferAndAttest: () -> Void

    private var attendingName: String {
        guard let caseEntry = caseEntry,
              let attendingId = caseEntry.attendingId ?? caseEntry.supervisorId,
              let attending = attendings.first(where: { $0.id == attendingId }) else {
            return "the attending"
        }
        return attending.name
    }

    private var canAttest: Bool {
        if evaluationsRequired {
            return selectedRating != nil
        }
        return true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)

                    Text("Proxy Attestation")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("I have proxy authorization from \(attendingName) to attest this case.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                }
                .padding(.top, 24)

                // Evaluation rating (if required)
                if evaluationsRequired {
                    VStack(spacing: 12) {
                        Text("Overall Evaluation")
                            .font(.headline)

                        Text("Select a rating to apply to all evaluation metrics for this case.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { rating in
                                Button {
                                    selectedRating = rating
                                } label: {
                                    Text("\(rating)")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .frame(width: 50, height: 50)
                                        .background(selectedRating == rating ? Color.blue : Color(UIColor.tertiarySystemFill))
                                        .foregroundStyle(selectedRating == rating ? .white : .primary)
                                        .cornerRadius(10)
                                }
                            }
                        }

                        HStack {
                            Text("1 = Needs Improvement")
                                .font(.caption2)
                            Spacer()
                            Text("5 = Excellent")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        onAttest()
                    } label: {
                        Text("Attest Case")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canAttest ? Color.blue : Color.gray.opacity(0.3))
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!canAttest)

                    // Defer evaluation option (only when evaluations are required)
                    if evaluationsRequired {
                        Button {
                            onDeferAndAttest()
                        } label: {
                            Text("Defer Evaluation & Attest")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .cornerRadius(12)
                        }
                    }

                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Admin Attestation Case Row

struct AdminAttestationCaseRow: View {
    let caseEntry: CaseEntry
    let users: [User]
    let attendings: [Attending]
    var showProxy: Bool = false

    private var fellowName: String {
        users.first { $0.id == caseEntry.fellowId || $0.id == caseEntry.ownerId }?.displayName ?? "Unknown"
    }

    private var attendingName: String {
        attendings.first { $0.id == caseEntry.attendingId || $0.id == caseEntry.supervisorId }?.name ?? "Unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(fellowName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                AttestationStatusBadge(status: caseEntry.attestationStatus)
            }

            HStack {
                Text("Attending: \(attendingName)")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                if showProxy && caseEntry.isProxyAttestation {
                    Text("(Proxy)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                if caseEntry.evaluationDeferred {
                    Text("Eval Deferred")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }

            Text(caseEntry.weekBucket.toWeekTimeframeLabel())
                .font(.caption)
                .foregroundColor(Color(UIColor.tertiaryLabel))

            Text("\(caseEntry.procedureTagIds.count) procedures")
                .font(.caption)
                .foregroundColor(Color(UIColor.tertiaryLabel))

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
                .padding(.top, 2)
            }

            // Show attestation comment if attested with comment
            if (caseEntry.attestationStatus == .attested || caseEntry.attestationStatus == .proxyAttested),
               let comment = caseEntry.attestationComment,
               !comment.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "text.bubble.fill")
                        .font(.caption2)
                    Text(comment)
                        .font(.caption)
                        .lineLimit(2)
                }
                .foregroundColor(.green)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Admin Case Log View

struct AdminCaseLogView: View {
    @Query private var allCases: [CaseEntry]
    @Query private var allUsers: [User]
    @Query private var attendings: [Attending]
    @Query private var facilities: [TrainingFacility]

    @State private var filterStatus: String = "all"
    @State private var selectedFellowId: UUID? = nil
    @State private var selectedFacilityId: UUID? = nil
    @State private var selectedDateRange: ProcedusAnalyticsRange = .allTime
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()

    private var dateFilteredCases: [CaseEntry] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedDateRange {
        case .week:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            return allCases.filter { $0.procedureDate >= weekStart }
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return allCases.filter { $0.procedureDate >= thirtyDaysAgo }
        case .monthToDate:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return allCases.filter { $0.procedureDate >= monthStart }
        case .yearToDate:
            let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            return allCases.filter { $0.procedureDate >= yearStart }
        case .academicYearToDate:
            // Academic year starts July 1
            let year = calendar.component(.month, from: now) >= 7 ? calendar.component(.year, from: now) : calendar.component(.year, from: now) - 1
            let academicYearStart = calendar.date(from: DateComponents(year: year, month: 7, day: 1)) ?? now
            return allCases.filter { $0.procedureDate >= academicYearStart }
        case .pgy:
            // Show all time for PGY - grouped by year elsewhere
            return allCases
        case .allTime:
            return allCases
        case .custom:
            return allCases.filter { $0.procedureDate >= customStartDate && $0.procedureDate <= customEndDate }
        }
    }

    private var filteredCases: [CaseEntry] {
        var cases = dateFilteredCases

        // Filter by status
        switch filterStatus {
        case "attested":
            cases = cases.filter { $0.attestationStatus == .attested || $0.attestationStatus == .proxyAttested }
        case "rejected":
            cases = cases.filter { $0.attestationStatus == .rejected }
        case "pending":
            cases = cases.filter { $0.attestationStatus == .pending || $0.attestationStatus == .requested }
        case "proxy":
            cases = cases.filter { $0.isProxyAttestation }
        default:
            break
        }

        // Filter by fellow
        if let fellowId = selectedFellowId {
            cases = cases.filter { $0.fellowId == fellowId || $0.ownerId == fellowId }
        }

        // Filter by facility
        if let facilityId = selectedFacilityId {
            cases = cases.filter { $0.facilityId == facilityId }
        }

        return cases.sorted { $0.createdAt > $1.createdAt }
    }

    private var fellows: [User] {
        allUsers.filter { $0.role == .fellow && !$0.hasGraduated }.sorted { $0.displayName < $1.displayName }
    }

    private var activeFacilities: [TrainingFacility] {
        facilities.filter { !$0.isArchived }.sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Filter dropdowns
                HStack(spacing: 12) {
                    // Fellow filter
                    Menu {
                        Button("All Fellows") { selectedFellowId = nil }
                        Divider()
                        ForEach(fellows) { fellow in
                            Button(fellow.displayName) { selectedFellowId = fellow.id }
                        }
                    } label: {
                        HStack {
                            Text(selectedFellowId == nil ? "All Fellows" : fellowName(for: selectedFellowId))
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(20)
                    }

                    // Facility filter
                    Menu {
                        Button("All Facilities") { selectedFacilityId = nil }
                        Divider()
                        ForEach(activeFacilities) { facility in
                            Button(facility.name) { selectedFacilityId = facility.id }
                        }
                    } label: {
                        HStack {
                            Text(selectedFacilityId == nil ? "All Facilities" : facilityName(for: selectedFacilityId))
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(20)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)

                // Status filter
                Picker("Filter", selection: $filterStatus) {
                    Text("All").tag("all")
                    Text("Attested").tag("attested")
                    Text("Rejected").tag("rejected")
                    Text("Proxy A...").tag("proxy")
                    Text("Pending").tag("pending")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                // Date range filter
                HStack(spacing: 12) {
                    Menu {
                        ForEach(ProcedusAnalyticsRange.allCases) { range in
                            Button(range.rawValue) { selectedDateRange = range }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text(selectedDateRange.rawValue)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(20)
                    }

                    if selectedDateRange == .custom {
                        DatePicker("", selection: $customStartDate, displayedComponents: .date)
                            .labelsHidden()
                        Text("-")
                            .foregroundColor(.secondary)
                        DatePicker("", selection: $customEndDate, displayedComponents: .date)
                            .labelsHidden()
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)

                // Cases count
                HStack {
                    Text("\(filteredCases.count) Cases")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)

                // Cases list
                VStack(spacing: 0) {
                    if filteredCases.isEmpty {
                        Text("No cases")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    } else {
                        ForEach(Array(filteredCases.enumerated()), id: \.element.id) { index, caseEntry in
                            CaseLogRowNew(
                                caseEntry: caseEntry,
                                fellows: fellows,
                                attendings: Array(attendings),
                                facilities: Array(facilities)
                            )

                            if index < filteredCases.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Case Log")
        .navigationBarTitleDisplayMode(.large)
    }

    private func fellowName(for id: UUID?) -> String {
        guard let id = id else { return "All Fellows" }
        return fellows.first { $0.id == id }?.displayName ?? "Unknown"
    }

    private func facilityName(for id: UUID?) -> String {
        guard let id = id else { return "All Facilities" }
        return activeFacilities.first { $0.id == id }?.name ?? "Unknown"
    }
}

// MARK: - Case Log Row (New Design)

struct CaseLogRowNew: View {
    let caseEntry: CaseEntry
    let fellows: [User]
    let attendings: [Attending]
    let facilities: [TrainingFacility]

    private var fellowName: String {
        fellows.first { $0.id == caseEntry.fellowId || $0.id == caseEntry.ownerId }?.displayName ?? "Unknown"
    }

    private var attendingName: String {
        attendings.first { $0.id == caseEntry.attendingId }?.name ?? ""
    }

    private var facilityName: String {
        facilities.first { $0.id == caseEntry.facilityId }?.name ?? ""
    }

    // Get unique procedure categories for this case
    private var procedureCategories: [ProcedureCategory] {
        var seen = Set<String>()
        var categories: [ProcedureCategory] = []

        for tagId in caseEntry.procedureTagIds {
            if let category = findCategoryForProcedure(tagId) {
                if !seen.contains(category.rawValue) {
                    seen.insert(category.rawValue)
                    categories.append(category)
                }
            }
        }
        return categories
    }

    private func findCategoryForProcedure(_ tagId: String) -> ProcedureCategory? {
        for pack in SpecialtyPackCatalog.allPacks {
            for packCategory in pack.categories {
                if packCategory.procedures.contains(where: { $0.id == tagId }) {
                    return packCategory.category
                }
            }
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Fellow name
                Text(fellowName)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIColor.label))

                // Date range
                Text(caseEntry.weekBucket.toWeekTimeframeLabel())
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Facility
                if !facilityName.isEmpty {
                    Text(facilityName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Attending name
            if !attendingName.isEmpty {
                Text(attendingName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Category bubbles
            HStack(spacing: 4) {
                ForEach(procedureCategories.prefix(3), id: \.rawValue) { category in
                    CategoryBubble(category: category, size: 24)
                }
                if procedureCategories.count > 3 {
                    Text("+\(procedureCategories.count - 3)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Attestation status indicator
            attestationStatusIcon

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var attestationStatusIcon: some View {
        if caseEntry.isImported {
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 16))
                .foregroundColor(.teal)
        } else {
            switch caseEntry.attestationStatus {
            case .pending, .requested:
                Image(systemName: "clock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
            case .attested:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
            case .proxyAttested:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
            case .rejected:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            case .notRequired:
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
        }
    }
}

// Keep old CaseLogRow for backward compatibility
struct CaseLogRow: View {
    let caseEntry: CaseEntry
    let fellows: [User]
    let attendings: [Attending]
    let facilities: [TrainingFacility]

    private var fellowName: String {
        fellows.first { $0.id == caseEntry.fellowId || $0.id == caseEntry.ownerId }?.displayName ?? "Unknown"
    }

    private var facilityName: String {
        facilities.first { $0.id == caseEntry.facilityId }?.name ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(fellowName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                AttestationStatusBadge(status: caseEntry.attestationStatus)
            }

            Text(caseEntry.weekBucket.toWeekTimeframeLabel())
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))

            HStack {
                Text("\(caseEntry.procedureTagIds.count) procedures")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                if !facilityName.isEmpty {
                    Text("• \(facilityName)")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Reports by Fellow View

struct ReportsByFellowView: View {
    @Query private var allUsers: [User]
    @Query private var allCases: [CaseEntry]

    @State private var selectedFellow: User?

    private var fellows: [User] {
        allUsers.filter { $0.role == .fellow && !$0.hasGraduated }.sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        List {
            ForEach(fellows) { fellow in
                let caseCount = allCases.filter { $0.fellowId == fellow.id || $0.ownerId == fellow.id }.count
                let procedureCount = allCases.filter { $0.fellowId == fellow.id || $0.ownerId == fellow.id }
                    .reduce(0) { $0 + $1.procedureTagIds.count }

                NavigationLink {
                    FellowProcedureReportView(fellow: fellow)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fellow.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(caseCount) cases, \(procedureCount) procedures")
                                .font(.caption)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        }
                        Spacer()
                        if fellow.hasGraduated {
                            Text("Graduated")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Reports by Fellow")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Fellow Procedure Report View

struct FellowProcedureReportView: View {
    let fellow: User

    @Query private var allCases: [CaseEntry]

    private var fellowCases: [CaseEntry] {
        allCases.filter { $0.fellowId == fellow.id || $0.ownerId == fellow.id }
    }

    /// Procedures grouped by category
    private var proceduresByCategory: [(category: ProcedureCategory, procedures: [(name: String, count: Int)])] {
        var categoryProcedures: [ProcedureCategory: [String: Int]] = [:]

        for caseEntry in fellowCases {
            for tagId in caseEntry.procedureTagIds {
                if let procedure = SpecialtyPackCatalog.findProcedure(by: tagId),
                   let category = SpecialtyPackCatalog.findCategory(for: tagId) {
                    if categoryProcedures[category] == nil {
                        categoryProcedures[category] = [:]
                    }
                    categoryProcedures[category]?[procedure.title, default: 0] += 1
                } else if tagId.hasPrefix("custom-") {
                    let customCategory = ProcedureCategory.other
                    if categoryProcedures[customCategory] == nil {
                        categoryProcedures[customCategory] = [:]
                    }
                    categoryProcedures[customCategory]?["Custom Procedure", default: 0] += 1
                }
            }
        }

        return categoryProcedures.map { (category, procs) in
            let sortedProcs = procs.map { (name: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count }
            return (category: category, procedures: sortedProcs)
        }
        .sorted { $0.procedures.reduce(0) { $0 + $1.count } > $1.procedures.reduce(0) { $0 + $1.count } }
    }

    var body: some View {
        List {
            Section {
                StatRow(label: "Total Cases", value: "\(fellowCases.count)")
                StatRow(label: "Total Procedures", value: "\(fellowCases.reduce(0) { $0 + $1.procedureTagIds.count })")
                StatRow(label: "Attested", value: "\(fellowCases.filter { $0.attestationStatus == .attested }.count)")
                StatRow(label: "Pending", value: "\(fellowCases.filter { $0.attestationStatus == .pending }.count)")
            } header: {
                Text("Summary")
            }

            if proceduresByCategory.isEmpty {
                Section {
                    Text("No procedures logged")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .italic()
                } header: {
                    Text("Procedure Counts")
                }
            } else {
                ForEach(proceduresByCategory, id: \.category) { categoryGroup in
                    Section {
                        ForEach(categoryGroup.procedures, id: \.name) { proc in
                            HStack {
                                Text(proc.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(proc.count)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                    } header: {
                        HStack {
                            CategoryBubble(category: categoryGroup.category, size: 16)
                            Text(categoryGroup.category.rawValue)
                        }
                    }
                }
            }
        }
        .navigationTitle(fellow.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Evaluation Dashboard View

struct EvaluationSummaryView: View {
    @Query private var allUsers: [User]
    @Query private var allCases: [CaseEntry]
    @Query private var evaluationFields: [EvaluationField]
    @Query private var attendings: [Attending]

    @State private var showGraduated: Bool = false
    @State private var filterPGY: Int? = nil
    @State private var selectedDateRange: ProcedusAnalyticsRange = .allTime
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()

    private var dateFilteredCases: [CaseEntry] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedDateRange {
        case .week:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            return allCases.filter { $0.procedureDate >= weekStart }
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return allCases.filter { $0.procedureDate >= thirtyDaysAgo }
        case .monthToDate:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return allCases.filter { $0.procedureDate >= monthStart }
        case .yearToDate:
            let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            return allCases.filter { $0.procedureDate >= yearStart }
        case .academicYearToDate:
            let year = calendar.component(.month, from: now) >= 7 ? calendar.component(.year, from: now) : calendar.component(.year, from: now) - 1
            let academicYearStart = calendar.date(from: DateComponents(year: year, month: 7, day: 1)) ?? now
            return allCases.filter { $0.procedureDate >= academicYearStart }
        case .pgy, .allTime:
            return allCases
        case .custom:
            return allCases.filter { $0.procedureDate >= customStartDate && $0.procedureDate <= customEndDate }
        }
    }

    private var fellows: [User] {
        var list = allUsers.filter { $0.role == .fellow && !$0.isArchived }
        // Filter by graduated status
        list = list.filter { showGraduated ? $0.hasGraduated : !$0.hasGraduated }
        if let pgy = filterPGY {
            list = list.filter { $0.trainingYear == pgy }
        }
        // Sort by PGY year (ascending), then by name
        return list.sorted {
            let pgy1 = $0.trainingYear ?? 99
            let pgy2 = $1.trainingYear ?? 99
            if pgy1 != pgy2 {
                return pgy1 < pgy2
            }
            return $0.displayName < $1.displayName
        }
    }

    /// Group fellows by PGY year
    private var fellowsByPGY: [(pgy: Int?, fellows: [User])] {
        var grouped: [Int?: [User]] = [:]
        for fellow in fellows {
            let pgy = fellow.trainingYear
            grouped[pgy, default: []].append(fellow)
        }
        // Sort groups by PGY year (nil at end)
        return grouped.sorted { ($0.key ?? 99) < ($1.key ?? 99) }
            .map { (pgy: $0.key, fellows: $0.value) }
    }

    /// PGY levels available for filtering based on current toggle
    private var availablePGYLevels: [Int] {
        let relevantFellows = allUsers.filter { $0.role == .fellow && !$0.isArchived && (showGraduated ? $0.hasGraduated : !$0.hasGraduated) }
        let pgySet = Set(relevantFellows.compactMap { $0.trainingYear })
        return pgySet.sorted()
    }

    private func casesWithEvaluations(for fellow: User) -> [CaseEntry] {
        dateFilteredCases.filter {
            ($0.fellowId == fellow.id || $0.ownerId == fellow.id) &&
            (!$0.evaluationResponses.isEmpty || !$0.evaluationChecks.isEmpty)
        }
    }

    private func averageRating(for fellow: User) -> Double {
        let cases = casesWithEvaluations(for: fellow)
        let ratingFields = evaluationFields.filter { $0.fieldType == .rating && !$0.isArchived }
        var totalRating = 0.0
        var ratingCount = 0

        for caseEntry in cases {
            let responses = caseEntry.evaluationResponses
            for field in ratingFields {
                if let valueStr = responses[field.id.uuidString],
                   let value = Int(valueStr), value > 0 {
                    totalRating += Double(value)
                    ratingCount += 1
                }
            }
        }

        return ratingCount > 0 ? totalRating / Double(ratingCount) : 0
    }

    private var hasAnyEvaluations: Bool {
        fellows.contains { !casesWithEvaluations(for: $0).isEmpty }
    }

    var body: some View {
        List {
            // Active/Graduated Toggle
            Section {
                Picker("Fellow Status", selection: $showGraduated) {
                    Text("Current").tag(false)
                    Text("Graduated").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .onChange(of: showGraduated) { _, _ in
                // Reset PGY filter when switching between active/graduated
                filterPGY = nil
            }

            // Filter Section
            Section {
                HStack {
                    Text("Filter PGY")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    Spacer()
                    Picker("PGY", selection: $filterPGY) {
                        Text("All").tag(nil as Int?)
                        ForEach(availablePGYLevels, id: \.self) { year in
                            Text("PGY-\(year)").tag(year as Int?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Text("Date Range")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    Spacer()
                    Picker("Date", selection: $selectedDateRange) {
                        ForEach(ProcedusAnalyticsRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if selectedDateRange == .custom {
                    HStack {
                        DatePicker("From", selection: $customStartDate, displayedComponents: .date)
                            .labelsHidden()
                        Text("-")
                            .foregroundColor(.secondary)
                        DatePicker("To", selection: $customEndDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }

            // Fellows List - Grouped by PGY Year
            if !hasAnyEvaluations {
                Section {
                    Text("No evaluations recorded yet")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .italic()
                }
            } else {
                ForEach(fellowsByPGY, id: \.pgy) { group in
                    let fellowsWithEvals = group.fellows.filter { !casesWithEvaluations(for: $0).isEmpty }
                    if !fellowsWithEvals.isEmpty {
                        Section {
                            ForEach(fellowsWithEvals) { fellow in
                                let fellowCases = casesWithEvaluations(for: fellow)
                                NavigationLink {
                                    FellowEvaluationDetailView(
                                        fellow: fellow,
                                        cases: fellowCases,
                                        evaluationFields: Array(evaluationFields.filter { !$0.isArchived }),
                                        attendings: Array(attendings)
                                    )
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(fellow.displayName)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text("\(fellowCases.count) evaluations")
                                                .font(.caption)
                                                .foregroundColor(Color(UIColor.secondaryLabel))
                                        }
                                        Spacer()
                                        let avg = averageRating(for: fellow)
                                        if avg > 0 {
                                            RatingStarsView(rating: avg)
                                            Text(String(format: "%.1f", avg))
                                                .font(.caption)
                                                .foregroundColor(Color(UIColor.secondaryLabel))
                                        }
                                    }
                                }
                            }
                        } header: {
                            if let pgy = group.pgy {
                                Text("PGY-\(pgy)")
                            } else {
                                Text("No PGY Assigned")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Evaluation Dashboard")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Rating Stars View

struct RatingStarsView: View {
    let rating: Double  // 0.0 to 5.0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: starImage(for: star))
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }

    private func starImage(for star: Int) -> String {
        let threshold = Double(star)
        if rating >= threshold {
            return "star.fill"
        } else if rating >= threshold - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

// MARK: - Fellow Evaluation Detail View

struct FellowEvaluationDetailView: View {
    let fellow: User
    let cases: [CaseEntry]
    let evaluationFields: [EvaluationField]
    let attendings: [Attending]

    @State private var showingExport = false
    @State private var selectedTab = 0

    private var checkboxFields: [EvaluationField] {
        evaluationFields.filter { $0.fieldType == .checkbox }
    }

    private var ratingFields: [EvaluationField] {
        evaluationFields.filter { $0.fieldType == .rating }
    }

    /// Count how many cases have this checkbox field checked
    private func checkboxCount(for field: EvaluationField) -> Int {
        cases.filter { caseEntry in
            caseEntry.evaluationResponses[field.id.uuidString] == "true"
        }.count
    }

    /// Calculate average rating for a rating field
    private func averageRating(for field: EvaluationField) -> Double {
        var total = 0.0
        var count = 0
        for caseEntry in cases {
            if let valueStr = caseEntry.evaluationResponses[field.id.uuidString],
               let value = Int(valueStr), value > 0 {
                total += Double(value)
                count += 1
            }
        }
        return count > 0 ? total / Double(count) : 0
    }

    /// All comments with attending attribution
    private var commentsWithContext: [(comment: String, attendingName: String, date: Date)] {
        cases.compactMap { caseEntry -> (comment: String, attendingName: String, date: Date)? in
            guard let comment = caseEntry.evaluationComment, !comment.isEmpty else { return nil }
            let attendingName = attendings.first { $0.id == caseEntry.attestorId }?.name ?? "Unknown"
            return (comment, attendingName, caseEntry.attestedAt ?? caseEntry.createdAt)
        }.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("View", selection: $selectedTab) {
                Text("Metrics").tag(0)
                Text("Comments").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            List {
                switch selectedTab {
                case 0:
                    metricsSection
                case 1:
                    commentsSection
                default:
                    metricsSection
                }
            }
        }
        .navigationTitle(fellow.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingExport = true } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingExport) {
            ExportEvaluationSheet(
                fellow: fellow,
                cases: cases,
                evaluationFields: evaluationFields,
                attendings: attendings
            )
        }
    }

    @ViewBuilder
    private var metricsSection: some View {
        // Checkbox metrics
        if !checkboxFields.isEmpty {
            Section("Competency Metrics") {
                ForEach(checkboxFields) { field in
                    let count = checkboxCount(for: field)
                    HStack {
                        Text(field.title)
                            .font(.subheadline)
                        Spacer()
                        Text("\(count)/\(cases.count)")
                            .font(.caption)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                        ProgressView(value: Double(count), total: Double(max(cases.count, 1)))
                            .frame(width: 50)
                            .tint(.blue)
                    }
                }
            }
        }

        // Rating metrics
        if !ratingFields.isEmpty {
            Section("Rating Averages") {
                ForEach(ratingFields) { field in
                    let avg = averageRating(for: field)
                    HStack {
                        Text(field.title)
                            .font(.subheadline)
                        Spacer()
                        if avg > 0 {
                            RatingStarsView(rating: avg)
                            Text(String(format: "%.1f", avg))
                                .font(.caption)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        } else {
                            Text("No ratings")
                                .font(.caption)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                    }
                }
            }
        }

        // Legacy checkbox data (from old format)
        let legacyCounts = legacyEvaluationCounts()
        if !legacyCounts.isEmpty {
            Section("Legacy Evaluations") {
                ForEach(legacyCounts, id: \.0) { (item, count) in
                    HStack {
                        Text(item)
                            .font(.subheadline)
                        Spacer()
                        Text("\(count)/\(cases.count)")
                            .font(.caption)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                }
            }
        }
    }

    private func legacyEvaluationCounts() -> [(String, Int)] {
        var counts: [String: Int] = [:]
        for caseEntry in cases {
            for check in caseEntry.evaluationChecks {
                counts[check, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }

    @ViewBuilder
    private var commentsSection: some View {
        if commentsWithContext.isEmpty {
            Section {
                Text("No comments recorded")
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .italic()
            }
        } else {
            Section("Comments (\(commentsWithContext.count))") {
                ForEach(commentsWithContext, id: \.comment) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.comment)
                            .font(.subheadline)
                        HStack {
                            Text("— \(item.attendingName)")
                            Spacer()
                            Text(item.date.formatted(date: .abbreviated, time: .omitted))
                        }
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - Export Evaluation Sheet

struct ExportEvaluationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let fellow: User
    let cases: [CaseEntry]
    let evaluationFields: [EvaluationField]
    let attendings: [Attending]

    @State private var startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var exportFormat: ExportFormat = .csv

    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case excel = "Excel"
        case pdf = "PDF"
    }

    private var filteredCases: [CaseEntry] {
        cases.filter { caseEntry in
            caseEntry.procedureDate >= startDate && caseEntry.procedureDate <= endDate
        }
    }

    private var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                } header: {
                    Text("Date Range")
                } footer: {
                    Text("\(filteredCases.count) evaluations in selected range")
                }

                Section {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Export Format")
                }

                Section {
                    previewSection
                } header: {
                    Text("Preview")
                }

                Section {
                    Button {
                        performExport()
                    } label: {
                        Label("Export Evaluation Summary", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(filteredCases.isEmpty)
                }
            }
            .navigationTitle("Export Evaluations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(fellow.displayName)
                .font(.headline)
            Text(dateRangeString)
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))

            Divider()

            let metrics = calculateMetrics()
            if metrics.isEmpty {
                Text("No evaluation fields configured")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            } else {
                ForEach(metrics.prefix(3), id: \.title) { metric in
                    HStack {
                        Text(metric.title)
                            .font(.caption)
                        Spacer()
                        if metric.fieldType == "rating", let avg = metric.average {
                            Text(String(format: "%.1f/5.0", avg))
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("\(metric.count)/\(metric.total)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                if metrics.count > 3 {
                    Text("+ \(metrics.count - 3) more fields...")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }

            let comments = collectComments()
            if !comments.isEmpty {
                Divider()
                Text("\(comments.count) comments")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
        }
        .padding(.vertical, 4)
    }

    private func calculateMetrics() -> [ExportService.EvaluationExportData.FieldMetric] {
        var metrics: [ExportService.EvaluationExportData.FieldMetric] = []

        for field in evaluationFields.sorted(by: { $0.displayOrder < $1.displayOrder }) {
            var count = 0
            var ratingSum = 0.0
            var ratingCount = 0

            for caseEntry in filteredCases {
                let responses = caseEntry.evaluationResponses
                if let value = responses[field.id.uuidString] {
                    if field.fieldType == .rating {
                        if let rating = Double(value) {
                            ratingSum += rating
                            ratingCount += 1
                        }
                    } else {
                        if value == "true" {
                            count += 1
                        }
                    }
                }
            }

            let average: Double? = field.fieldType == .rating && ratingCount > 0 ? ratingSum / Double(ratingCount) : nil
            let percentage: Double
            if field.fieldType == .rating {
                percentage = average != nil ? (average! / 5.0) * 100 : 0
            } else {
                percentage = filteredCases.isEmpty ? 0 : (Double(count) / Double(filteredCases.count)) * 100
            }

            metrics.append(ExportService.EvaluationExportData.FieldMetric(
                title: field.title,
                fieldType: field.fieldType == .rating ? "rating" : "checkbox",
                average: average,
                count: field.fieldType == .rating ? ratingCount : count,
                total: filteredCases.count,
                percentage: percentage
            ))
        }

        return metrics
    }

    private func collectComments() -> [ExportService.EvaluationExportData.CommentEntry] {
        var comments: [ExportService.EvaluationExportData.CommentEntry] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        for caseEntry in filteredCases.sorted(by: { $0.createdAt > $1.createdAt }) {
            if let comment = caseEntry.evaluationComment, !comment.isEmpty {
                let attendingName = attendings.first(where: { $0.id == caseEntry.attestorId })?.name ?? "Unknown"
                comments.append(ExportService.EvaluationExportData.CommentEntry(
                    comment: comment,
                    attendingName: attendingName,
                    date: caseEntry.createdAt,
                    formattedDate: dateFormatter.string(from: caseEntry.createdAt)
                ))
            }
        }

        return comments
    }

    private func performExport() {
        let exportData = ExportService.EvaluationExportData(
            fellowName: fellow.displayName,
            dateRange: dateRangeString,
            totalEvaluations: filteredCases.count,
            fieldMetrics: calculateMetrics(),
            comments: collectComments()
        )

        let safeName = fellow.displayName.replacingOccurrences(of: " ", with: "_")
        let url: URL?

        switch exportFormat {
        case .csv:
            url = ExportService.shared.exportEvaluationSummaryToCSV(exportData, filename: "\(safeName)_evaluations.csv")
        case .excel:
            url = ExportService.shared.exportEvaluationSummaryToExcel(exportData, filename: "\(safeName)_evaluations.xls")
        case .pdf:
            url = ExportService.shared.exportEvaluationSummaryToPDF(exportData, filename: "\(safeName)_evaluations.pdf")
        }

        if let url = url {
            ShareSheetPresenter.present(url: url)
        }
        dismiss()
    }
}

// MARK: - Export Data View

struct ExportDataView: View {
    @Query private var allUsers: [User]
    @Query private var allCases: [CaseEntry]
    @Query(filter: #Predicate<Attending> { !$0.isArchived }) private var attendings: [Attending]
    @Query(filter: #Predicate<TrainingFacility> { !$0.isArchived }) private var facilities: [TrainingFacility]
    @Query private var evaluationFields: [EvaluationField]
    @Query(filter: #Predicate<CustomAccessSite> { !$0.isArchived }) private var customAccessSites: [CustomAccessSite]
    @Query(filter: #Predicate<CustomComplication> { !$0.isArchived }) private var customComplications: [CustomComplication]
    @Query(sort: \DutyHoursEntry.weekBucket, order: .reverse) private var allDutyHours: [DutyHoursEntry]

    @State private var exportType = "log"
    @State private var exportFormat = "csv"
    @State private var selectedFellowId: UUID? = nil
    @State private var selectedRange: ProcedusAnalyticsRange = .allTime
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var showingGraduatedFellows = false

    private var currentFellows: [User] {
        allUsers.filter { $0.role == .fellow && !$0.hasGraduated }.sorted { $0.displayName < $1.displayName }
    }

    private var graduatedFellows: [User] {
        allUsers.filter { $0.role == .fellow && $0.hasGraduated }.sorted { $0.displayName < $1.displayName }
    }

    private var fellows: [User] {
        showingGraduatedFellows ? graduatedFellows : currentFellows
    }

    private var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        switch selectedRange {
        case .week:
            return "This Week"
        case .last30Days:
            return "Last 30 Days"
        case .monthToDate:
            return "Month to Date"
        case .yearToDate:
            return "Year to Date"
        case .academicYearToDate:
            return "Academic Year to Date"
        case .pgy:
            return "PGY Year"
        case .allTime:
            return "All Time"
        case .custom:
            return "\(formatter.string(from: customStartDate)) - \(formatter.string(from: customEndDate))"
        }
    }

    private func dateRange(for range: ProcedusAnalyticsRange) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch range {
        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            return (startOfWeek, now)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return (start, now)
        case .monthToDate:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return (startOfMonth, now)
        case .yearToDate:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            return (startOfYear, now)
        case .academicYearToDate:
            // Academic year starts July 1
            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)
            let academicYearStart = month >= 7 ? year : year - 1
            let startComponents = DateComponents(year: academicYearStart, month: 7, day: 1)
            let start = calendar.date(from: startComponents) ?? now
            return (start, now)
        case .pgy, .allTime:
            return (Date.distantPast, now)
        case .custom:
            return (customStartDate, customEndDate)
        }
    }

    private func filterCasesByDateRange(_ cases: [CaseEntry]) -> [CaseEntry] {
        let range = dateRange(for: selectedRange)
        return cases.filter { $0.procedureDate >= range.start && $0.procedureDate <= range.end }
    }

    var body: some View {
        List {
            // Fellow Status Toggle
            Section {
                Picker("Fellows", selection: $showingGraduatedFellows) {
                    Text("Current (\(currentFellows.count))").tag(false)
                    Text("Graduated (\(graduatedFellows.count))").tag(true)
                }
                .pickerStyle(.segmented)
            }

            Section {
                Picker("Export Type", selection: $exportType) {
                    Text("Case Log").tag("log")
                    Text("Procedure Counts").tag("counts")
                    Text("Evaluation Summary").tag("evaluations")
                    Text("Evaluation Log").tag("evalLog")
                    Text("Duty Hours").tag("dutyHours")
                }
            } header: {
                Text("Export Type")
            } footer: {
                switch exportType {
                case "log":
                    Text("Detailed list of procedures by date, attending, and outcome.")
                case "counts":
                    Text("Totals grouped by procedure and category.")
                case "evaluations":
                    Text("Summary of attending evaluations with averages and feedback.")
                case "evalLog":
                    Text("Case-by-case evaluation log showing who performed each evaluation (Attending vs Proxy).")
                case "dutyHours":
                    Text("Weekly duty hours logged by fellows.")
                default:
                    Text("")
                }
            }

            Section {
                Picker("Date Range", selection: $selectedRange) {
                    ForEach(ProcedusAnalyticsRange.allCases.filter { $0 != .pgy }, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }

                if selectedRange == .custom {
                    DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $customEndDate, displayedComponents: .date)
                }
            } header: {
                Text("Date Range")
            } footer: {
                Text("Filter exported data to the selected time period.")
            }

            Section {
                Picker("Format", selection: $exportFormat) {
                    Text("CSV").tag("csv")
                    Text("Excel").tag("excel")
                    Text("PDF").tag("pdf")
                }
            } header: {
                Text("Format")
            }

            Section {
                Button {
                    exportAll()
                } label: {
                    Label("Export All Fellows (\(dateRangeString))", systemImage: "arrow.down.doc.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            } header: {
                Text("Full Export")
            }

            Section {
                if fellows.isEmpty {
                    Text(showingGraduatedFellows ? "No graduated fellows" : "No current fellows")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(fellows) { fellow in
                        Button {
                            exportForFellow(fellow)
                        } label: {
                            HStack {
                                Text(fellow.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(Color(UIColor.label))
                                Spacer()
                                Image(systemName: "arrow.down.doc")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text(showingGraduatedFellows ? "Export by Graduated Fellow" : "Export by Fellow")
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exportAll() {
        for fellow in fellows {
            exportForFellow(fellow)
        }
    }

    private func exportForFellow(_ fellow: User) {
        let allFellowCases = allCases.filter { $0.fellowId == fellow.id || $0.ownerId == fellow.id }
        let fellowCases = filterCasesByDateRange(allFellowCases)
        let safeName = fellow.displayName.replacingOccurrences(of: " ", with: "_")
        var url: URL?

        switch exportType {
        case "log":
            let rows = buildExportRows(for: fellowCases, fellowName: fellow.displayName)
            switch exportFormat {
            case "csv":
                url = ExportService.shared.exportToCSV(rows: rows, filename: "\(safeName)_log")
            case "excel":
                url = ExportService.shared.exportToExcel(rows: rows, filename: "\(safeName)_log")
            case "pdf":
                url = ExportService.shared.exportToPDF(rows: rows, fellowName: fellow.displayName, title: "Procedure Log (\(dateRangeString))")
            default: break
            }

        case "counts":
            let rows = buildCountRows(for: fellowCases)
            switch exportFormat {
            case "csv":
                url = ExportService.shared.exportProcedureCountsToCSV(rows: rows, filename: "\(safeName)_counts")
            case "excel":
                url = ExportService.shared.exportProcedureCountsToExcel(rows: rows, fellowName: fellow.displayName, totalCases: fellowCases.count, dateRange: dateRangeString)
            case "pdf":
                url = ExportService.shared.exportProcedureCountsToPDF(rows: rows, fellowName: fellow.displayName, dateRange: dateRangeString)
            default: break
            }

        case "evaluations":
            let exportData = buildEvaluationExportData(for: fellowCases, fellowName: fellow.displayName, dateRange: dateRangeString)
            switch exportFormat {
            case "csv":
                url = ExportService.shared.exportEvaluationSummaryToCSV(exportData, filename: "\(safeName)_evaluations.csv")
            case "excel":
                url = ExportService.shared.exportEvaluationSummaryToExcel(exportData, filename: "\(safeName)_evaluations.xls")
            case "pdf":
                url = ExportService.shared.exportEvaluationSummaryToPDF(exportData, filename: "\(safeName)_evaluations.pdf")
            default: break
            }

        case "evalLog":
            let rows = buildEvaluationLogRows(for: fellowCases, fellowName: fellow.displayName)
            switch exportFormat {
            case "csv":
                url = ExportService.shared.exportEvaluationLogToCSV(rows: rows, filename: "\(safeName)_eval_log")
            case "excel":
                url = ExportService.shared.exportEvaluationLogToExcel(rows: rows, fellowName: fellow.displayName, dateRange: dateRangeString)
            case "pdf":
                url = ExportService.shared.exportEvaluationLogToPDF(rows: rows, fellowName: fellow.displayName, dateRange: dateRangeString)
            default: break
            }

        case "dutyHours":
            let rows = buildDutyHoursRows(for: fellow)
            switch exportFormat {
            case "csv":
                url = ExportService.shared.exportDutyHoursToCSV(rows: rows, filename: "\(safeName)_duty_hours")
            case "excel":
                url = ExportService.shared.exportDutyHoursToExcel(rows: rows, fellowName: fellow.displayName, dateRange: dateRangeString)
            case "pdf":
                url = ExportService.shared.exportDutyHoursToPDF(rows: rows, fellowName: fellow.displayName, dateRange: dateRangeString)
            default: break
            }

        default: break
        }

        if let url = url {
            ShareSheetPresenter.present(url: url)
        }
    }

    private func buildExportRows(for cases: [CaseEntry], fellowName: String) -> [ExportService.CaseExportRow] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short

        return cases.map { caseEntry in
            let attendingName = attendings.first(where: { $0.id == caseEntry.attendingId })?.name ?? "N/A"
            let facilityName = facilities.first(where: { $0.id == caseEntry.facilityId })?.name ?? "N/A"
            let procedures = caseEntry.procedureTagIds.compactMap { SpecialtyPackCatalog.findProcedureTitle(for: $0) }.joined(separator: "; ")

            let accessSites = caseEntry.accessSiteIds.compactMap { siteId -> String? in
                if let builtIn = AccessSite(rawValue: siteId) {
                    return builtIn.rawValue
                } else if let custom = customAccessSites.first(where: { $0.id.uuidString == siteId }) {
                    return custom.title
                }
                return nil
            }.joined(separator: "; ")

            let complications = caseEntry.complicationIds.compactMap { compId -> String? in
                if let builtIn = Complication(rawValue: compId) {
                    return builtIn.rawValue
                } else if let custom = customComplications.first(where: { $0.id.uuidString == compId }) {
                    return custom.title
                }
                return nil
            }.joined(separator: "; ")

            return ExportService.CaseExportRow(
                fellowName: fellowName,
                attendingName: attendingName,
                facilityName: facilityName,
                weekBucket: caseEntry.weekBucket,
                procedures: procedures,
                procedureCount: caseEntry.procedureTagIds.count,
                accessSites: accessSites,
                complications: complications,
                outcome: caseEntry.outcome.rawValue,
                attestationStatus: caseEntry.attestationStatus.rawValue,
                attestedDate: caseEntry.attestedAt.map { dateFormatter.string(from: $0) } ?? "N/A",
                createdDate: dateFormatter.string(from: caseEntry.createdAt),
                procedureDate: dateFormatter.string(from: caseEntry.procedureDate)
            )
        }
    }

    private func buildCountRows(for cases: [CaseEntry]) -> [ExportService.ProcedureCountRow] {
        var counts: [String: (category: String, count: Int)] = [:]

        for caseEntry in cases {
            for procId in caseEntry.procedureTagIds {
                let title = SpecialtyPackCatalog.findProcedureTitle(for: procId) ?? procId
                let category = SpecialtyPackCatalog.findCategory(for: procId)?.rawValue ?? "Other"
                if counts[title] == nil {
                    counts[title] = (category: category, count: 0)
                }
                counts[title]?.count += 1
            }
        }

        return counts.map { ExportService.ProcedureCountRow(category: $0.value.category, procedure: $0.key, count: $0.value.count) }
            .sorted {
                // Sort by category first, then by procedure name within category
                if $0.category != $1.category {
                    return $0.category < $1.category
                }
                return $0.procedure < $1.procedure
            }
    }

    private func buildEvaluationExportData(for cases: [CaseEntry], fellowName: String, dateRange: String = "All Time") -> ExportService.EvaluationExportData {
        var metrics: [ExportService.EvaluationExportData.FieldMetric] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        for field in evaluationFields.sorted(by: { $0.displayOrder < $1.displayOrder }) {
            var count = 0
            var ratingSum = 0.0
            var ratingCount = 0

            for caseEntry in cases {
                let responses = caseEntry.evaluationResponses
                if let value = responses[field.id.uuidString] {
                    if field.fieldType == .rating {
                        if let rating = Double(value) {
                            ratingSum += rating
                            ratingCount += 1
                        }
                    } else {
                        if value == "true" {
                            count += 1
                        }
                    }
                }
            }

            let average: Double? = field.fieldType == .rating && ratingCount > 0 ? ratingSum / Double(ratingCount) : nil
            let percentage: Double
            if field.fieldType == .rating {
                percentage = average != nil ? (average! / 5.0) * 100 : 0
            } else {
                percentage = cases.isEmpty ? 0 : (Double(count) / Double(cases.count)) * 100
            }

            metrics.append(ExportService.EvaluationExportData.FieldMetric(
                title: field.title,
                fieldType: field.fieldType == .rating ? "rating" : "checkbox",
                average: average,
                count: field.fieldType == .rating ? ratingCount : count,
                total: cases.count,
                percentage: percentage
            ))
        }

        var comments: [ExportService.EvaluationExportData.CommentEntry] = []
        for caseEntry in cases.sorted(by: { $0.createdAt > $1.createdAt }) {
            if let comment = caseEntry.evaluationComment, !comment.isEmpty {
                let attendingName = attendings.first(where: { $0.id == caseEntry.attestorId })?.name ?? "Unknown"
                comments.append(ExportService.EvaluationExportData.CommentEntry(
                    comment: comment,
                    attendingName: attendingName,
                    date: caseEntry.createdAt,
                    formattedDate: dateFormatter.string(from: caseEntry.createdAt)
                ))
            }
        }

        return ExportService.EvaluationExportData(
            fellowName: fellowName,
            dateRange: dateRange,
            totalEvaluations: cases.count,
            fieldMetrics: metrics,
            comments: comments
        )
    }

    private func buildEvaluationLogRows(for cases: [CaseEntry], fellowName: String) -> [ExportService.EvaluationLogRow] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short

        return cases.sorted(by: { $0.createdAt > $1.createdAt }).compactMap { caseEntry in
            // Only include attested cases
            guard caseEntry.attestationStatus == .attested || caseEntry.attestationStatus == .proxyAttested else {
                return nil
            }

            let attendingName = attendings.first(where: { $0.id == caseEntry.attendingId })?.name ?? "N/A"
            let attestorName: String
            if let attestorId = caseEntry.attestorId,
               let attestor = attendings.first(where: { $0.id == attestorId }) {
                attestorName = attestor.name
            } else {
                attestorName = attendingName
            }

            let evaluatedBy = caseEntry.isProxyAttestation ? "Proxy (Admin)" : "Attending"
            let procedures = caseEntry.procedureTagIds.compactMap { SpecialtyPackCatalog.findProcedureTitle(for: $0) }.joined(separator: "; ")

            // Get evaluation ratings
            var ratings: [String: String] = [:]
            for field in evaluationFields.sorted(by: { $0.displayOrder < $1.displayOrder }) {
                if let value = caseEntry.evaluationResponses[field.id.uuidString] {
                    if field.fieldType == .rating {
                        ratings[field.title] = value
                    } else {
                        ratings[field.title] = value == "true" ? "Yes" : "No"
                    }
                }
            }

            return ExportService.EvaluationLogRow(
                fellowName: fellowName,
                caseDate: dateFormatter.string(from: caseEntry.createdAt),
                attendingName: attendingName,
                evaluatedBy: evaluatedBy,
                attestorName: attestorName,
                procedures: procedures,
                attestationDate: caseEntry.attestedAt.map { dateFormatter.string(from: $0) } ?? "N/A",
                comment: caseEntry.evaluationComment ?? "",
                ratings: ratings
            )
        }
    }

    private func buildDutyHoursRows(for fellow: User) -> [ExportService.DutyHoursRow] {
        let range = dateRange(for: selectedRange)

        // Filter duty hours entries by fellow and date range
        let fellowEntries = allDutyHours.filter { entry in
            guard entry.userId == fellow.id else { return false }

            // Parse week bucket to get the Monday date of that week
            let weekComponents = entry.weekBucket.split(separator: "-W")
            guard weekComponents.count == 2,
                  let year = Int(weekComponents[0]),
                  let week = Int(weekComponents[1]) else {
                return true // Include if we can't parse
            }

            let calendar = Calendar(identifier: .iso8601)
            var dateComponents = DateComponents()
            dateComponents.yearForWeekOfYear = year
            dateComponents.weekOfYear = week
            dateComponents.weekday = 2 // Monday
            guard let weekDate = calendar.date(from: dateComponents) else {
                return true
            }

            return weekDate >= range.start && weekDate <= range.end
        }

        return fellowEntries.sorted(by: { $0.weekBucket > $1.weekBucket }).map { entry in
            ExportService.DutyHoursRow(
                weekBucket: entry.weekBucket,
                weekLabel: entry.weekBucket.toWeekTimeframeLabel(),
                hours: entry.hours,
                notes: entry.notes ?? ""
            )
        }
    }
}

// MARK: - Invite Codes Sheet

struct InviteCodesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var programs: [Program]

    @State private var showingRegenerateFellow = false
    @State private var showingRegenerateAttending = false
    @State private var showingRegenerateAdmin = false

    private var program: Program? { programs.first }

    var body: some View {
        NavigationStack {
            List {
                if let program = program {
                    Section {
                        InviteCodeDetailRow(
                            label: "Fellow Code",
                            code: program.fellowInviteCode,
                            color: .blue,
                            description: "Share with fellows to join your program"
                        )
                        Button("Regenerate Code") {
                            showingRegenerateFellow = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }

                    Section {
                        InviteCodeDetailRow(
                            label: "Attending Code",
                            code: program.attendingInviteCode,
                            color: .green,
                            description: "Share with attendings to join your program"
                        )
                        Button("Regenerate Code") {
                            showingRegenerateAttending = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }

                    Section {
                        InviteCodeDetailRow(
                            label: "Admin Code",
                            code: program.adminInviteCode,
                            color: .orange,
                            description: "Share with co-administrators only"
                        )
                        Button("Regenerate Code") {
                            showingRegenerateAdmin = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                } else {
                    Text("No program configured")
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
            .navigationTitle("Invite Codes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Regenerate Fellow Code?", isPresented: $showingRegenerateFellow) {
                Button("Cancel", role: .cancel) {}
                Button("Regenerate") {
                    program?.fellowInviteCode = Program.generateInviteCode()
                    program?.updatedAt = Date()
                    try? modelContext.save()
                }
            } message: {
                Text("The old code will no longer work for new fellows.")
            }
            .alert("Regenerate Attending Code?", isPresented: $showingRegenerateAttending) {
                Button("Cancel", role: .cancel) {}
                Button("Regenerate") {
                    program?.attendingInviteCode = Program.generateInviteCode()
                    program?.updatedAt = Date()
                    try? modelContext.save()
                }
            } message: {
                Text("The old code will no longer work for new attendings.")
            }
            .alert("Regenerate Admin Code?", isPresented: $showingRegenerateAdmin) {
                Button("Cancel", role: .cancel) {}
                Button("Regenerate") {
                    program?.adminInviteCode = Program.generateInviteCode()
                    program?.updatedAt = Date()
                    try? modelContext.save()
                }
            } message: {
                Text("The old code will no longer work for new admins.")
            }
        }
    }
}

// MARK: - Invite Code Detail Row

struct InviteCodeDetailRow: View {
    let label: String
    let code: String
    let color: Color
    let description: String

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Button {
                UIPasteboard.general.string = code
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                HStack {
                    Text(code)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(color)
                    Spacer()
                    Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                        .foregroundColor(copied ? .green : Color(UIColor.tertiaryLabel))
                }
            }

            Text(description)
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Send Program Message Sheet

struct SendProgramUpdateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var programs: [Program]
    @Query private var users: [User]

    @AppStorage("selectedAdminId") private var selectedAdminIdString = ""

    @State private var messageTitle = ""
    @State private var messageBody = ""
    @State private var targetAudience: TargetAudience = .all
    @State private var isSending = false
    @State private var showingConfirmation = false
    @State private var showingSuccess = false
    @State private var selectedFellowId: UUID? = nil
    @State private var selectedPGYYear: Int? = nil

    private var program: Program? { programs.first }

    private var adminUsers: [User] {
        users.filter { $0.role == .admin }
    }

    private var currentAdmin: User? {
        if let adminId = UUID(uuidString: selectedAdminIdString),
           let admin = adminUsers.first(where: { $0.id == adminId }) {
            return admin
        }
        return adminUsers.first
    }

    private var fellows: [User] {
        guard let programId = program?.id else { return [] }
        return users.filter { $0.programId == programId && $0.role == .fellow && !$0.hasGraduated }
    }

    private var attendings: [User] {
        guard let programId = program?.id else { return [] }
        return users.filter { $0.programId == programId && $0.role == .attending }
    }

    private var availablePGYYears: [Int] {
        Set(fellows.compactMap { $0.trainingYear }).sorted()
    }

    private var fellowsInSelectedClass: [User] {
        guard let year = selectedPGYYear else { return [] }
        return fellows.filter { $0.trainingYear == year }
    }

    enum TargetAudience: String, CaseIterable, Identifiable {
        case all = "All Members"
        case fellowsOnly = "Fellows Only"
        case attendingsOnly = "Attendings Only"
        case specificFellow = "Individual Fellow"
        case fellowClass = "Fellow Class"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .all: return "person.3.fill"
            case .fellowsOnly: return "person.2.fill"
            case .attendingsOnly: return "stethoscope"
            case .specificFellow: return "person.fill"
            case .fellowClass: return "person.3.sequence.fill"
            }
        }
    }

    private var recipientCount: Int {
        switch targetAudience {
        case .all: return fellows.count + attendings.count
        case .fellowsOnly: return fellows.count
        case .attendingsOnly: return attendings.count
        case .specificFellow: return selectedFellowId != nil ? 1 : 0
        case .fellowClass: return fellowsInSelectedClass.count
        }
    }

    private var canSend: Bool {
        !messageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        recipientCount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $messageTitle)
                } header: {
                    Text("Message Title")
                } footer: {
                    Text("A brief headline for your message")
                }

                Section {
                    TextEditor(text: $messageBody)
                        .frame(minHeight: 120)
                } header: {
                    Text("Message Body")
                } footer: {
                    Text("The full content of your message")
                }

                Section {
                    Picker("Send To", selection: $targetAudience) {
                        ForEach(TargetAudience.allCases) { audience in
                            Label(audience.rawValue, systemImage: audience.icon)
                                .tag(audience)
                        }
                    }
                } header: {
                    Text("Recipients")
                } footer: {
                    Text("\(recipientCount) member\(recipientCount == 1 ? "" : "s") will receive this message")
                }
                .onChange(of: targetAudience) { _, _ in
                    selectedFellowId = nil
                    selectedPGYYear = nil
                }

                if targetAudience == .specificFellow {
                    Section {
                        Picker("Fellow", selection: $selectedFellowId) {
                            Text("Select a fellow").tag(nil as UUID?)
                            ForEach(fellows.sorted(by: { $0.displayName < $1.displayName })) { fellow in
                                HStack {
                                    Text(fellow.displayName)
                                    if let year = fellow.trainingYear {
                                        Text("PGY-\(year)")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tag(fellow.id as UUID?)
                            }
                        }
                    }
                }

                if targetAudience == .fellowClass {
                    Section {
                        Picker("PGY Year", selection: $selectedPGYYear) {
                            Text("Select a class").tag(nil as Int?)
                            ForEach(availablePGYYears, id: \.self) { year in
                                let count = fellows.filter { $0.trainingYear == year }.count
                                Text("PGY-\(year) (\(count) fellow\(count == 1 ? "" : "s"))")
                                    .tag(year as Int?)
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Messages are sent to recipients and will appear in their Messages tab. Recipients can reply to you.")
                            .font(.caption)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                }
            }
            .navigationTitle("Send Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        showingConfirmation = true
                    }
                    .disabled(!canSend || isSending)
                    .fontWeight(.semibold)
                }
            }
            .alert("Send Message?", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Send") {
                    sendMessage()
                }
            } message: {
                Text("This will send \"\(messageTitle)\" to \(recipientCount) member\(recipientCount == 1 ? "" : "s").")
            }
            .alert("Message Sent!", isPresented: $showingSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your message has been sent to \(recipientCount) member\(recipientCount == 1 ? "" : "s").")
            }
        }
    }

    private func sendMessage() {
        guard program != nil else { return }
        isSending = true

        // Create a conversation ID for grouping replies
        let conversationId = UUID()

        // Get sender info
        let senderId = currentAdmin?.id
        let senderName = currentAdmin?.displayName ?? "Program Admin"

        // Get recipient user IDs based on target audience (use Set to prevent duplicates)
        let recipientIds: Set<UUID>
        switch targetAudience {
        case .all:
            recipientIds = Set((fellows + attendings).map { $0.id })
        case .fellowsOnly:
            recipientIds = Set(fellows.map { $0.id })
        case .attendingsOnly:
            recipientIds = Set(attendings.map { $0.id })
        case .specificFellow:
            recipientIds = selectedFellowId.map { Set([$0]) } ?? []
        case .fellowClass:
            recipientIds = Set(fellowsInSelectedClass.map { $0.id })
        }

        // Use directMessage type for individual fellow, programUpdate for all others
        let messageType = targetAudience == .specificFellow
            ? NotificationType.directMessage.rawValue
            : NotificationType.programUpdate.rawValue

        // Create notification records for each unique recipient
        for userId in recipientIds {
            let notification = Procedus.Notification(
                userId: userId,
                title: messageTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                message: messageBody.trimmingCharacters(in: .whitespacesAndNewlines),
                notificationType: messageType
            )
            // Set sender tracking
            notification.senderId = senderId
            notification.senderName = senderName
            notification.senderRoleRaw = UserRole.admin.rawValue
            notification.conversationId = conversationId
            modelContext.insert(notification)
        }

        try? modelContext.save()

        // Fire local push notification for program messages
        PushNotificationManager.shared.notifyProgramMessage(
            title: messageTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            body: messageBody.trimmingCharacters(in: .whitespacesAndNewlines),
            messageId: conversationId
        )

        // Update badge for each recipient
        for userId in recipientIds {
            NotificationManager.shared.updateProgramMessageBadge(forUserId: userId)
        }

        isSending = false
        showingSuccess = true
    }
}

// MARK: - Notifications Sheet

struct NotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var notifications: [Procedus.Notification]
    @Query private var attendings: [Attending]
    @Query private var users: [User]

    let role: UserRole
    let userId: UUID?

    @State private var selectedCategory: NotificationCategory
    @State private var notificationToReply: Procedus.Notification?

    init(role: UserRole, userId: UUID?) {
        self.role = role
        self.userId = userId
        // Admin only sees Messages, not Attestations
        _selectedCategory = State(initialValue: role == .admin ? .messages : .attestations)
    }

    /// Get the current user for reply functionality
    private var currentUser: User? {
        guard let userId = userId else { return nil }
        // For fellows, find directly by ID
        if let user = users.first(where: { $0.id == userId }) {
            return user
        }
        // For attendings, find by name match
        if let attending = attendings.first(where: { $0.id == userId }) {
            return users.first(where: { "\($0.firstName) \($0.lastName)" == attending.name })
        }
        return nil
    }

    /// Get effective user name for replying
    private var currentUserName: String {
        if let user = currentUser {
            return user.displayName
        }
        // Fallback for attending without User record
        if let attending = attendings.first(where: { $0.id == userId }) {
            return attending.name
        }
        return "User"
    }

    /// Get effective user ID for replying (prefer User.id over Attending.id)
    private var effectiveUserId: UUID? {
        currentUser?.id ?? userId
    }

    /// For attending role, get all related IDs (Attending.id, Attending.userId, matching User.id)
    private var relatedIds: Set<UUID> {
        guard let userId = userId else { return [] }
        var ids: Set<UUID> = [userId]

        if role == .attending {
            // Check if userId is an Attending ID
            if let attending = attendings.first(where: { $0.id == userId }) {
                // Add the linked User ID if it exists
                if let linkedUserId = attending.userId {
                    ids.insert(linkedUserId)
                }
                // Also find any User with matching name
                if let matchingUser = users.first(where: { $0.role == .attending && "\($0.firstName) \($0.lastName)" == attending.name }) {
                    ids.insert(matchingUser.id)
                }
            }
            // Check if userId is a User ID for an attending
            if let user = users.first(where: { $0.id == userId && $0.role == .attending }) {
                // Find the matching Attending record
                let userName = "\(user.firstName) \(user.lastName)"
                if let attending = attendings.first(where: { $0.name == userName }) {
                    ids.insert(attending.id)
                    if let linkedUserId = attending.userId {
                        ids.insert(linkedUserId)
                    }
                }
            }
        }

        return ids
    }

    enum NotificationCategory: String, CaseIterable, Identifiable {
        case attestations = "Attestations"
        case messages = "Messages"
        case achievements = "Achievements"

        var id: String { rawValue }

        var notificationTypes: [String] {
            switch self {
            case .attestations:
                return [
                    NotificationType.attestationRequested.rawValue,
                    NotificationType.attestationComplete.rawValue,
                    NotificationType.caseRejected.rawValue
                ]
            case .messages:
                // Program messages from admin/others + direct messages + teaching files
                return [
                    NotificationType.programUpdate.rawValue,
                    NotificationType.programChange.rawValue,
                    NotificationType.procedureAdded.rawValue,
                    NotificationType.categoryAdded.rawValue,
                    NotificationType.userInvite.rawValue,
                    NotificationType.reminder.rawValue,
                    NotificationType.info.rawValue,
                    NotificationType.dutyHoursWarning.rawValue,
                    NotificationType.dutyHoursViolation.rawValue,
                    NotificationType.directMessage.rawValue,
                    NotificationType.teachingFileUploaded.rawValue,
                    NotificationType.teachingFileComment.rawValue
                ]
            case .achievements:
                // Badge/achievement notifications for fellows
                return [
                    NotificationType.badgeEarned.rawValue
                ]
            }
        }
    }

    private var allRelevantNotifications: [Procedus.Notification] {
        // For admin role: show messages where they are the recipient (replies from fellows/attendings)
        // For other roles: show notifications where userId matches one of the related IDs
        guard userId != nil, !relatedIds.isEmpty else { return [] }
        return notifications
            .filter { notification in
                !notification.isCleared &&
                (relatedIds.contains(notification.userId) ||
                 (notification.attendingId != nil && relatedIds.contains(notification.attendingId!)))
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var filteredNotifications: [Procedus.Notification] {
        allRelevantNotifications.filter { selectedCategory.notificationTypes.contains($0.notificationType) }
    }

    private var attestationCount: Int {
        allRelevantNotifications.filter { NotificationCategory.attestations.notificationTypes.contains($0.notificationType) && !$0.isRead }.count
    }

    private var messagesCount: Int {
        allRelevantNotifications.filter { NotificationCategory.messages.notificationTypes.contains($0.notificationType) && !$0.isRead }.count
    }

    private var achievementsCount: Int {
        allRelevantNotifications.filter { NotificationCategory.achievements.notificationTypes.contains($0.notificationType) && !$0.isRead }.count
    }

    private var attestationNotifications: [Procedus.Notification] {
        allRelevantNotifications.filter { NotificationCategory.attestations.notificationTypes.contains($0.notificationType) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Picker - role-specific categories
                if role == .admin {
                    // Admin only has messages (replies from others)
                    Text("Messages")
                        .font(.headline)
                        .padding()
                } else if role == .attending {
                    // Attending sees Attestations and Messages (no achievements)
                    Picker("Category", selection: $selectedCategory) {
                        Text(attestationCount > 0 ? "Attestations (\(attestationCount))" : "Attestations")
                            .tag(NotificationCategory.attestations)
                        Text(messagesCount > 0 ? "Messages (\(messagesCount))" : "Messages")
                            .tag(NotificationCategory.messages)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                } else {
                    // Fellow sees all three categories: Attestations, Messages, Achievements
                    Picker("Category", selection: $selectedCategory) {
                        Text(attestationCount > 0 ? "Attestations (\(attestationCount))" : "Attestations")
                            .tag(NotificationCategory.attestations)
                        Text(messagesCount > 0 ? "Messages (\(messagesCount))" : "Messages")
                            .tag(NotificationCategory.messages)
                        Text(achievementsCount > 0 ? "Achievements (\(achievementsCount))" : "Achievements")
                            .tag(NotificationCategory.achievements)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }

                // Category-specific Clear All button (shown when there are notifications in selected category)
                if !filteredNotifications.isEmpty {
                    Button {
                        clearCategoryNotifications()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Clear All \(selectedCategory.rawValue)")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                List {
                    if filteredNotifications.isEmpty {
                        Text("No \(selectedCategory.rawValue.lowercased())")
                            .font(.subheadline)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .italic()
                    } else {
                        ForEach(filteredNotifications) { notification in
                            NotificationRow(notification: notification) {
                                // Reply callback
                                notificationToReply = notification
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Mark as read when tapped
                                if !notification.isRead {
                                    notification.isRead = true
                                    notification.readAt = Date()
                                    try? modelContext.save()
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    notification.isCleared = true
                                    notification.clearedAt = Date()
                                    try? modelContext.save()
                                } label: {
                                    Label("Clear", systemImage: "xmark")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if !notification.isRead {
                                    Button {
                                        notification.isRead = true
                                        notification.readAt = Date()
                                        try? modelContext.save()
                                    } label: {
                                        Label("Mark Read", systemImage: "checkmark")
                                    }
                                    .tint(.blue)
                                }
                                // Add reply swipe action for messages with sender
                                if notification.senderId != nil {
                                    Button {
                                        notificationToReply = notification
                                    } label: {
                                        Label("Reply", systemImage: "arrowshape.turn.up.left.fill")
                                    }
                                    .tint(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $notificationToReply) { notification in
                if let effectiveId = effectiveUserId {
                    ReplyToMessageSheet(
                        originalNotification: notification,
                        currentUserId: effectiveId,
                        currentUserName: currentUserName,
                        currentUserRole: role
                    )
                }
            }
        }
    }

    /// Clear all notifications in the currently selected category
    private func clearCategoryNotifications() {
        for notification in filteredNotifications {
            notification.isCleared = true
            notification.clearedAt = Date()
        }
        try? modelContext.save()
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: Procedus.Notification
    var onReply: (() -> Void)? = nil
    @State private var isExpanded = false

    private var isMessageType: Bool {
        let messageTypes = [
            NotificationType.programUpdate.rawValue,
            NotificationType.programChange.rawValue,
            NotificationType.info.rawValue,
            NotificationType.directMessage.rawValue
        ]
        return messageTypes.contains(notification.notificationType)
    }

    private var canReply: Bool {
        // Can reply to any message that has a sender
        notification.senderId != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if !notification.isRead {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                }
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(notification.isRead ? .regular : .semibold)
                Spacer()
                Text(notification.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }

            // Show sender if available
            if let senderName = notification.senderName {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .font(.caption2)
                    Text("From: \(senderName)")
                        .font(.caption2)
                }
                .foregroundColor(Color(UIColor.tertiaryLabel))
            }

            Text(notification.message)
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
                .lineLimit(isExpanded ? nil : 2)
                .onTapGesture { withAnimation { isExpanded.toggle() } }

            if !isExpanded && notification.message.count > 80 {
                Text("Tap to read more")
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .onTapGesture { withAnimation { isExpanded.toggle() } }
            }

            // Reply button for messages with sender
            if canReply, let replyAction = onReply {
                Button {
                    replyAction()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.caption2)
                        Text("Reply")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Reply To Message Sheet

struct ReplyToMessageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let originalNotification: Procedus.Notification
    let currentUserId: UUID
    let currentUserName: String
    let currentUserRole: UserRole

    @State private var replyMessage = ""
    @State private var isSending = false
    @State private var showingSuccess = false

    private var canSend: Bool {
        !replyMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(originalNotification.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(originalNotification.message)
                            .font(.caption)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                        if let senderName = originalNotification.senderName {
                            Text("From: \(senderName)")
                                .font(.caption2)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                    }
                } header: {
                    Text("Original Message")
                }

                Section {
                    TextEditor(text: $replyMessage)
                        .frame(minHeight: 100)
                } header: {
                    Text("Your Reply")
                } footer: {
                    Text("Your reply will be sent to the original sender")
                }
            }
            .navigationTitle("Reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        sendReply()
                    }
                    .disabled(!canSend || isSending)
                    .fontWeight(.semibold)
                }
            }
            .alert("Reply Sent!", isPresented: $showingSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your reply has been sent.")
            }
        }
    }

    private func sendReply() {
        guard let recipientId = originalNotification.senderId else { return }
        isSending = true

        // Mark the original notification as read when replying
        originalNotification.isRead = true

        // Create reply notification for the original sender
        let replyNotification = Procedus.Notification(
            userId: recipientId,
            title: "Reply from \(currentUserName)",
            message: replyMessage.trimmingCharacters(in: .whitespacesAndNewlines),
            notificationType: NotificationType.directMessage.rawValue
        )

        // Set sender tracking
        replyNotification.senderId = currentUserId
        replyNotification.senderName = currentUserName
        replyNotification.senderRoleRaw = currentUserRole.rawValue
        replyNotification.replyToId = originalNotification.id
        replyNotification.conversationId = originalNotification.conversationId ?? originalNotification.id

        modelContext.insert(replyNotification)
        try? modelContext.save()

        isSending = false
        showingSuccess = true
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

#Preview {
    AdminDashboardView()
        .environment(AppState())
}
