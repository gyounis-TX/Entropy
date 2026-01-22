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
    @Query private var customAccessSites: [CustomAccessSite]
    @Query private var customComplications: [CustomComplication]
    @Query private var customProcedureDetails: [CustomProcedureDetail]
    @Query private var evaluationFields: [EvaluationField]

    @AppStorage("adminName") private var adminNameStorage = ""

    @State private var showingNotifications = false
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

    // Admin doesn't receive notifications - they send them to others
    // This count shows only admin-specific notifications (currently none)
    private var unreadNotificationCount: Int {
        0  // Admin role sends notifications, doesn't receive them
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

                        // Communications Section
                        communicationsSection

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

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            // Admin notification bell (purple for admin role)
            Button {
                showingNotifications = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.purple)  // Purple for admin
                        .frame(width: 44, height: 44)

                    Image(systemName: "bell.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)

                    // Notification count badge in center of bell
                    if unreadNotificationCount > 0 {
                        Text("\(unreadNotificationCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.purple)
                            .padding(4)
                            .background(Circle().fill(.white))
                            .offset(y: 2)  // Centered in bell
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

    // MARK: - Reports Section

    private var reportsSection: some View {
        VStack(spacing: 8) {
            AdminSectionHeader(title: "REPORTS")

            NavigationLink { AttestationDashboardView() } label: {
                AdminPillRow(icon: "checkmark.seal.fill", iconColor: .green, title: "Attestation Dashboard", statusBadge: pendingCases > 0 ? "\(pendingCases) pending" : nil, statusColor: .orange)
            }

            NavigationLink { AdminCaseLogView() } label: {
                AdminPillRow(icon: "doc.text.fill", iconColor: .blue, title: "Case Log", subtitle: "\(totalCases) cases")
            }

            NavigationLink { ProcedureCountsView() } label: {
                AdminPillRow(icon: "number.circle.fill", iconColor: .green, title: "Procedure Counts")
            }

            NavigationLink { ReportsByFellowView() } label: {
                AdminPillRow(icon: "person.2.fill", iconColor: .blue, title: "Reports by Fellow")
            }

            NavigationLink { EvaluationSummaryView() } label: {
                AdminPillRow(icon: "star.fill", iconColor: .yellow, title: "Evaluation Summary")
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

    // MARK: - Communications Section

    private var communicationsSection: some View {
        VStack(spacing: 8) {
            AdminSectionHeader(title: "COMMUNICATIONS")

            Button { showingProgramMessage = true } label: {
                AdminPillRow(icon: "paperplane.fill", iconColor: .blue, title: "Send Message")
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

        // Set fellowship specialty to Cardiology
        program.fellowshipSpecialty = .cardiology

        // Enable evaluations with default settings
        program.evaluationsEnabled = true
        program.updatedAt = Date()

        // Create facilities - track IDs as we create
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

        // Create admin users - Cindy Crabapple and Lionel Hutz
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

        // Clean up old admin with wrong email
        if let oldAdmin = allUsers.first(where: { $0.email == "krabappel@springfield.com" }) {
            oldAdmin.email = "crabapple@springfield.com"
            oldAdmin.firstName = "Cindy"
            oldAdmin.lastName = "Crabapple"
        }

        // Create fellows (Simpsons) - track IDs as we create
        var createdFellowIds: [UUID] = []
        let fellowData = [
            ("Homer", "Simpson", "homer@springfield.com", 3),
            ("Marge", "Simpson", "marge@springfield.com", 2),
            ("Bart", "Simpson", "bart@springfield.com", 1)
        ]
        for (first, last, email, year) in fellowData {
            if let existing = allUsers.first(where: { $0.email == email }) {
                createdFellowIds.append(existing.id)
            } else {
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
                createdFellowIds.append(fellow.id)
            }
        }

        // Create attendings - track IDs as we create
        var createdAttendingIds: [UUID] = []
        let attendingData = [
            ("Ned", "Flanders", "ned@springfield.com"),
            ("Moe", "Szyslak", "moe@springfield.com"),
            ("Apu", "Nahasapeemapetilon", "apu@springfield.com")
        ]
        for (first, last, email) in attendingData {
            if let existing = attendings.first(where: { $0.firstName == first && $0.lastName == last }) {
                createdAttendingIds.append(existing.id)
            } else {
                // Create Attending record
                let attending = Attending(firstName: first, lastName: last)
                attending.programId = program.id
                modelContext.insert(attending)
                createdAttendingIds.append(attending.id)

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
            let defaultFields: [(title: String, description: String)] = [
                ("Procedural Competence", "Technical skill execution, proper technique, appropriate equipment handling, and ability to complete procedure safely and efficiently."),
                ("Clinical Judgment", "Appropriate patient selection, recognition of complications, ability to adapt to unexpected findings, and sound decision-making during the procedure."),
                ("Documentation", "Accurate, complete, and timely documentation of the procedure, findings, complications, and follow-up plan."),
                ("Professionalism", "Appropriate communication with team members, respectful patient interactions, and adherence to ethical standards."),
                ("Communication", "Clear explanation of procedure to patient and family, effective team communication during procedure, and appropriate handoff to receiving team.")
            ]
            for (i, fieldInfo) in defaultFields.enumerated() {
                let field = EvaluationField(
                    title: fieldInfo.title,
                    descriptionText: fieldInfo.description,
                    fieldType: .rating,  // Use rating type for default fields
                    isRequired: true,
                    displayOrder: i,
                    programId: program.id,
                    isDefault: true
                )
                modelContext.insert(field)
            }
        }

        // Create 20 sample cases (10 invasive + 10 noninvasive)
        let calendar = Calendar.current
        let icPack = SpecialtyPackCatalog.pack(for: "interventional-cardiology")
        let invasiveProcedures = icPack?.categories.flatMap { $0.procedures.map { $0.id } } ?? []
        let ciPack = SpecialtyPackCatalog.pack(for: "cardiac-imaging")
        let noninvasiveProcedures = ciPack?.categories.flatMap { $0.procedures.map { $0.id } } ?? []

        // Access sites for IC procedures
        let icAccessSites: [AccessSite] = [.femoral, .radial, .brachial, .pedal]
        let operatorPositions: [OperatorPosition] = [.primary, .secondary]

        // Sample case notes
        let sampleNotes = [
            "Successful PCI to mid-LAD with DES. Patient tolerated well. No complications.",
            "Diagnostic cath showed severe 3VD. Referred to CT surgery for CABG evaluation.",
            "Right heart cath for pulmonary HTN workup. Mean PA pressure 38mmHg.",
            "Elective PCI to RCA. Used radial access with 6Fr guide. Good angiographic result.",
            "Complex bifurcation lesion. Used 2-stent technique with good final result.",
            "Chronic total occlusion attempt. Achieved antegrade crossing after 90 mins.",
            "Impella-supported high-risk PCI in patient with EF 20%. No hemodynamic issues.",
            "STEMI activation - door to balloon 45 minutes. Culprit LAD, good flow restored.",
            "Structural case - TAVR workup. Anatomy suitable for transfemoral approach.",
            "EP study for syncope workup. No inducible arrhythmias. Plan for ILR."
        ]

        let noninvasiveNotes = [
            "TTE showing preserved EF at 60%. No significant valvular disease.",
            "Stress echo with borderline ischemia in inferior wall. Correlation needed.",
            "TEE for afib cardioversion. No LAA thrombus identified. Cleared for DCCV.",
            "Carotid ultrasound showing 50-69% stenosis on right. Medical management.",
            "Lower extremity venous duplex negative for DVT bilaterally.",
            "Renal artery duplex showing no significant stenosis. RAS excluded.",
            "AAA surveillance - stable at 4.2cm. Continue annual monitoring.",
            "Bubble study positive. PFO identified. Consider closure if cryptogenic stroke.",
            "Dobutamine stress echo - no inducible ischemia at peak dose.",
            "Right heart catheterization and TTE correlation for MR quantification."
        ]

        if !createdFellowIds.isEmpty && !createdAttendingIds.isEmpty && !createdFacilityIds.isEmpty && !invasiveProcedures.isEmpty {
            // Spread cases over 3 years (156 weeks) for realistic analytics data
            let threeYearsInWeeks = 156

            // Create 10 invasive cases
            for i in 0..<10 {
                let weeksAgo = Int.random(in: 0...threeYearsInWeeks)
                let caseDate = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: Date()) ?? Date()
                let weekBucket = CaseEntry.makeWeekBucket(for: caseDate)

                let randomFellowId = createdFellowIds.randomElement()!
                let newCase = CaseEntry(
                    fellowId: randomFellowId,
                    ownerId: randomFellowId,
                    attendingId: createdAttendingIds.randomElement(),
                    weekBucket: weekBucket,
                    facilityId: createdFacilityIds.randomElement()
                )
                newCase.programId = program.id

                let numProcedures = Int.random(in: 1...3)
                newCase.procedureTagIds = Array(invasiveProcedures.shuffled().prefix(numProcedures))
                newCase.createdAt = caseDate
                newCase.caseTypeRaw = CaseType.invasive.rawValue

                let numAccessSites = Int.random(in: 1...2)
                newCase.accessSiteIds = Array(icAccessSites.shuffled().prefix(numAccessSites)).map { $0.rawValue }
                newCase.operatorPositionRaw = operatorPositions.randomElement()?.rawValue
                newCase.notes = sampleNotes[i]
                newCase.attestationStatusRaw = AttestationStatus.pending.rawValue

                modelContext.insert(newCase)

                // Create attestation notification for attending
                if let attendingId = newCase.attendingId {
                    let fellowName = allUsers.first(where: { $0.id == randomFellowId })?.lastName ?? "Fellow"
                    let procedureTitles = newCase.procedureTagIds.compactMap { tagId in
                        SpecialtyPackCatalog.findProcedure(by: tagId)?.title
                    }
                    let procedureList = procedureTitles.prefix(3).joined(separator: ", ")
                    let suffix = procedureTitles.count > 3 ? " + \(procedureTitles.count - 3) more" : ""
                    let message = procedureTitles.isEmpty ?
                        "\(fellowName) submitted a case with \(newCase.procedureTagIds.count) procedure(s) for your attestation." :
                        "\(fellowName) submitted a case with \(procedureList)\(suffix) for your attestation."

                    let notification = Procedus.Notification(
                        userId: attendingId,
                        title: "New Case for Attestation",
                        message: message,
                        notificationType: NotificationType.attestationRequested.rawValue,
                        caseId: newCase.id,
                        attendingId: attendingId
                    )
                    notification.createdAt = caseDate  // Match the case creation date
                    modelContext.insert(notification)
                }
            }

            // Create 10 noninvasive cases (1 procedure per case as per imaging logging convention)
            if !noninvasiveProcedures.isEmpty {
                for i in 0..<10 {
                    let weeksAgo = Int.random(in: 0...threeYearsInWeeks)
                    let caseDate = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: Date()) ?? Date()
                    let weekBucket = CaseEntry.makeWeekBucket(for: caseDate)

                    let randomFellowId = createdFellowIds.randomElement()!
                    let newCase = CaseEntry(
                        fellowId: randomFellowId,
                        ownerId: randomFellowId,
                        attendingId: nil,
                        weekBucket: weekBucket,
                        facilityId: createdFacilityIds.randomElement()
                    )
                    newCase.programId = program.id

                    // Noninvasive cases have exactly 1 procedure per case (imaging study)
                    newCase.procedureTagIds = [noninvasiveProcedures.randomElement()!]
                    newCase.createdAt = caseDate
                    newCase.caseTypeRaw = CaseType.noninvasive.rawValue
                    newCase.attestationStatusRaw = AttestationStatus.notRequired.rawValue
                    newCase.notes = noninvasiveNotes[i]

                    modelContext.insert(newCase)
                }
            }
        }

        try? modelContext.save()
        devDataPopulated = true
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
    @Query private var evaluationFields: [EvaluationField]
    @Query private var attendings: [Attending]

    @State private var sortOption: EvaluationSortOption = .fellowName
    @State private var filterPGY: Int? = nil
    @State private var showingFilters = false

    enum EvaluationSortOption: String, CaseIterable {
        case fellowName = "Name"
        case pgyYear = "PGY Year"
        case evaluationCount = "Evaluations"
        case averageRating = "Avg Rating"
    }

    private var fellows: [User] {
        var list = allUsers.filter { $0.role == .fellow && !$0.isArchived }
        if let pgy = filterPGY {
            list = list.filter { $0.trainingYear == pgy }
        }
        return list.sorted { sortComparison($0, $1) }
    }

    private func sortComparison(_ a: User, _ b: User) -> Bool {
        switch sortOption {
        case .fellowName:
            return a.displayName < b.displayName
        case .pgyYear:
            return (a.trainingYear ?? 0) < (b.trainingYear ?? 0)
        case .evaluationCount:
            return casesWithEvaluations(for: a).count > casesWithEvaluations(for: b).count
        case .averageRating:
            return averageRating(for: a) > averageRating(for: b)
        }
    }

    private func casesWithEvaluations(for fellow: User) -> [CaseEntry] {
        allCases.filter {
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
            // Sort/Filter Section
            Section {
                HStack {
                    Text("Sort by")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    Spacer()
                    Picker("Sort", selection: $sortOption) {
                        ForEach(EvaluationSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Text("Filter PGY")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    Spacer()
                    Picker("PGY", selection: $filterPGY) {
                        Text("All").tag(nil as Int?)
                        ForEach(1...7, id: \.self) { year in
                            Text("PGY-\(year)").tag(year as Int?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            // Fellows List
            Section {
                if !hasAnyEvaluations {
                    Text("No evaluations recorded yet")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .italic()
                } else {
                    ForEach(fellows) { fellow in
                        let fellowCases = casesWithEvaluations(for: fellow)

                        if !fellowCases.isEmpty {
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
                                        HStack(spacing: 8) {
                                            if let pgy = fellow.trainingYear {
                                                Text("PGY-\(pgy)")
                                                    .font(.caption)
                                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                            }
                                            Text("\(fellowCases.count) evaluations")
                                                .font(.caption)
                                                .foregroundColor(Color(UIColor.secondaryLabel))
                                        }
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
                    }
                }
            }
        }
        .navigationTitle("Evaluation Summary")
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
            caseEntry.createdAt >= startDate && caseEntry.createdAt <= endDate
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

    enum TargetAudience: String, CaseIterable, Identifiable {
        case all = "All Members"
        case fellowsOnly = "Fellows Only"
        case attendingsOnly = "Attendings Only"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .all: return "person.3.fill"
            case .fellowsOnly: return "person.2.fill"
            case .attendingsOnly: return "stethoscope"
            }
        }
    }

    private var recipientCount: Int {
        switch targetAudience {
        case .all: return fellows.count + attendings.count
        case .fellowsOnly: return fellows.count
        case .attendingsOnly: return attendings.count
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
        guard let program = program else { return }
        isSending = true

        // Create a conversation ID for grouping replies
        let conversationId = UUID()

        // Get sender info
        let senderId = currentAdmin?.id
        let senderName = currentAdmin?.displayName ?? "Program Admin"

        // Get recipient user IDs based on target audience
        let recipientIds: [UUID]
        switch targetAudience {
        case .all:
            recipientIds = (fellows + attendings).map { $0.id }
        case .fellowsOnly:
            recipientIds = fellows.map { $0.id }
        case .attendingsOnly:
            recipientIds = attendings.map { $0.id }
        }

        // Create notification records for each recipient
        for userId in recipientIds {
            let notification = Procedus.Notification(
                userId: userId,
                title: messageTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                message: messageBody.trimmingCharacters(in: .whitespacesAndNewlines),
                notificationType: NotificationType.programUpdate.rawValue
            )
            // Set sender tracking
            notification.senderId = senderId
            notification.senderName = senderName
            notification.senderRoleRaw = UserRole.admin.rawValue
            notification.conversationId = conversationId
            modelContext.insert(notification)
        }

        try? modelContext.save()

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

    @State private var selectedCategory: NotificationCategory = .attestations
    @State private var notificationToReply: Procedus.Notification?

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
                return [
                    NotificationType.programUpdate.rawValue,
                    NotificationType.programChange.rawValue,
                    NotificationType.procedureAdded.rawValue,
                    NotificationType.categoryAdded.rawValue,
                    NotificationType.userInvite.rawValue,
                    NotificationType.reminder.rawValue,
                    NotificationType.info.rawValue
                ]
            }
        }
    }

    private var allRelevantNotifications: [Procedus.Notification] {
        // Admin role doesn't receive notifications - they only send them
        // If no userId provided for non-admin, return empty
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

    private var attestationNotifications: [Procedus.Notification] {
        allRelevantNotifications.filter { NotificationCategory.attestations.notificationTypes.contains($0.notificationType) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Picker - simplified to avoid rendering bugs with counts
                Picker("Category", selection: $selectedCategory) {
                    Text(attestationCount > 0 ? "Attestations (\(attestationCount))" : "Attestations")
                        .tag(NotificationCategory.attestations)
                    Text(messagesCount > 0 ? "Messages (\(messagesCount))" : "Messages")
                        .tag(NotificationCategory.messages)
                }
                .pickerStyle(.segmented)
                .padding()

                // Clear Attestations button for attending role
                if role == .attending && !attestationNotifications.isEmpty && selectedCategory == .attestations {
                    Button {
                        clearAttestationNotifications()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Clear All Attestation Notifications")
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
                if !filteredNotifications.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") {
                            for notification in filteredNotifications {
                                notification.isCleared = true
                                notification.clearedAt = Date()
                            }
                            try? modelContext.save()
                        }
                        .font(.subheadline)
                    }
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

    private func clearAttestationNotifications() {
        for notification in attestationNotifications {
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

    private var isMessageType: Bool {
        let messageTypes = [
            NotificationType.programUpdate.rawValue,
            NotificationType.programChange.rawValue,
            NotificationType.info.rawValue
        ]
        return messageTypes.contains(notification.notificationType)
    }

    private var canReply: Bool {
        isMessageType && notification.senderId != nil
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
                .lineLimit(2)

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

        // Create reply notification for the original sender
        let replyNotification = Procedus.Notification(
            userId: recipientId,
            title: "Reply: \(originalNotification.title)",
            message: replyMessage.trimmingCharacters(in: .whitespacesAndNewlines),
            notificationType: NotificationType.programUpdate.rawValue
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
