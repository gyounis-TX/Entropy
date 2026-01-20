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
    @Query private var notifications: [Procedus.Notification]
    @Query private var customCategories: [CustomCategory]
    @Query private var customProcedures: [CustomProcedure]
    @Query private var evaluationFields: [EvaluationField]

    @AppStorage("adminName") private var adminNameStorage = ""

    @State private var showingNotifications = false
    @State private var showingInviteCodes = false
    @State private var showingClearDataConfirmation = false
    @State private var showingPopulateDevConfirmation = false
    @State private var devDataPopulated = false

    private var currentProgram: Program? { programs.first }

    private var unreadNotificationCount: Int {
        notifications.filter { !$0.isRead }.count
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

    private var totalCases: Int { allCases.count }

    private var attestedCases: Int {
        allCases.filter { $0.attestationStatus == .attested || $0.attestationStatus == .proxyAttested }.count
    }

    private var pendingCases: Int {
        allCases.filter { $0.attestationStatus == .pending || $0.attestationStatus == .requested }.count
    }

    private var rejectedCases: Int {
        allCases.filter { $0.attestationStatus == .rejected }.count
    }

    private var attestationRate: Double {
        totalCases > 0 ? Double(attestedCases) / Double(totalCases) * 100 : 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header with badge
                    headerSection

                    VStack(spacing: 12) {
                        // Statistics Section
                        statisticsSection

                        // Management Section
                        managementSection

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
                    .padding(.bottom, 32)
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Admin")
                        .font(.headline)
                }
            }
            .sheet(isPresented: $showingNotifications) {
                 NotificationsSheet(role: .admin, userId: nil)
            }
            .sheet(isPresented: $showingInviteCodes) {
                InviteCodesSheet()
            }
            .alert("Clear All Cases & Attestations?", isPresented: $showingClearDataConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) { clearAllCaseData() }
            } message: {
                Text("This will permanently delete ALL cases and attestations. This cannot be undone.")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            // Purple notification badge
            Button {
                showingNotifications = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 44, height: 44)

                    if unreadNotificationCount > 0 {
                        Text("\(unreadNotificationCount)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Management")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
                .padding(.top, 8)

            VStack(spacing: 0) {
                NavigationLink { ManageProgramView() } label: {
                    AdminMenuRow(icon: "gearshape.fill", iconColor: .gray, title: "Manage Program")
                }

                Divider().padding(.leading, 52)

                NavigationLink { FellowManagementView() } label: {
                    AdminMenuRow(icon: "person.2.fill", iconColor: .blue, title: "Manage Fellows", badge: "\(fellowCount)")
                }

                Divider().padding(.leading, 52)

                NavigationLink { AttendingManagementView() } label: {
                    AdminMenuRow(icon: "stethoscope", iconColor: .green, title: "Manage Attendings", badge: "\(attendingCount)")
                }

                Divider().padding(.leading, 52)

                NavigationLink { FacilityManagementView() } label: {
                    AdminMenuRow(icon: "building.2.fill", iconColor: .blue, title: "Manage Facilities")
                }

                Divider().padding(.leading, 52)

                NavigationLink { ManageProceduresView() } label: {
                    AdminMenuRow(icon: "list.clipboard.fill", iconColor: .orange, title: "Manage Procedures")
                }

                Divider().padding(.leading, 52)

                NavigationLink { ManageEvaluationsView() } label: {
                    AdminMenuRow(icon: "checkmark.seal.fill", iconColor: .green, title: "Manage Evaluations", badge: currentProgram?.evaluationsEnabled == true ? "On" : nil, badgeColor: .green)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Reports Section

    private var reportsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reports")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
                .padding(.top, 8)

            VStack(spacing: 0) {
                NavigationLink { AttestationDashboardView() } label: {
                    AdminMenuRow(icon: "checkmark.seal.fill", iconColor: .green, title: "Attestation Dashboard", badge: pendingCases > 0 ? "\(pendingCases) pending" : nil, badgeColor: .orange)
                }

                Divider().padding(.leading, 52)

                NavigationLink { AdminCaseLogView() } label: {
                    AdminMenuRow(icon: "doc.text.fill", iconColor: .blue, title: "Case Log", badge: "\(totalCases) cases")
                }

                Divider().padding(.leading, 52)

                NavigationLink { ProcedureCountsView() } label: {
                    AdminMenuRow(icon: "number.circle.fill", iconColor: .green, title: "Procedure Counts")
                }

                Divider().padding(.leading, 52)

                NavigationLink { ReportsByFellowView() } label: {
                    AdminMenuRow(icon: "person.2.fill", iconColor: .blue, title: "Reports by Fellow")
                }

                Divider().padding(.leading, 52)

                NavigationLink { EvaluationSummaryView() } label: {
                    AdminMenuRow(icon: "star.fill", iconColor: .yellow, title: "Evaluation Summary")
                }

                Divider().padding(.leading, 52)

                NavigationLink { ExportDataView() } label: {
                    AdminMenuRow(icon: "square.and.arrow.up.fill", iconColor: .purple, title: "Export Data")
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Access Section

    private var accessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Access")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
                .padding(.top, 8)

            Button { showingInviteCodes = true } label: {
                AdminMenuRow(icon: "qrcode", iconColor: .purple, title: "Manage Invite Codes", showChevron: true)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Developer Tools Section

    #if DEBUG
    @State private var showingResetDevConfirmation = false

    private var developerToolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Developer Tools")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Image(systemName: "hammer.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            .padding(.leading, 4)
            .padding(.top, 8)

            VStack(spacing: 0) {
                // Populate Dev Program
                Button { showingPopulateDevConfirmation = true } label: {
                    AdminMenuRow(
                        icon: "wand.and.stars",
                        iconColor: .purple,
                        title: "Populate Dev Program",
                        badge: devDataPopulated || currentProgram?.name == "My Great Fellowship" ? "Active" : nil,
                        badgeColor: .green,
                        showChevron: false
                    )
                }
                .disabled(currentProgram?.name == "My Great Fellowship")

                Divider().padding(.leading, 52)

                // Reset Dev Program (only show if dev program is active)
                if currentProgram?.name == "My Great Fellowship" {
                    Button { showingResetDevConfirmation = true } label: {
                        AdminMenuRow(
                            icon: "arrow.counterclockwise",
                            iconColor: .orange,
                            title: "Reset Dev Program",
                            badge: nil,
                            badgeColor: .secondary,
                            showChevron: false
                        )
                    }

                    Divider().padding(.leading, 52)
                }

                // Clear All Cases
                Button { showingClearDataConfirmation = true } label: {
                    AdminMenuRow(icon: "trash.fill", iconColor: .red, title: "Clear All Cases & Attestations", badge: "\(totalCases) cases", badgeColor: .secondary, showChevron: false)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            Text("Dev program includes: 3 cardiology packs, 3 fellows (Simpsons), 3 attendings, 2 facilities, evaluations enabled, and a custom procedure.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
        .alert("Populate Dev Program?", isPresented: $showingPopulateDevConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Populate") { populateDevProgram() }
        } message: {
            Text("This will create 'My Great Fellowship' with test data including 3 fellows, 3 attendings, 2 facilities, cardiology specialty packs, and evaluations enabled.")
        }
        .alert("Reset Dev Program?", isPresented: $showingResetDevConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetDevProgram() }
        } message: {
            Text("This will delete all dev program data including fellows, attendings, facilities, cases, and custom procedures. You will start with a fresh program.")
        }
    }

    private func resetDevProgram() {
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

        // Reset program to fresh state
        if let program = currentProgram {
            program.name = ""
            program.institutionName = ""
            program.specialtyPackIds = []
            program.evaluationsEnabled = false
            program.updatedAt = Date()
        }

        devDataPopulated = false
        try? modelContext.save()
    }
    #endif

    private func clearAllCaseData() {
        for caseEntry in allCases {
            modelContext.delete(caseEntry)
        }
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

        // Enable evaluations with default settings
        program.evaluationsEnabled = true
        program.updatedAt = Date()

        // Create facilities
        let facilityNames = [
            ("University Hospital", "UH"),
            ("Outpatient Lab", "OPL")
        ]
        for (name, shortName) in facilityNames {
            if !facilities.contains(where: { $0.name == name }) {
                let facility = TrainingFacility(name: name)
                facility.shortName = shortName
                facility.programId = program.id
                modelContext.insert(facility)
            }
        }

        // Create fellows (Simpsons)
        let fellowData = [
            ("Homer", "Simpson", "homer@springfield.com", 3),
            ("Marge", "Simpson", "marge@springfield.com", 2),
            ("Bart", "Simpson", "bart@springfield.com", 1)
        ]
        for (first, last, email, year) in fellowData {
            if !allUsers.contains(where: { $0.email == email }) {
                let fellow = User(
                    email: email,
                    firstName: first,
                    lastName: last,
                    role: .fellow,
                    accountMode: .institutional,
                    programId: program.id,
                    trainingYear: year
                )
                modelContext.insert(fellow)
            }
        }

        // Create attendings
        let attendingData = [
            ("Ned", "Flanders", "ned@springfield.com"),
            ("Moe", "Szyslak", "moe@springfield.com"),
            ("Apu", "Nahasapeemapetilon", "apu@springfield.com")
        ]
        for (first, last, email) in attendingData {
            if !attendings.contains(where: { $0.firstName == first && $0.lastName == last }) {
                // Create Attending record
                let attending = Attending(firstName: first, lastName: last)
                attending.programId = program.id
                modelContext.insert(attending)

                // Create linked User for login
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

        // Create custom category
        if !customCategories.contains(where: { $0.name == "Custom Procedures" }) {
            let category = CustomCategory(
                name: "Custom Procedures",
                letter: "C",
                colorHex: "#8B5CF6",
                programId: program.id
            )
            modelContext.insert(category)

            // Create custom procedure in that category
            let customProc = CustomProcedure(
                title: "Test Procedure",
                category: .other,
                programId: program.id,
                creatorId: nil
            )
            customProc.customCategoryId = category.id
            modelContext.insert(customProc)
        }

        // Create default evaluation fields if not exist
        if evaluationFields.isEmpty {
            let defaultFields = [
                "Procedural Competence",
                "Clinical Judgment",
                "Documentation",
                "Professionalism",
                "Communication"
            ]
            for (i, title) in defaultFields.enumerated() {
                let field = EvaluationField(
                    title: title,
                    isRequired: true,
                    displayOrder: i,
                    programId: program.id,
                    isDefault: true
                )
                modelContext.insert(field)
            }
        }

        try? modelContext.save()
        devDataPopulated = true
    }
    #endif
}

// MARK: - Admin Menu Row

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
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.body)
                .foregroundColor(Color(UIColor.label))

            Spacer()

            if let badge = badge {
                Text(badge)
                    .font(.subheadline)
                    .foregroundColor(badgeColor)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

    private var procedureCounts: [(procedure: String, count: Int)] {
        var counts: [String: Int] = [:]
        for caseEntry in allCases {
            for procedureId in caseEntry.procedureTagIds {
                let title = SpecialtyPackCatalog.findProcedureTitle(for: procedureId) ?? procedureId
                counts[title, default: 0] += 1
            }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }

    var body: some View {
        List {
            if procedureCounts.isEmpty {
                ContentUnavailableView(
                    "No Procedures",
                    systemImage: "list.clipboard",
                    description: Text("No procedures have been logged yet.")
                )
            } else {
                ForEach(procedureCounts, id: \.procedure) { item in
                    HStack {
                        Text(item.procedure)
                            .font(.subheadline)
                        Spacer()
                        Text("\(item.count)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Procedure Counts")
        .navigationBarTitleDisplayMode(.inline)
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

                // Statistics Section
                statisticsSection

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

                    // Program Code (auto-generated)
                    ProgramCodeRow(label: "Program Code", code: program.programCode)
                    Divider().padding(.leading, 16)

                    // Edit Details Button
                    Button { showingEditProgram = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                            Text("Edit Details")
                                .font(.body)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

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
                    Text("Enter your program and institution name. The program code will be generated automatically.")
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
                }
            }
        }
    }

    private func save() {
        if let program = program {
            program.name = name.trimmingCharacters(in: .whitespaces)
            program.institutionName = institutionName.trimmingCharacters(in: .whitespaces)
            // Program code is auto-generated and not editable
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
            CategoryBubble(category: packCategory.category, size: 28)
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
                        } else {
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
            AddEditFellowSheet(fellow: nil, maxTrainingYear: currentProgram?.trainingProgramLength ?? 10)
        }
        .sheet(item: $selectedFellow) { fellow in
            AddEditFellowSheet(fellow: fellow, maxTrainingYear: currentProgram?.trainingProgramLength ?? 10)
        }
        .alert("Graduate Fellow?", isPresented: $showingGraduateConfirm) {
            Button("Cancel", role: .cancel) { fellowToGraduate = nil }
            Button("Graduate") {
                if let fellow = fellowToGraduate {
                    fellow.hasGraduated = true
                    fellow.graduatedAt = Date()
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

                    if let year = fellow.trainingYear {
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

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var trainingYear = 1
    @State private var showingGraduateConfirm = false
    @State private var showingUngraduateConfirm = false

    init(fellow: User?, maxTrainingYear: Int = 10) {
        self.fellow = fellow
        self.maxTrainingYear = maxTrainingYear
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
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    Picker("Training Year", selection: $trainingYear) {
                        ForEach(1...maxTrainingYear, id: \.self) { year in
                            Text("PGY-\(year)").tag(year)
                        }
                    }
                } header: {
                    Text("Fellow Information")
                } footer: {
                    Text("Email is required for the fellow to join the program with an invite code.")
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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(firstName.isEmpty || lastName.isEmpty)
                }
            }
            .onAppear {
                if let fellow = fellow {
                    firstName = fellow.firstName
                    lastName = fellow.lastName
                    email = fellow.email
                    trainingYear = fellow.trainingYear ?? 1
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

    @State private var showingAddAttending = false
    @State private var selectedAttending: Attending?
    @State private var selectedTab = 0  // 0 = Active, 1 = Archived

    private var activeAttendings: [Attending] {
        attendings.filter { !$0.isArchived }.sorted { $0.name < $1.name }
    }

    private var archivedAttendings: [Attending] {
        attendings.filter { $0.isArchived }.sorted { $0.name < $1.name }
    }

    private func caseCount(for attending: Attending) -> Int {
        allCases.filter { $0.attendingId == attending.id }.count
    }

    private func canDelete(attending: Attending) -> Bool {
        caseCount(for: attending) == 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Segmented Control
                Picker("View", selection: $selectedTab) {
                    Text("Active (\(activeAttendings.count))").tag(0)
                    Text("Archived (\(archivedAttendings.count))").tag(1)
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
            Text(attending.name)
                .font(.body)
                .foregroundColor(Color(UIColor.label))

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
                    TextField("Short Name (optional)", text: $shortName)
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
                        .disabled(name.isEmpty)
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
                                CustomCategoryBubble(category: category, size: 28)
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
                            Divider().padding(.leading, 60)
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

    @State private var showingAddCustomItem = false

    private var program: Program? { programs.first }

    private let defaultEvaluationItems = [
        "Demonstrates appropriate preparation",
        "Demonstrates appropriate knowledge",
        "Demonstrates technical proficiency",
        "Communicates effectively",
        "Maintains situational awareness",
        "Manages complications appropriately",
        "Shows professional behavior"
    ]

    private var customFields: [EvaluationField] {
        evaluationFields.filter { !$0.isDefault && !$0.isArchived }
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

                    // Default Evaluation Items
                    if program?.evaluationsEnabled == true {
                        Section {
                            Button {
                                selectAllDefaults()
                            } label: {
                                Label("Use All Default Items", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }

                            ForEach(defaultEvaluationItems, id: \.self) { item in
                                let isSelected = program?.evaluationItems.contains(item) ?? false
                                Button {
                                    toggleDefaultItem(item)
                                } label: {
                                    HStack {
                                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                            .foregroundColor(isSelected ? .blue : Color(UIColor.tertiaryLabel))
                                        Text(item)
                                            .font(.subheadline)
                                            .foregroundColor(Color(UIColor.label))
                                    }
                                }
                            }
                        } header: {
                            Text("Default Evaluation Items")
                        }

                        // Custom Evaluation Items
                        Section {
                            if customFields.isEmpty {
                                Text("No custom items")
                                    .font(.subheadline)
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                    .italic()
                            } else {
                                ForEach(customFields) { field in
                                    Text(field.title)
                                        .font(.subheadline)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                modelContext.delete(field)
                                                try? modelContext.save()
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }

                            Button { showingAddCustomItem = true } label: {
                                Label("Add Custom Item", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        } header: {
                            Text("Custom Evaluation Items")
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Evaluations")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddCustomItem) {
            AddCustomEvaluationItemSheet()
        }
    }

    private func selectAllDefaults() {
        guard let program = program else { return }
        program.evaluationItems = defaultEvaluationItems
        program.updatedAt = Date()
        try? modelContext.save()
    }

    private func toggleDefaultItem(_ item: String) {
        guard let program = program else { return }
        if program.evaluationItems.contains(item) {
            program.evaluationItems.removeAll { $0 == item }
        } else {
            program.evaluationItems.append(item)
        }
        program.updatedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Add Custom Evaluation Item Sheet

struct AddCustomEvaluationItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var programs: [Program]

    @State private var title = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Evaluation Criteria", text: $title)
                } footer: {
                    Text("Enter the evaluation criteria that attendings will assess.")
                }
            }
            .navigationTitle("Add Evaluation Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let field = EvaluationField(title: title, programId: programs.first?.id)
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

// MARK: - Attestation Dashboard View

struct AttestationDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allCases: [CaseEntry]
    @Query private var allUsers: [User]
    @Query private var attendings: [Attending]

    @State private var filterStatus: AttestationStatus? = nil
    @State private var filterFellowId: UUID? = nil
    @State private var filterAttendingId: UUID? = nil
    @State private var showingProxyAttestation = false
    @State private var caseForProxy: CaseEntry?

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

        return cases.sorted { $0.createdAt > $1.createdAt }
    }

    private var fellows: [User] {
        allUsers.filter { $0.role == .fellow }.sorted { $0.displayName < $1.displayName }
    }

    private var activeAttendings: [Attending] {
        attendings.filter { !$0.isArchived }.sorted { $0.name < $1.name }
    }

    private var proxyAttestedCases: [CaseEntry] {
        allCases.filter { $0.isProxyAttestation }
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
        .alert("Proxy Attestation", isPresented: $showingProxyAttestation) {
            Button("Cancel", role: .cancel) { caseForProxy = nil }
            Button("Attest") { performProxyAttestation() }
        } message: {
            proxyAttestationMessage
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

    private func performProxyAttestation() {
        if let caseEntry = caseForProxy {
            caseEntry.attestationStatus = .proxyAttested
            caseEntry.isProxyAttestation = true
            caseEntry.attestedAt = Date()
            try? modelContext.save()
        }
        caseForProxy = nil
    }

    private var proxyAttestationMessage: Text {
        if let caseEntry = caseForProxy,
           let attendingId = caseEntry.attendingId ?? caseEntry.supervisorId,
           let attending = attendings.first(where: { $0.id == attendingId }) {
            return Text("I have proxy authorization from \(attending.name) to attest this case.")
        } else {
            return Text("Are you sure you want to attest this case by proxy?")
        }
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
            }

            Text(caseEntry.weekBucket.toWeekTimeframeLabel())
                .font(.caption)
                .foregroundColor(Color(UIColor.tertiaryLabel))

            Text("\(caseEntry.procedureTagIds.count) procedures")
                .font(.caption)
                .foregroundColor(Color(UIColor.tertiaryLabel))
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

    private var filteredCases: [CaseEntry] {
        var cases = allCases

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
        allUsers.filter { $0.role == .fellow }.sorted { $0.displayName < $1.displayName }
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
        .navigationTitle("Procedure Log")
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
        allUsers.filter { $0.role == .fellow }.sorted { $0.displayName < $1.displayName }
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

    private var procedureCounts: [(String, Int)] {
        var counts: [String: Int] = [:]
        for caseEntry in fellowCases {
            for tagId in caseEntry.procedureTagIds {
                if let procedure = SpecialtyPackCatalog.findProcedure(by: tagId) {
                    counts[procedure.title, default: 0] += 1
                } else if tagId.hasPrefix("custom-") {
                    counts["Custom Procedure", default: 0] += 1
                }
            }
        }
        return counts.sorted { $0.value > $1.value }
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

            Section {
                if procedureCounts.isEmpty {
                    Text("No procedures logged")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .italic()
                } else {
                    ForEach(procedureCounts, id: \.0) { (name, count) in
                        HStack {
                            Text(name)
                                .font(.subheadline)
                            Spacer()
                            Text("\(count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
            } header: {
                Text("Procedure Counts")
            }
        }
        .navigationTitle(fellow.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Evaluation Summary View

struct EvaluationSummaryView: View {
    @Query private var allUsers: [User]
    @Query private var allCases: [CaseEntry]

    private var fellows: [User] {
        allUsers.filter { $0.role == .fellow }.sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        List {
            ForEach(fellows) { fellow in
                let fellowCases = allCases.filter { ($0.fellowId == fellow.id || $0.ownerId == fellow.id) && !$0.evaluationChecks.isEmpty }

                if !fellowCases.isEmpty {
                    NavigationLink {
                        FellowEvaluationDetailView(fellow: fellow, cases: fellowCases)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fellow.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(fellowCases.count) evaluations")
                                .font(.caption)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        }
                    }
                }
            }

            if fellows.allSatisfy({ fellow in
                allCases.filter { ($0.fellowId == fellow.id || $0.ownerId == fellow.id) && !$0.evaluationChecks.isEmpty }.isEmpty
            }) {
                Text("No evaluations recorded yet")
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .italic()
            }
        }
        .navigationTitle("Evaluation Summary")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Fellow Evaluation Detail View

struct FellowEvaluationDetailView: View {
    let fellow: User
    let cases: [CaseEntry]

    @State private var showingExport = false

    private var evaluationCounts: [(String, Int)] {
        var counts: [String: Int] = [:]
        for caseEntry in cases {
            for check in caseEntry.evaluationChecks {
                counts[check, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }

    private var comments: [String] {
        cases.compactMap { $0.evaluationComment }.filter { !$0.isEmpty }
    }

    var body: some View {
        List {
            Section {
                ForEach(evaluationCounts, id: \.0) { (item, count) in
                    HStack {
                        Text(item)
                            .font(.subheadline)
                        Spacer()
                        Text("\(count)/\(cases.count)")
                            .font(.subheadline)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                }
            } header: {
                Text("Evaluation Metrics")
            }

            if !comments.isEmpty {
                Section {
                    ForEach(comments, id: \.self) { comment in
                        Text(comment)
                            .font(.subheadline)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                } header: {
                    Text("Comments (\(comments.count))")
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
            ExportEvaluationSheet(fellow: fellow, cases: cases)
        }
    }
}

// MARK: - Export Evaluation Sheet

struct ExportEvaluationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let fellow: User
    let cases: [CaseEntry]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { exportToExcel() } label: {
                        Label("Export to Excel", systemImage: "tablecells")
                    }
                    Button { exportToPDF() } label: {
                        Label("Export to PDF", systemImage: "doc.richtext")
                    }
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

    private func exportToExcel() {
        // Implementation would use ExportService
        dismiss()
    }

    private func exportToPDF() {
        // Implementation would use ExportService
        dismiss()
    }
}

// MARK: - Export Data View

struct ExportDataView: View {
    @Query private var allUsers: [User]

    @State private var exportType = "log"
    @State private var exportFormat = "csv"
    @State private var selectedFellowId: UUID? = nil

    private var fellows: [User] {
        allUsers.filter { $0.role == .fellow }.sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        List {
            Section {
                Picker("Export Type", selection: $exportType) {
                    Text("Procedure Log").tag("log")
                    Text("Procedure Counts").tag("counts")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Export Type")
            } footer: {
                if exportType == "log" {
                    Text("Detailed list of procedures by date, attending, and outcome.")
                } else {
                    Text("Totals grouped by procedure and category.")
                }
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
                    Label("Export All Fellows", systemImage: "arrow.down.doc.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            } header: {
                Text("Full Export")
            }

            Section {
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
            } header: {
                Text("Export by Fellow")
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exportAll() {
        // Implementation would use ExportService
    }

    private func exportForFellow(_ fellow: User) {
        // Implementation would use ExportService
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

// MARK: - Notifications Sheet

struct NotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var notifications: [Procedus.Notification]

    let role: UserRole
    let userId: UUID?

    private var relevantNotifications: [Procedus.Notification] {
        var filtered = notifications.filter { !$0.isCleared }
        if let userId = userId {
            filtered = filtered.filter { $0.userId == userId || $0.attendingId == userId }
        }
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            List {
                if relevantNotifications.isEmpty {
                    Text("No notifications")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .italic()
                } else {
                    ForEach(relevantNotifications) { notification in
                        NotificationRow(notification: notification)
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
                if !relevantNotifications.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") {
                            for notification in relevantNotifications {
                                notification.isCleared = true
                                notification.clearedAt = Date()
                            }
                            try? modelContext.save()
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: Procedus.Notification

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
            Text(notification.message)
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
                .lineLimit(2)
        }
        .padding(.vertical, 4)
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
