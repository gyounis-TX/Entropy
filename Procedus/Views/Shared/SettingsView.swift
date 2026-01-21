import SwiftUI
import SwiftData
import CommonCrypto

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query private var attendings: [Attending]
    @Query private var facilities: [TrainingFacility]
    @Query private var customProcedures: [CustomProcedure]
    @Query private var customAccessSites: [CustomAccessSite]
    @Query private var customComplications: [CustomComplication]
    @Query private var notifications: [Procedus.Notification]
    @Query private var allUsers: [User]
    @Query private var procedureGroups: [FellowProcedureGroup]
    @Query private var customProcedureDetails: [CustomProcedureDetail]
    @Query private var programs: [Program]

    private var currentProgram: Program? { programs.first }

    @AppStorage("isPasscodeSet") private var isPasscodeSet = false
    @AppStorage("isBiometricsEnabled") private var isBiometricsEnabled = false
    @AppStorage("cloudBackupEnabled") private var cloudBackupEnabled = false

    // Sheet states
    @State private var showingProfileEdit = false
    @State private var showingSecuritySettings = false
    @State private var showingCloudBackup = false
    @State private var showingAttendingsList = false
    @State private var showingFacilitiesList = false
    @State private var showingSpecialtyPacks = false
    @State private var showingCustomProcedures = false
    @State private var showingCustomAccessSites = false
    @State private var showingCustomComplications = false
    @State private var showingCustomProcedureDetails = false
    @State private var showingExportOptions = false
    @State private var showingImportLog = false
    @State private var showingAbout = false
    @State private var showingDevInstitutional = false
    @State private var showingInstitutionalProfileEdit = false

    // Notification settings
    @AppStorage("pushNotificationsEnabled") private var pushNotificationsEnabled = false
    @AppStorage("attestationAlertsEnabled") private var attestationAlertsEnabled = true
    @AppStorage("rejectedCasesAlertsEnabled") private var rejectedCasesAlertsEnabled = true
    @State private var showingNotificationsSheet = false

    // Identity selection sheets
    @State private var showingFellowIdentityPicker = false
    @State private var showingAttendingIdentityPicker = false
    @State private var showingDefaultFacilityPicker = false
    @State private var showingMigrationWizard = false
    @State private var showingProcedureGroups = false

    // Individual dev mode
    @State private var showingPopulateIndividualDevConfirmation = false
    @State private var showingResetIndividualDevConfirmation = false

    // Fellowship specialty picker
    @State private var showingFellowshipSpecialtyPicker = false

    private var unreadNotificationCount: Int {
        guard let userId = appState.currentUser?.id else { return 0 }
        return notifications.filter { $0.userId == userId && !$0.isRead }.count
    }

    // Counts
    private var activeAttendingsCount: Int {
        attendings.filter { !$0.isArchived }.count
    }

    private var activeFacilitiesCount: Int {
        facilities.filter { !$0.isArchived }.count
    }

    private var enabledPacksCount: Int {
        appState.enabledSpecialtyPackIds.count
    }

    private var procedureGroupsCount: Int {
        guard let fellowIdString = UserDefaults.standard.string(forKey: "selectedFellowId"),
              let fellowId = UUID(uuidString: fellowIdString) else { return 0 }
        return procedureGroups.filter { !$0.isArchived && $0.creatorId == fellowId }.count
    }

    private var activeCustomProceduresCount: Int {
        customProcedures.filter { !$0.isArchived }.count
    }

    private var activeCustomAccessSitesCount: Int {
        customAccessSites.filter { !$0.isArchived }.count
    }

    private var activeCustomComplicationsCount: Int {
        customComplications.filter { !$0.isArchived }.count
    }

    private var activeCustomProcedureDetailsCount: Int {
        customProcedureDetails.filter { !$0.isArchived }.count
    }

    #if DEBUG
    private var hasIndividualDevData: Bool {
        // Check if we have any attendings with "Simpson" in the name (from dev data)
        attendings.contains { $0.name.contains("Simpson") }
    }
    #endif

    // Active fellows (for identity selection)
    private var activeFellows: [User] {
        allUsers.filter { $0.role == .fellow && !$0.hasGraduated }
            .sorted { $0.displayName < $1.displayName }
    }

    // Active attendings (for identity selection)
    private var activeAttendingsForSelection: [Attending] {
        attendings.filter { !$0.isArchived }
            .sorted { $0.name < $1.name }
    }

    // Active facilities
    private var activeFacilities: [TrainingFacility] {
        facilities.filter { !$0.isArchived }
            .sorted { $0.name < $1.name }
    }

    // Selected fellow name
    private var selectedFellowName: String {
        if let fellowId = appState.selectedFellowId,
           let fellow = activeFellows.first(where: { $0.id == fellowId }) {
            return fellow.displayName
        }
        return "Not Selected"
    }

    // Default facility name
    private var defaultFacilityName: String {
        if let facilityId = appState.defaultFacilityId,
           let facility = activeFacilities.first(where: { $0.id == facilityId }) {
            return facility.name
        }
        return "Not Set"
    }

    // Selected attending name
    private var selectedAttendingName: String {
        if let attendingId = appState.selectedAttendingId,
           let attending = activeAttendingsForSelection.first(where: { $0.id == attendingId }) {
            return attending.name
        }
        return "Not Selected"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if appState.isIndividualMode {
                        individualModeContent
                    } else {
                        institutionalModeContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NotificationBellButton(
                        role: appState.userRole,
                        badgeCount: unreadNotificationCount
                    ) {
                        showingNotificationsSheet = true
                    }
                }
            }
            .sheet(isPresented: $showingNotificationsSheet) {
                NotificationsSheet(role: appState.userRole, userId: appState.currentUser?.id)
            }
        }
    }

    // MARK: - Individual Mode Content

    private var individualModeContent: some View {
        VStack(spacing: 12) {
            // FELLOW PROFILE Section
            SectionHeader(title: "FELLOW PROFILE")

            // Profile Row
            SettingsPillRow(
                icon: "person.fill",
                iconColor: .blue,
                title: appState.individualDisplayName,
                showChevron: true
            ) {
                showingProfileEdit = true
            }

            // Security Row
            SettingsPillRow(
                icon: "lock.fill",
                iconColor: Color(red: 0.3, green: 0.5, blue: 0.7),
                title: "Security",
                badge: isPasscodeSet ? .checkmark : nil,
                showChevron: true
            ) {
                showingSecuritySettings = true
            }

            // Cloud Backup Row
            SettingsPillRow(
                icon: "cloud.fill",
                iconColor: .blue,
                title: "Cloud Backup",
                badge: cloudBackupEnabled ? .checkmark : nil,
                showChevron: true
            ) {
                showingCloudBackup = true
            }

            // TRAINING PROGRAM Section
            SectionHeader(title: "TRAINING PROGRAM")

            // Program Specialty Row
            SettingsPillRow(
                icon: appState.individualFellowshipSpecialty?.iconName ?? "graduationcap.fill",
                iconColor: .purple,
                title: "Program Specialty",
                subtitle: appState.individualFellowshipSpecialty?.displayName ?? "Not Selected",
                showChevron: true
            ) {
                showingFellowshipSpecialtyPicker = true
            }

            // Specialty Packs Row
            SettingsPillRow(
                icon: "square.stack.3d.up.fill",
                iconColor: .purple,
                title: "Specialty Packs",
                badge: enabledPacksCount > 0 ? .count(enabledPacksCount) : nil,
                showChevron: true
            ) {
                showingSpecialtyPacks = true
            }

            // Attendings Row
            SettingsPillRow(
                icon: "person.2.fill",
                iconColor: .orange,
                title: "Attendings",
                badge: activeAttendingsCount > 0 ? .count(activeAttendingsCount) : nil,
                showChevron: true
            ) {
                showingAttendingsList = true
            }

            // Hospitals/Facilities Row
            SettingsPillRow(
                icon: "building.2.fill",
                iconColor: Color(red: 0.2, green: 0.4, blue: 0.8),
                title: "Hospitals",
                badge: activeFacilitiesCount > 0 ? .count(activeFacilitiesCount) : nil,
                showChevron: true
            ) {
                showingFacilitiesList = true
            }

            // PROCEDURES Section
            SectionHeader(title: "PROCEDURES")

            // Custom Procedures Row
            SettingsPillRow(
                icon: "list.clipboard.fill",
                iconColor: Color(red: 0.9, green: 0.4, blue: 0.5),
                title: "Custom Procedures",
                badge: activeCustomProceduresCount > 0 ? .count(activeCustomProceduresCount) : nil,
                showChevron: true
            ) {
                showingCustomProcedures = true
            }

            // Custom Access Sites Row
            SettingsPillRow(
                icon: "arrow.triangle.branch",
                iconColor: .gray,
                title: "Custom Access Sites",
                badge: activeCustomAccessSitesCount > 0 ? .count(activeCustomAccessSitesCount) : nil,
                showChevron: true
            ) {
                showingCustomAccessSites = true
            }

            // Custom Complications Row
            SettingsPillRow(
                icon: "exclamationmark.triangle.fill",
                iconColor: .yellow,
                title: "Custom Complications",
                badge: activeCustomComplicationsCount > 0 ? .count(activeCustomComplicationsCount) : nil,
                showChevron: true
            ) {
                showingCustomComplications = true
            }

            // Procedure Details Row
            SettingsPillRow(
                icon: "slider.horizontal.3",
                iconColor: .cyan,
                title: "Procedure Details",
                badge: activeCustomProcedureDetailsCount > 0 ? .count(activeCustomProcedureDetailsCount) : nil,
                showChevron: true
            ) {
                showingCustomProcedureDetails = true
            }

            // IMPORT/EXPORT Section
            SectionHeader(title: "IMPORT/EXPORT")

            // Import Row
            SettingsPillRow(
                icon: "square.and.arrow.down.fill",
                iconColor: .orange,
                title: "Import Procedure Log",
                showChevron: true
            ) {
                showingImportLog = true
            }

            // Export Row
            SettingsPillRow(
                icon: "square.and.arrow.up.fill",
                iconColor: .green,
                title: "Export Data",
                showChevron: true
            ) {
                showingExportOptions = true
            }

            // NOTIFICATIONS Section
            SectionHeader(title: "NOTIFICATIONS")

            SettingsPillToggle(
                icon: "bell.fill",
                iconColor: .red,
                title: "Push Notifications",
                isOn: $pushNotificationsEnabled
            )

            if pushNotificationsEnabled {
                SettingsPillToggle(
                    icon: "checkmark.seal.fill",
                    iconColor: .green,
                    title: "Attestation Alerts",
                    isOn: $attestationAlertsEnabled
                )
                .padding(.leading, 20)

                SettingsPillToggle(
                    icon: "xmark.seal.fill",
                    iconColor: .orange,
                    title: "Rejected Cases",
                    isOn: $rejectedCasesAlertsEnabled
                )
                .padding(.leading, 20)
            }

            // About Row
            SettingsPillRow(
                icon: "info.circle.fill",
                iconColor: .blue,
                title: "About",
                showChevron: true
            ) {
                showingAbout = true
            }

            // Migration Section
            SectionHeader(title: "PROGRAM MIGRATION")

            SettingsPillRow(
                icon: "arrow.triangle.merge",
                iconColor: Color(red: 0.05, green: 0.35, blue: 0.65),
                title: "Migrate to Institutional",
                showChevron: true
            ) {
                showingMigrationWizard = true
            }

            #if DEBUG
            // Dev Mode - Enter Institutional
            SectionHeader(title: "DEVELOPMENT")

            SettingsPillRow(
                icon: "wand.and.stars",
                iconColor: .purple,
                title: "Populate Sample Data",
                badge: hasIndividualDevData ? .checkmark : nil,
                showChevron: false
            ) {
                showingPopulateIndividualDevConfirmation = true
            }
            .disabled(hasIndividualDevData)

            if hasIndividualDevData {
                SettingsPillRow(
                    icon: "trash.fill",
                    iconColor: .red,
                    title: "Reset Sample Data",
                    showChevron: false
                ) {
                    showingResetIndividualDevConfirmation = true
                }
            }

            SettingsPillRow(
                icon: "hammer.fill",
                iconColor: .orange,
                title: "Enter Institutional Mode",
                showChevron: true
            ) {
                showingDevInstitutional = true
            }
            #endif
        }
        .sheet(isPresented: $showingProfileEdit) {
            IndividualProfileEditSheet()
        }
        .sheet(isPresented: $showingSecuritySettings) {
            SecuritySettingsSheet(isPasscodeSet: $isPasscodeSet, isBiometricsEnabled: $isBiometricsEnabled)
        }
        .sheet(isPresented: $showingCloudBackup) {
            CloudBackupSheet(isEnabled: $cloudBackupEnabled)
        }
        .sheet(isPresented: $showingFellowshipSpecialtyPicker) {
            FellowshipSpecialtyPickerSheet()
        }
        .sheet(isPresented: $showingSpecialtyPacks) {
            SpecialtyPacksSheet()
        }
        .sheet(isPresented: $showingAttendingsList) {
            AttendingsListSheet()
        }
        .sheet(isPresented: $showingFacilitiesList) {
            FacilitiesListSheet()
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
        .sheet(isPresented: $showingExportOptions) {
            ExportSheet()
        }
        .sheet(isPresented: $showingImportLog) {
            ImportProcedureLogView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutSheet()
        }
        .fullScreenCover(isPresented: $showingMigrationWizard) {
            IndividualToInstitutionalMigrationView()
        }
        #if DEBUG
        .sheet(isPresented: $showingDevInstitutional) {
            DevInstitutionalSheet()
        }
        .alert("Populate Sample Data?", isPresented: $showingPopulateIndividualDevConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Populate") { populateIndividualDevData() }
        } message: {
            Text("This will create sample attendings (Simpsons), facilities, and 20 cases (10 invasive + 10 noninvasive) spanning the last 3 months.")
        }
        .alert("Reset Sample Data?", isPresented: $showingResetIndividualDevConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetIndividualDevData() }
        } message: {
            Text("This will delete all sample attendings, facilities, and cases created by the dev populate feature.")
        }
        #endif
    }

    #if DEBUG
    private func populateIndividualDevData() {
        // Get or create individual user ID
        let individualUserId = getOrCreateIndividualUserId()

        // Create attendings (Simpsons family - same as institutional)
        let attendingData = [
            ("Dr. Julius", "Hibbert"),
            ("Dr. Nick", "Riviera"),
            ("Dr. Marvin", "Monroe")
        ]

        var createdAttendingIds: [UUID] = []
        for (first, last) in attendingData {
            let fullName = "\(first) \(last)"
            if !attendings.contains(where: { $0.name == fullName }) {
                let attending = Attending(
                    firstName: first,
                    lastName: last,
                    ownerId: individualUserId
                )
                modelContext.insert(attending)
                createdAttendingIds.append(attending.id)
            } else if let existing = attendings.first(where: { $0.name == fullName }) {
                createdAttendingIds.append(existing.id)
            }
        }

        // Create facilities
        let facilityData = ["Springfield General Hospital", "Springfield Medical Center"]
        var createdFacilityIds: [UUID] = []
        for facilityName in facilityData {
            if !facilities.contains(where: { $0.name == facilityName }) {
                let facility = TrainingFacility(name: facilityName, ownerId: individualUserId)
                modelContext.insert(facility)
                createdFacilityIds.append(facility.id)
            } else if let existing = facilities.first(where: { $0.name == facilityName }) {
                createdFacilityIds.append(existing.id)
            }
        }

        // Enable cardiology packs if not enabled
        if !appState.enabledSpecialtyPackIds.contains("interventional-cardiology") {
            appState.toggleSpecialtyPack("interventional-cardiology")
        }
        if !appState.enabledSpecialtyPackIds.contains("cardiac-imaging") {
            appState.toggleSpecialtyPack("cardiac-imaging")
        }

        // Create 10 invasive cases spanning last 3 months
        let calendar = Calendar.current
        let icPack = SpecialtyPackCatalog.pack(for: "interventional-cardiology")
        let invasiveProcedures = icPack?.categories.flatMap { $0.procedures.map { $0.id } } ?? []

        // Access sites for IC procedures
        let icAccessSites: [AccessSite] = [.femoral, .radial, .brachial, .pedal]
        let operatorPositions: [OperatorPosition] = [.primary, .secondary]

        // Sample case notes for realistic dev data
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

        guard !createdAttendingIds.isEmpty, !createdFacilityIds.isEmpty, !invasiveProcedures.isEmpty else { return }

        for i in 0..<10 {
            // Spread cases over last 12 weeks
            let weeksAgo = Int.random(in: 0...12)
            let caseDate = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: Date()) ?? Date()
            let weekBucket = CaseEntry.makeWeekBucket(for: caseDate)

            let newCase = CaseEntry(
                ownerId: individualUserId,
                attendingId: createdAttendingIds.randomElement(),
                weekBucket: weekBucket,
                facilityId: createdFacilityIds.randomElement()
            )

            // Add 1-3 random procedures
            let numProcedures = Int.random(in: 1...3)
            newCase.procedureTagIds = Array(invasiveProcedures.shuffled().prefix(numProcedures))
            newCase.createdAt = caseDate
            newCase.caseTypeRaw = CaseType.invasive.rawValue

            // Add 1-2 random access sites
            let numAccessSites = Int.random(in: 1...2)
            newCase.accessSiteIds = Array(icAccessSites.shuffled().prefix(numAccessSites)).map { $0.rawValue }

            // Add random operator position
            newCase.operatorPositionRaw = operatorPositions.randomElement()?.rawValue

            // Use realistic sample notes
            newCase.notes = sampleNotes[i]

            modelContext.insert(newCase)
        }

        // Create 10 noninvasive cases spanning last 3 months
        let ciPack = SpecialtyPackCatalog.pack(for: "cardiac-imaging")
        let noninvasiveProcedures = ciPack?.categories.flatMap { $0.procedures.map { $0.id } } ?? []

        // Sample noninvasive case notes
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

        if !noninvasiveProcedures.isEmpty {
            for i in 0..<10 {
                // Spread cases over last 12 weeks
                let weeksAgo = Int.random(in: 0...12)
                let caseDate = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: Date()) ?? Date()
                let weekBucket = CaseEntry.makeWeekBucket(for: caseDate)

                let newCase = CaseEntry(
                    ownerId: individualUserId,
                    attendingId: nil,  // Noninvasive cases don't require attending
                    weekBucket: weekBucket,
                    facilityId: createdFacilityIds.randomElement()
                )

                // Add 1-2 random noninvasive procedures
                let numProcedures = Int.random(in: 1...2)
                newCase.procedureTagIds = Array(noninvasiveProcedures.shuffled().prefix(numProcedures))
                newCase.createdAt = caseDate
                newCase.caseTypeRaw = CaseType.noninvasive.rawValue
                newCase.attestationStatusRaw = AttestationStatus.notRequired.rawValue
                newCase.notes = noninvasiveNotes[i]

                modelContext.insert(newCase)
            }
        }

        try? modelContext.save()
    }

    private func resetIndividualDevData() {
        // Get individual user ID
        let individualUserId = getOrCreateIndividualUserId()

        // Delete attendings created by individual mode (Simpson doctors)
        let devAttendingNames = ["Dr. Julius Hibbert", "Dr. Nick Riviera", "Dr. Marvin Monroe"]
        for attending in attendings where devAttendingNames.contains(attending.name) {
            modelContext.delete(attending)
        }

        // Delete facilities created by individual mode
        let devFacilityNames = ["Springfield General Hospital", "Springfield Medical Center"]
        for facility in facilities where devFacilityNames.contains(facility.name) {
            modelContext.delete(facility)
        }

        // Delete cases with dev notes
        let allCases = (try? modelContext.fetch(FetchDescriptor<CaseEntry>())) ?? []
        for caseEntry in allCases where caseEntry.ownerId == individualUserId && (caseEntry.notes?.contains("auto-generated") ?? false) {
            modelContext.delete(caseEntry)
        }

        try? modelContext.save()
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
    #endif

    // MARK: - Institutional Mode Content

    private var institutionalModeContent: some View {
        VStack(spacing: 12) {
            // FELLOW-SPECIFIC SETTINGS (mirroring individual mode)
            if appState.userRole == .fellow {
                // FELLOW PROFILE Section
                SectionHeader(title: "FELLOW PROFILE")

                // Profile Row with role badge
                SettingsPillRowWithRole(
                    icon: "person.fill",
                    iconColor: .blue,
                    title: appState.currentUser?.displayName ?? "User",
                    roleBadge: "Fellow",
                    roleBadgeColor: .blue,
                    showChevron: true
                ) {
                    showingInstitutionalProfileEdit = true
                }

                // Identity Row
                SettingsPillRow(
                    icon: "person.crop.circle.badge.checkmark",
                    iconColor: .blue,
                    title: "Identity",
                    subtitle: selectedFellowName,
                    showChevron: true
                ) {
                    showingFellowIdentityPicker = true
                }

                // Security Row
                SettingsPillRow(
                    icon: "lock.fill",
                    iconColor: Color(red: 0.3, green: 0.5, blue: 0.7),
                    title: "Security",
                    badge: isPasscodeSet ? .checkmark : nil,
                    showChevron: true
                ) {
                    showingSecuritySettings = true
                }

                // Cloud Backup Row
                SettingsPillRow(
                    icon: "cloud.fill",
                    iconColor: .blue,
                    title: "Cloud Backup",
                    badge: cloudBackupEnabled ? .checkmark : nil,
                    showChevron: true
                ) {
                    showingCloudBackup = true
                }

                // TRAINING PROGRAM Section
                SectionHeader(title: "TRAINING PROGRAM")

                // Program Specialty Row (read-only for fellows, set by admin)
                SettingsPillRow(
                    icon: currentProgram?.fellowshipSpecialty?.iconName ?? "graduationcap.fill",
                    iconColor: ProcedusTheme.accent,
                    title: "Program Specialty",
                    subtitle: currentProgram?.fellowshipSpecialty?.displayName ?? "Not Set",
                    showChevron: false
                ) {
                    // Read-only - no action
                }

                // Specialty Packs Row
                SettingsPillRow(
                    icon: "square.stack.3d.up.fill",
                    iconColor: .purple,
                    title: "Specialty Packs",
                    badge: enabledPacksCount > 0 ? .count(enabledPacksCount) : nil,
                    showChevron: true
                ) {
                    showingSpecialtyPacks = true
                }

                // Attendings Row
                SettingsPillRow(
                    icon: "stethoscope",
                    iconColor: .green,
                    title: "Attendings",
                    badge: activeAttendingsCount > 0 ? .count(activeAttendingsCount) : nil,
                    showChevron: true
                ) {
                    showingAttendingsList = true
                }

                // Hospitals Row
                SettingsPillRow(
                    icon: "building.2.fill",
                    iconColor: Color(red: 0.2, green: 0.4, blue: 0.8),
                    title: "Hospitals",
                    badge: activeFacilitiesCount > 0 ? .count(activeFacilitiesCount) : nil,
                    showChevron: true
                ) {
                    showingFacilitiesList = true
                }

                // PROCEDURES Section
                SectionHeader(title: "PROCEDURES")

                // Custom Procedures Row
                SettingsPillRow(
                    icon: "list.clipboard.fill",
                    iconColor: Color(red: 0.9, green: 0.4, blue: 0.5),
                    title: "Custom Procedures",
                    badge: activeCustomProceduresCount > 0 ? .count(activeCustomProceduresCount) : nil,
                    showChevron: true
                ) {
                    showingCustomProcedures = true
                }

                // Custom Access Sites Row
                SettingsPillRow(
                    icon: "arrow.triangle.branch",
                    iconColor: .gray,
                    title: "Custom Access Sites",
                    badge: activeCustomAccessSitesCount > 0 ? .count(activeCustomAccessSitesCount) : nil,
                    showChevron: true
                ) {
                    showingCustomAccessSites = true
                }

                // Custom Complications Row
                SettingsPillRow(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .yellow,
                    title: "Custom Complications",
                    badge: activeCustomComplicationsCount > 0 ? .count(activeCustomComplicationsCount) : nil,
                    showChevron: true
                ) {
                    showingCustomComplications = true
                }

                // Procedure Details Row
                SettingsPillRow(
                    icon: "slider.horizontal.3",
                    iconColor: .cyan,
                    title: "Procedure Details",
                    badge: activeCustomProcedureDetailsCount > 0 ? .count(activeCustomProcedureDetailsCount) : nil,
                    showChevron: true
                ) {
                    showingCustomProcedureDetails = true
                }

                // IMPORT/EXPORT Section
                SectionHeader(title: "IMPORT/EXPORT")

                // Import Row
                SettingsPillRow(
                    icon: "square.and.arrow.down.fill",
                    iconColor: .orange,
                    title: "Import Procedure Log",
                    showChevron: true
                ) {
                    showingImportLog = true
                }

                // Export Row
                SettingsPillRow(
                    icon: "square.and.arrow.up.fill",
                    iconColor: .green,
                    title: "Export Data",
                    showChevron: true
                ) {
                    showingExportOptions = true
                }

                // NOTIFICATIONS Section
                SectionHeader(title: "NOTIFICATIONS")

                SettingsPillToggle(
                    icon: "bell.fill",
                    iconColor: .red,
                    title: "Push Notifications",
                    isOn: $pushNotificationsEnabled
                )

                if pushNotificationsEnabled {
                    SettingsPillToggle(
                        icon: "checkmark.seal.fill",
                        iconColor: .green,
                        title: "Attestation Alerts",
                        isOn: $attestationAlertsEnabled
                    )
                    .padding(.leading, 20)

                    SettingsPillToggle(
                        icon: "xmark.seal.fill",
                        iconColor: .orange,
                        title: "Rejected Cases",
                        isOn: $rejectedCasesAlertsEnabled
                    )
                    .padding(.leading, 20)
                }

                // About Row
                SettingsPillRow(
                    icon: "info.circle.fill",
                    iconColor: .blue,
                    title: "About",
                    showChevron: true
                ) {
                    showingAbout = true
                }
            } else {
                // ADMIN/ATTENDING SETTINGS (original structure)
                SectionHeader(title: "PROFILE")

                // Show role-based profile
                SettingsPillRowWithRole(
                    icon: roleIcon,
                    iconColor: roleColor,
                    title: appState.currentUser?.displayName ?? "User",
                    roleBadge: appState.userRole.displayName,
                    roleBadgeColor: roleColor,
                    showChevron: true
                ) {
                    showingInstitutionalProfileEdit = true
                }

                // Identity Selection for Attendings
                if appState.userRole == .attending {
                    SettingsPillRow(
                        icon: "person.crop.circle.badge.checkmark",
                        iconColor: .green,
                        title: "Identity",
                        subtitle: selectedAttendingName,
                        showChevron: true
                    ) {
                        showingAttendingIdentityPicker = true
                    }
                }

                // Security
                SettingsPillRow(
                    icon: "lock.fill",
                    iconColor: Color(red: 0.3, green: 0.5, blue: 0.7),
                    title: "Security",
                    badge: isPasscodeSet ? .checkmark : nil,
                    showChevron: true
                ) {
                    showingSecuritySettings = true
                }

                // Push Notifications Section (for admin/attending)
                SectionHeader(title: "NOTIFICATIONS")

                // Push Notifications Toggle
                SettingsPillToggle(
                    icon: "bell.fill",
                    iconColor: .red,
                    title: "Push Notifications",
                    isOn: $pushNotificationsEnabled
                )

                // Conditional notification options
                if pushNotificationsEnabled {
                    SettingsPillToggle(
                        icon: "checkmark.seal.fill",
                        iconColor: .green,
                        title: "Attestation Alerts",
                        isOn: $attestationAlertsEnabled
                    )
                    .padding(.leading, 20)

                    SettingsPillToggle(
                        icon: "xmark.seal.fill",
                        iconColor: .orange,
                        title: "Rejected Cases",
                        isOn: $rejectedCasesAlertsEnabled
                    )
                    .padding(.leading, 20)
                }

                // About
                SettingsPillRow(
                    icon: "info.circle.fill",
                    iconColor: .blue,
                    title: "About",
                    showChevron: true
                ) {
                    showingAbout = true
                }
            }

            // Sign Out (for all roles)
            Button {
                appState.signOut()
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding(.top, 8)

            #if DEBUG
            // Dev mode role switching for institutional
            SectionHeader(title: "DEVELOPMENT")

            SettingsPillRow(
                icon: "person.badge.key.fill",
                iconColor: .orange,
                title: "Switch Role",
                subtitle: "Current: \(appState.userRole.displayName)",
                showChevron: true
            ) {
                showingDevInstitutional = true
            }
            #endif
        }
        .sheet(isPresented: $showingInstitutionalProfileEdit) {
            InstitutionalProfileEditSheet()
        }
        .sheet(isPresented: $showingSecuritySettings) {
            SecuritySettingsSheet(isPasscodeSet: $isPasscodeSet, isBiometricsEnabled: $isBiometricsEnabled)
        }
        .sheet(isPresented: $showingCloudBackup) {
            CloudBackupSheet(isEnabled: $cloudBackupEnabled)
        }
        .sheet(isPresented: $showingAbout) {
            AboutSheet()
        }
        .sheet(isPresented: $showingFellowIdentityPicker) {
            FellowIdentityPickerSheet(fellows: activeFellows)
        }
        .sheet(isPresented: $showingAttendingIdentityPicker) {
            AttendingIdentityPickerSheet(attendings: activeAttendingsForSelection)
        }
        .sheet(isPresented: $showingSpecialtyPacks) {
            SpecialtyPacksSheet()
        }
        .sheet(isPresented: $showingAttendingsList) {
            AttendingsListSheet()
        }
        .sheet(isPresented: $showingFacilitiesList) {
            FacilitiesListSheet()
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
        .sheet(isPresented: $showingImportLog) {
            ImportProcedureLogView()
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportSheet()
        }
        #if DEBUG
        .sheet(isPresented: $showingDevInstitutional) {
            DevRoleSwitcherSheet()
        }
        #endif
    }

    private var roleIcon: String {
        switch appState.userRole {
        case .fellow: return "person.fill"
        case .attending: return "stethoscope"
        case .admin: return "person.badge.key.fill"
        }
    }

    private var roleColor: Color {
        switch appState.userRole {
        case .fellow: return .blue
        case .attending: return .green
        case .admin: return .purple
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Image(systemName: "person.fill")
                .font(.caption)
                .foregroundColor(.secondary)
                .opacity(0)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.leading, 4)
        .padding(.top, 8)
    }
}

// MARK: - Settings Pill Row

enum SettingsBadge {
    case checkmark
    case count(Int)
}

struct SettingsPillRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var badge: SettingsBadge? = nil
    var showChevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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

                // Badge
                if let badge = badge {
                    switch badge {
                    case .checkmark:
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                    case .count(let count):
                        Text("\(count)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.tertiarySystemFill))
                            .clipShape(Capsule())
                    }
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
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Pill Row With Role Badge

struct SettingsPillRowWithRole: View {
    let icon: String
    let iconColor: Color
    let title: String
    let roleBadge: String
    let roleBadgeColor: Color
    var showChevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)

                // Title
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color(UIColor.label))

                // Role Badge
                Text(roleBadge)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(roleBadgeColor)
                    .clipShape(Capsule())

                Spacer()

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
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Pill Toggle

struct SettingsPillToggle: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)

            // Title
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(Color(UIColor.label))

            Spacer()

            // Toggle
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Institutional Profile Edit Sheet

struct InstitutionalProfileEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var firstName: String = ""
    @State private var lastName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                } header: {
                    Text("Name")
                }

                Section {
                    HStack {
                        Text("Role")
                        Spacer()
                        Text(appState.userRole.displayName)
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    Text("Your role is assigned by the program administrator.")
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                firstName = appState.currentUser?.firstName ?? ""
                lastName = appState.currentUser?.lastName ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveProfile() {
        guard let user = appState.currentUser else { return }
        user.firstName = firstName
        user.lastName = lastName
        user.updatedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Individual Profile Edit Sheet

struct IndividualProfileEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var selectedPGYLevel: PGYLevel? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                } header: {
                    Text("Name")
                }

                Section {
                    Picker("PGY Level", selection: $selectedPGYLevel) {
                        Text("Not Selected").tag(nil as PGYLevel?)
                        ForEach(PGYLevel.allCases) { level in
                            Text(level.displayName).tag(level as PGYLevel?)
                        }
                    }
                } header: {
                    Text("Training Year")
                } footer: {
                    Text("Your current post-graduate year. Used for analytics and time range filtering.")
                }

                Section {
                    HStack {
                        Text("Display Name")
                        Spacer()
                        Text(displayName)
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    Text("This name will appear in your exported reports.")
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                firstName = appState.individualFirstName
                lastName = appState.individualLastName
                selectedPGYLevel = appState.individualPGYLevel
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.individualFirstName = firstName
                        appState.individualLastName = lastName
                        appState.individualPGYLevel = selectedPGYLevel
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var displayName: String {
        let first = firstName.trimmingCharacters(in: .whitespaces)
        let last = lastName.trimmingCharacters(in: .whitespaces)
        if first.isEmpty && last.isEmpty {
            return "Fellow"
        }
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Security Settings Sheet

struct SecuritySettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPasscodeSet: Bool
    @Binding var isBiometricsEnabled: Bool

    @State private var showingPasscodeSetup = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isPasscodeSet {
                        Button("Change Passcode") {
                            showingPasscodeSetup = true
                        }

                        Button("Remove Passcode", role: .destructive) {
                            isPasscodeSet = false
                            isBiometricsEnabled = false
                            UserDefaults.standard.removeObject(forKey: "storedPasscodeHash")
                        }

                        Toggle("Face ID / Touch ID", isOn: $isBiometricsEnabled)
                    } else {
                        Button("Set Up Passcode") {
                            showingPasscodeSetup = true
                        }
                    }
                } footer: {
                    if !isPasscodeSet {
                        Text("Enable passcode to protect your data with Face ID / Touch ID")
                    }
                }
            }
            .navigationTitle("Security")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPasscodeSetup) {
                PasscodeSetupSheet(isPasscodeSet: $isPasscodeSet)
            }
        }
    }
}

// MARK: - Cloud Backup Sheet

struct CloudBackupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isEnabled: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable iCloud Backup", isOn: $isEnabled)
                } footer: {
                    Text("Your procedure data will be synced to iCloud and available across your devices.")
                }

                if isEnabled {
                    Section {
                        HStack {
                            Text("Last Backup")
                            Spacer()
                            Text("Just now")
                                .foregroundColor(.secondary)
                        }

                        Button("Backup Now") {
                            // Trigger backup
                        }
                    }
                }
            }
            .navigationTitle("Cloud Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Specialty Packs Sheet

struct SpecialtyPacksSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var selectedPackForPreview: SpecialtyPack?

    var body: some View {
        NavigationStack {
            List {
                ForEach(SpecialtyPackCatalog.allPacks, id: \.id) { pack in
                    SpecialtyPackRowWithPreview(
                        pack: pack,
                        isEnabled: appState.isPackEnabled(pack.id),
                        onToggle: { appState.toggleSpecialtyPack(pack.id) },
                        onPreview: { selectedPackForPreview = pack }
                    )
                }
            }
            .navigationTitle("Specialty Packs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedPackForPreview) { pack in
                IndividualSpecialtyPackPreviewSheet(pack: pack)
            }
        }
    }
}

// MARK: - Specialty Pack Row with Preview Button

struct SpecialtyPackRowWithPreview: View {
    let pack: SpecialtyPack
    let isEnabled: Bool
    let onToggle: () -> Void
    let onPreview: () -> Void

    private var procedureCount: Int {
        pack.categories.reduce(0) { $0 + $1.procedures.count }
    }

    var body: some View {
        HStack {
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pack.name)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(Color(UIColor.label))

                        Text("\(pack.categories.count) categories, \(procedureCount) procedures")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isEnabled ? .green : Color(UIColor.tertiaryLabel))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Preview button
            Button(action: onPreview) {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
    }
}

// MARK: - Individual Specialty Pack Preview Sheet

struct IndividualSpecialtyPackPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pack: SpecialtyPack

    var body: some View {
        NavigationStack {
            List {
                // Pack info section
                Section {
                    LabeledContent("Short Name", value: pack.shortName)
                    LabeledContent("Type", value: pack.type.rawValue)
                    LabeledContent("Categories", value: "\(pack.categories.count)")
                    let totalProcs = pack.categories.reduce(0) { $0 + $1.procedures.count }
                    LabeledContent("Total Procedures", value: "\(totalProcs)")
                } header: {
                    Text("Pack Information")
                }

                // Categories and procedures
                ForEach(pack.categories, id: \.id) { category in
                    Section {
                        ForEach(category.procedures, id: \.id) { procedure in
                            HStack {
                                if let letter = category.category.bubbleLetter {
                                    Text(letter)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(category.category.bubbleColor)
                                        .clipShape(Circle())
                                }
                                Text(procedure.title)
                                    .font(.subheadline)
                            }
                        }
                    } header: {
                        Text(category.category.rawValue)
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

struct SpecialtyPackRow: View {
    let pack: SpecialtyPack
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color(UIColor.label))

                    Text("\(pack.categories.count) categories, \(procedureCount) procedures")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isEnabled ? .green : Color(UIColor.tertiaryLabel))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var procedureCount: Int {
        pack.categories.reduce(0) { $0 + $1.procedures.count }
    }
}

// MARK: - Attendings List Sheet

struct AttendingsListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Attending> { !$0.isArchived }, sort: \Attending.name) private var attendings: [Attending]

    @State private var showingAddSheet = false
    @State private var attendingToEdit: Attending?

    var body: some View {
        NavigationStack {
            List {
                ForEach(attendings) { attending in
                    Button {
                        attendingToEdit = attending
                    } label: {
                        HStack {
                            Text(attending.name)
                                .foregroundColor(Color(UIColor.label))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                    }
                }
                .onDelete(perform: deleteAttending)
            }
            .overlay {
                if attendings.isEmpty {
                    ContentUnavailableView(
                        "No Attendings",
                        systemImage: "person.2",
                        description: Text("Add attendings to track who supervised your procedures.")
                    )
                }
            }
            .navigationTitle("Attendings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEditAttendingSheet(attending: nil)
            }
            .sheet(item: $attendingToEdit) { attending in
                AddEditAttendingSheet(attending: attending)
            }
        }
    }

    private func deleteAttending(at offsets: IndexSet) {
        for index in offsets {
            attendings[index].isArchived = true
        }
    }
}

// MARK: - Facilities List Sheet

struct FacilitiesListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TrainingFacility> { !$0.isArchived }, sort: \TrainingFacility.name) private var facilities: [TrainingFacility]

    @State private var showingAddSheet = false
    @State private var facilityToEdit: TrainingFacility?

    var body: some View {
        NavigationStack {
            List {
                ForEach(facilities) { facility in
                    Button {
                        facilityToEdit = facility
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(facility.name)
                                    .foregroundColor(Color(UIColor.label))
                                if let shortName = facility.shortName, !shortName.isEmpty {
                                    Text(shortName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                    }
                }
                .onDelete(perform: deleteFacility)
            }
            .overlay {
                if facilities.isEmpty {
                    ContentUnavailableView(
                        "No Hospitals",
                        systemImage: "building.2",
                        description: Text("Add hospitals where you perform procedures.")
                    )
                }
            }
            .navigationTitle("Hospitals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEditFacilitySheet(facility: nil)
            }
            .sheet(item: $facilityToEdit) { facility in
                AddEditFacilitySheet(facility: facility)
            }
        }
    }

    private func deleteFacility(at offsets: IndexSet) {
        for index in offsets {
            facilities[index].isArchived = true
        }
    }
}

// MARK: - Custom Procedures List Sheet

struct CustomProceduresListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CustomProcedure> { !$0.isArchived }) private var procedures: [CustomProcedure]

    @State private var showingAddSheet = false
    @State private var procedureToEdit: CustomProcedure?

    var body: some View {
        NavigationStack {
            List {
                ForEach(procedures) { procedure in
                    Button {
                        procedureToEdit = procedure
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(procedure.title)
                                    .foregroundColor(Color(UIColor.label))
                                Text(procedure.category.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                    }
                }
                .onDelete(perform: deleteProcedure)
            }
            .overlay {
                if procedures.isEmpty {
                    ContentUnavailableView(
                        "No Custom Procedures",
                        systemImage: "list.clipboard",
                        description: Text("Add procedures specific to your training.")
                    )
                }
            }
            .navigationTitle("Custom Procedures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddCustomProcedureSheet()
            }
            .sheet(item: $procedureToEdit) { procedure in
                AddCustomProcedureSheet(existingProcedure: procedure)
            }
        }
    }

    private func deleteProcedure(at offsets: IndexSet) {
        for index in offsets {
            procedures[index].isArchived = true
        }
    }
}

// MARK: - Fellow Custom Procedures List Sheet (Institutional Mode)

struct FellowCustomProceduresListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<CustomProcedure> { !$0.isArchived }) private var allProcedures: [CustomProcedure]

    @State private var showingAddSheet = false
    @State private var procedureToEdit: CustomProcedure?

    // Get current fellow ID from settings
    @AppStorage("selectedFellowId") private var selectedFellowIdString = ""

    private var currentFellowId: UUID? {
        UUID(uuidString: selectedFellowIdString)
    }

    // Filter to only show fellow's own procedures
    private var myProcedures: [CustomProcedure] {
        guard let fellowId = currentFellowId else { return [] }
        return allProcedures.filter { $0.creatorId == fellowId }
    }

    var body: some View {
        NavigationStack {
            List {
                // Warning if no identity selected
                if currentFellowId == nil {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Identity Not Selected")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Select your identity in Settings to add custom procedures.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                ForEach(myProcedures) { procedure in
                    Button {
                        procedureToEdit = procedure
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(procedure.title)
                                    .foregroundColor(Color(UIColor.label))
                                Text(procedure.category.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                    }
                }
                .onDelete(perform: deleteProcedure)
            }
            .overlay {
                if myProcedures.isEmpty && currentFellowId != nil {
                    ContentUnavailableView(
                        "No Custom Procedures",
                        systemImage: "list.clipboard",
                        description: Text("Add your own custom procedures here. They'll appear alongside the program's standard procedures when logging cases.")
                    )
                }
            }
            .navigationTitle("My Custom Procedures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(currentFellowId == nil)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddFellowCustomProcedureSheet()
            }
            .sheet(item: $procedureToEdit) { procedure in
                AddFellowCustomProcedureSheet(existingProcedure: procedure)
            }
        }
    }

    private func deleteProcedure(at offsets: IndexSet) {
        let proceduresToDelete = offsets.map { myProcedures[$0] }
        for procedure in proceduresToDelete {
            procedure.isArchived = true
        }
        try? modelContext.save()
    }
}

// MARK: - Add Fellow Custom Procedure Sheet

struct AddFellowCustomProcedureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var programs: [Program]

    var existingProcedure: CustomProcedure?

    @State private var title: String = ""
    @State private var selectedCategoryId: String = ""

    // Get current fellow ID from settings
    @AppStorage("selectedFellowId") private var selectedFellowIdString = ""

    private var currentFellowId: UUID? {
        UUID(uuidString: selectedFellowIdString)
    }

    // Get enabled specialty packs from program
    private var currentProgram: Program? {
        programs.first
    }

    private var enabledPacks: [SpecialtyPack] {
        guard let program = currentProgram else { return [] }
        return program.specialtyPackIds.compactMap { SpecialtyPackCatalog.pack(for: $0) }
    }

    // Combined categories from enabled packs (deduplicated)
    private var availableCategories: [ProcedureCategory] {
        var seen = Set<String>()
        var result: [ProcedureCategory] = []
        for pack in enabledPacks {
            for packCategory in pack.categories {
                if !seen.contains(packCategory.category.rawValue) {
                    seen.insert(packCategory.category.rawValue)
                    result.append(packCategory.category)
                }
            }
        }
        return result.sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Procedure Name", text: $title)
                }

                Section {
                    if availableCategories.isEmpty {
                        Text("No specialty packs configured for this program.")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Picker("Category", selection: $selectedCategoryId) {
                            ForEach(availableCategories) { category in
                                Text(category.rawValue).tag(category.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Category")
                }
            }
            .navigationTitle(existingProcedure == nil ? "Add Custom Procedure" : "Edit Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let procedure = existingProcedure {
                    title = procedure.title
                    selectedCategoryId = procedure.categoryRaw
                } else if let firstCategory = availableCategories.first {
                    selectedCategoryId = firstCategory.rawValue
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProcedure()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty || selectedCategoryId.isEmpty || currentFellowId == nil)
                }
            }
        }
    }

    private func saveProcedure() {
        guard let fellowId = currentFellowId else { return }
        let category = ProcedureCategory(rawValue: selectedCategoryId) ?? .other

        if let existing = existingProcedure {
            existing.title = title
            existing.categoryRaw = selectedCategoryId
        } else {
            let newProcedure = CustomProcedure(
                title: title,
                category: category,
                programId: currentProgram?.id,
                creatorId: fellowId  // Set creatorId to current fellow
            )
            modelContext.insert(newProcedure)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Fellow Procedure Groups List Sheet

struct FellowProcedureGroupsListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<FellowProcedureGroup> { !$0.isArchived }) private var allGroups: [FellowProcedureGroup]
    @Query private var programs: [Program]

    @State private var showingAddSheet = false
    @State private var groupToEdit: FellowProcedureGroup?

    @AppStorage("selectedFellowId") private var selectedFellowIdString = ""

    private var currentFellowId: UUID? {
        UUID(uuidString: selectedFellowIdString)
    }

    private var myGroups: [FellowProcedureGroup] {
        guard let fellowId = currentFellowId else { return [] }
        return allGroups.filter { $0.creatorId == fellowId }
            .sorted { $0.name < $1.name }
    }

    private var currentProgram: Program? {
        programs.first
    }

    var body: some View {
        NavigationStack {
            List {
                if currentFellowId == nil {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Identity Not Selected")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Select your identity in Settings to create procedure groups.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                ForEach(myGroups) { group in
                    Button {
                        groupToEdit = group
                    } label: {
                        HStack(spacing: 12) {
                            Text(group.letter)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(group.color)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                    .foregroundColor(Color(UIColor.label))
                                Text("\(group.procedureTagIds.count) procedures")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                    }
                }
                .onDelete(perform: deleteGroup)
            }
            .overlay {
                if myGroups.isEmpty && currentFellowId != nil {
                    ContentUnavailableView(
                        "No Procedure Groups",
                        systemImage: "folder",
                        description: Text("Create groups to organize existing procedures into custom categories for easier case logging.")
                    )
                }
            }
            .navigationTitle("Procedure Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(currentFellowId == nil)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEditFellowProcedureGroupSheet(program: currentProgram)
            }
            .sheet(item: $groupToEdit) { group in
                AddEditFellowProcedureGroupSheet(existingGroup: group, program: currentProgram)
            }
        }
    }

    private func deleteGroup(at offsets: IndexSet) {
        let groupsToDelete = offsets.map { myGroups[$0] }
        for group in groupsToDelete {
            group.isArchived = true
        }
        try? modelContext.save()
    }
}

// MARK: - Add/Edit Fellow Procedure Group Sheet

struct AddEditFellowProcedureGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var existingGroup: FellowProcedureGroup?
    var program: Program?

    @State private var name: String = ""
    @State private var selectedLetter: String = "A"
    @State private var selectedColorHex: String = "#4ECDC4"
    @State private var selectedProcedureIds: Set<String> = []

    @AppStorage("selectedFellowId") private var selectedFellowIdString = ""

    private var currentFellowId: UUID? {
        UUID(uuidString: selectedFellowIdString)
    }

    private var enabledPacks: [SpecialtyPack] {
        guard let program = program else { return [] }
        return program.specialtyPackIds.compactMap { SpecialtyPackCatalog.pack(for: $0) }
    }

    private var allProcedures: [(id: String, title: String, category: ProcedureCategory)] {
        var result: [(id: String, title: String, category: ProcedureCategory)] = []
        for pack in enabledPacks {
            for packCategory in pack.categories {
                for procedure in packCategory.procedures {
                    result.append((id: procedure.id, title: procedure.title, category: packCategory.category))
                }
            }
        }
        return result.sorted { $0.title < $1.title }
    }

    private var proceduresByCategory: [ProcedureCategory: [(id: String, title: String)]] {
        var grouped: [ProcedureCategory: [(id: String, title: String)]] = [:]
        for proc in allProcedures {
            grouped[proc.category, default: []].append((id: proc.id, title: proc.title))
        }
        return grouped
    }

    private var sortedCategories: [ProcedureCategory] {
        proceduresByCategory.keys.sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Info") {
                    TextField("Group Name", text: $name)

                    Picker("Letter", selection: $selectedLetter) {
                        ForEach(CustomCategory.availableLetters, id: \.self) { letter in
                            Text(letter).tag(letter)
                        }
                    }
                    .pickerStyle(.menu)

                    // Color picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.subheadline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                            ForEach(CustomCategory.availableColors, id: \.self) { hex in
                                Button {
                                    selectedColorHex = hex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex) ?? .gray)
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            if selectedColorHex == hex {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.bold())
                                                    .foregroundColor(.white)
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // Preview
                    HStack {
                        Text("Preview")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(selectedLetter)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color(hex: selectedColorHex) ?? .gray)
                            .clipShape(Circle())
                        Text(name.isEmpty ? "Group Name" : name)
                            .foregroundColor(name.isEmpty ? .secondary : Color(UIColor.label))
                    }
                }

                Section {
                    Text("Select procedures to include in this group. These will appear as a separate category when logging cases.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    HStack {
                        Text("Procedures")
                        Spacer()
                        Text("\(selectedProcedureIds.count) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                ForEach(sortedCategories, id: \.self) { category in
                    Section(category.rawValue) {
                        if let procedures = proceduresByCategory[category] {
                            ForEach(procedures, id: \.id) { proc in
                                Button {
                                    toggleProcedure(proc.id)
                                } label: {
                                    HStack {
                                        if let letter = category.bubbleLetter {
                                            Text(letter)
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .frame(width: 20, height: 20)
                                                .background(category.bubbleColor)
                                                .clipShape(Circle())
                                        }

                                        Text(proc.title)
                                            .foregroundColor(Color(UIColor.label))

                                        Spacer()

                                        Image(systemName: selectedProcedureIds.contains(proc.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedProcedureIds.contains(proc.id) ? .green : Color(UIColor.tertiaryLabel))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(existingGroup == nil ? "New Procedure Group" : "Edit Procedure Group")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let group = existingGroup {
                    name = group.name
                    selectedLetter = group.letter
                    selectedColorHex = group.colorHex
                    selectedProcedureIds = Set(group.procedureTagIds)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGroup()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty || selectedProcedureIds.isEmpty || currentFellowId == nil)
                }
            }
        }
    }

    private func toggleProcedure(_ id: String) {
        if selectedProcedureIds.contains(id) {
            selectedProcedureIds.remove(id)
        } else {
            selectedProcedureIds.insert(id)
        }
    }

    private func saveGroup() {
        guard let fellowId = currentFellowId else { return }

        if let existing = existingGroup {
            existing.name = name
            existing.letter = selectedLetter
            existing.colorHex = selectedColorHex
            existing.procedureTagIds = Array(selectedProcedureIds)
        } else {
            let newGroup = FellowProcedureGroup(
                name: name,
                letter: selectedLetter,
                colorHex: selectedColorHex,
                procedureTagIds: Array(selectedProcedureIds),
                creatorId: fellowId,
                programId: program?.id
            )
            modelContext.insert(newGroup)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Custom Access Sites List Sheet

struct CustomAccessSitesListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CustomAccessSite> { !$0.isArchived }) private var sites: [CustomAccessSite]

    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(sites) { site in
                    Text(site.title)
                }
                .onDelete(perform: deleteSite)
            }
            .overlay {
                if sites.isEmpty {
                    ContentUnavailableView(
                        "No Custom Access Sites",
                        systemImage: "arrow.triangle.branch",
                        description: Text("Add access sites specific to your procedures.")
                    )
                }
            }
            .navigationTitle("Custom Access Sites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddCustomAccessSiteSheet()
            }
        }
    }

    private func deleteSite(at offsets: IndexSet) {
        for index in offsets {
            sites[index].isArchived = true
        }
    }
}

// MARK: - Custom Complications List Sheet

struct CustomComplicationsListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CustomComplication> { !$0.isArchived }) private var complications: [CustomComplication]

    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(complications) { complication in
                    Text(complication.title)
                }
                .onDelete(perform: deleteComplication)
            }
            .overlay {
                if complications.isEmpty {
                    ContentUnavailableView(
                        "No Custom Complications",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Add complications specific to your specialty.")
                    )
                }
            }
            .navigationTitle("Custom Complications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddCustomComplicationSheet()
            }
        }
    }

    private func deleteComplication(at offsets: IndexSet) {
        for index in offsets {
            complications[index].isArchived = true
        }
    }
}

// MARK: - Custom Procedure Detail Row View

private struct CustomProcedureDetailRowView: View {
    let detail: CustomProcedureDetail
    let onTap: () -> Void

    private var optionsPreview: String {
        let preview = detail.options.prefix(3).joined(separator: ", ")
        return detail.options.count > 3 ? preview + "..." : preview
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(detail.options.count) options • \(detail.procedureTagIds.count) procedures")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !detail.options.isEmpty {
                    Text(optionsPreview)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Custom Procedure Details List Sheet

struct CustomProcedureDetailsListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<CustomProcedureDetail> { !$0.isArchived }) private var allDetails: [CustomProcedureDetail]

    @State private var showingAddSheet = false
    @State private var detailToEdit: CustomProcedureDetail?

    /// Get individual user ID
    private var individualUserId: UUID? {
        if let uuidString = UserDefaults.standard.string(forKey: "individualUserUUID"),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }
        return nil
    }

    /// Filter details to only show user's own in individual mode
    private var myDetails: [CustomProcedureDetail] {
        guard let userId = individualUserId else { return [] }
        return allDetails.filter { $0.ownerId == userId }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(myDetails) { detail in
                    CustomProcedureDetailRowView(detail: detail) {
                        detailToEdit = detail
                    }
                }
                .onDelete(perform: deleteDetail)
            }
            .overlay {
                if myDetails.isEmpty {
                    ScrollView {
                        VStack(spacing: 20) {
                            Spacer().frame(height: 40)

                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)

                            Text("No Procedure Details")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Add custom details like devices or techniques for specific procedures. These will appear when logging those procedures.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            // Example image
                            VStack(spacing: 8) {
                                Text("Example:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Image("ProcedureDetailsExample")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 300)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                            .padding(.top, 8)

                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Procedure Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEditCustomProcedureDetailSheet(detail: nil)
            }
            .sheet(item: $detailToEdit) { detail in
                AddEditCustomProcedureDetailSheet(detail: detail)
            }
        }
    }

    private func deleteDetail(at offsets: IndexSet) {
        for index in offsets {
            myDetails[index].isArchived = true
        }
    }
}

// MARK: - Add/Edit Custom Procedure Detail Sheet

struct AddEditCustomProcedureDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    let detail: CustomProcedureDetail?

    @State private var name: String = ""
    @State private var optionsText: String = ""  // Comma-separated options
    @State private var selectedProcedureIds: Set<String> = []
    @State private var showingProcedurePicker = false

    private var isEditing: Bool { detail != nil }

    /// Get individual user ID
    private var individualUserId: UUID? {
        if let uuidString = UserDefaults.standard.string(forKey: "individualUserUUID"),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }
        return nil
    }

    /// Parse options from comma-separated text
    private var parsedOptions: [String] {
        optionsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Get procedure names for display
    private func procedureName(for tagId: String) -> String {
        SpecialtyPackCatalog.findProcedure(by: tagId)?.title ?? tagId
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Detail Name", text: $name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name")
                } footer: {
                    Text("e.g., \"Device Used\", \"Technique\", \"Approach\"")
                }

                Section {
                    TextField("Options (comma-separated)", text: $optionsText, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Options")
                } footer: {
                    Text("Enter each option separated by commas.\ne.g., \"Penumbra, EKOS, AngioVac, Inari\"")
                }

                Section {
                    Button {
                        showingProcedurePicker = true
                    } label: {
                        HStack {
                            Text("Select Procedures")
                            Spacer()
                            Text("\(selectedProcedureIds.count) selected")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !selectedProcedureIds.isEmpty {
                        ForEach(Array(selectedProcedureIds).sorted(), id: \.self) { tagId in
                            HStack {
                                Text(procedureName(for: tagId))
                                    .font(.subheadline)
                                Spacer()
                                Button {
                                    selectedProcedureIds.remove(tagId)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Applies To")
                } footer: {
                    Text("This detail will appear when logging the selected procedures.")
                }

                if !parsedOptions.isEmpty {
                    Section {
                        ForEach(parsedOptions, id: \.self) { option in
                            Label(option, systemImage: "checkmark.circle")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Preview (\(parsedOptions.count) options)")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Detail" : "New Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDetail()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                              parsedOptions.isEmpty ||
                              selectedProcedureIds.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let detail = detail {
                    name = detail.name
                    optionsText = detail.options.joined(separator: ", ")
                    selectedProcedureIds = Set(detail.procedureTagIds)
                }
            }
            .sheet(isPresented: $showingProcedurePicker) {
                ProcedurePickerForDetailSheet(selectedProcedureIds: $selectedProcedureIds)
            }
        }
    }

    private func saveDetail() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existingDetail = detail {
            // Update existing
            existingDetail.name = trimmedName
            existingDetail.options = parsedOptions
            existingDetail.procedureTagIds = Array(selectedProcedureIds)
        } else {
            // Create new
            let newDetail = CustomProcedureDetail(
                name: trimmedName,
                procedureTagIds: Array(selectedProcedureIds),
                options: parsedOptions,
                ownerId: individualUserId
            )
            modelContext.insert(newDetail)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Procedure Picker for Detail Sheet

struct ProcedurePickerForDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Binding var selectedProcedureIds: Set<String>

    @State private var searchText = ""
    @State private var expandedPackIds: Set<String> = []

    /// Get enabled packs
    private var enabledPacks: [SpecialtyPack] {
        SpecialtyPackCatalog.allPacks.filter { appState.enabledSpecialtyPackIds.contains($0.id) }
    }

    /// Filter procedures by search
    private func filteredProcedures(in pack: SpecialtyPack) -> [(category: PackCategory, procedures: [ProcedureTag])] {
        if searchText.isEmpty {
            return pack.categories.map { ($0, $0.procedures) }
        }
        let lowercased = searchText.lowercased()
        return pack.categories.compactMap { category in
            let filtered = category.procedures.filter {
                $0.title.lowercased().contains(lowercased)
            }
            return filtered.isEmpty ? nil : (category, filtered)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(enabledPacks, id: \.id) { pack in
                    let filteredCategories = filteredProcedures(in: pack)
                    if !filteredCategories.isEmpty {
                        Section {
                            ForEach(filteredCategories, id: \.category.id) { item in
                                DisclosureGroup(
                                    isExpanded: Binding(
                                        get: { expandedPackIds.contains("\(pack.id)-\(item.category.id)") },
                                        set: { isExpanded in
                                            if isExpanded {
                                                expandedPackIds.insert("\(pack.id)-\(item.category.id)")
                                            } else {
                                                expandedPackIds.remove("\(pack.id)-\(item.category.id)")
                                            }
                                        }
                                    )
                                ) {
                                    ForEach(item.procedures, id: \.id) { procedure in
                                        Button {
                                            if selectedProcedureIds.contains(procedure.id) {
                                                selectedProcedureIds.remove(procedure.id)
                                            } else {
                                                selectedProcedureIds.insert(procedure.id)
                                            }
                                        } label: {
                                            HStack {
                                                Text(procedure.title)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                if selectedProcedureIds.contains(procedure.id) {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        CategoryBubble(category: item.category.category, size: 20)
                                        Text(item.category.category.rawValue)
                                            .font(.subheadline)
                                    }
                                }
                            }
                        } header: {
                            Text(pack.name)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search procedures")
            .navigationTitle("Select Procedures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Text("\(selectedProcedureIds.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - About Sheet

struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Link(destination: URL(string: "https://proceduspro.com/support")!) {
                        HStack {
                            Text("Help & Support")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                    }
                    .foregroundColor(Color(UIColor.label))

                    Link(destination: URL(string: "https://proceduspro.com/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                    }
                    .foregroundColor(Color(UIColor.label))

                    Link(destination: URL(string: "https://proceduspro.com/terms")!) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                    }
                    .foregroundColor(Color(UIColor.label))
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Dev Institutional Sheet (for entering institutional mode from individual)

#if DEBUG
struct DevInstitutionalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var fellows: [User]
    @Query private var attendings: [Attending]

    private var availableFellows: [User] {
        fellows.filter { $0.role == .fellow && !$0.isArchived }
    }

    private var availableAttendings: [Attending] {
        attendings.filter { !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Select Role") {
                    Button {
                        appState.devSignIn(role: .fellow)
                        appState.hasCompletedOnboarding = true
                        // Auto-select first fellow if none selected
                        if appState.selectedFellowId == nil, let firstFellow = availableFellows.first {
                            appState.selectedFellowId = firstFellow.id
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.blue)
                            Text("Fellow")
                            Spacer()
                        }
                    }

                    Button {
                        appState.devSignIn(role: .attending)
                        appState.hasCompletedOnboarding = true
                        // Auto-select first attending if none selected
                        if appState.selectedAttendingId == nil, let firstAttending = availableAttendings.first {
                            appState.selectedAttendingId = firstAttending.id
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "stethoscope")
                                .foregroundColor(.green)
                            Text("Attending")
                            Spacer()
                        }
                    }

                    Button {
                        appState.devSignIn(role: .admin)
                        appState.hasCompletedOnboarding = true
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                                .foregroundColor(.purple)
                            Text("Admin")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Enter Institutional")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Dev Role Switcher Sheet (for institutional mode)

struct DevRoleSwitcherSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Query private var fellows: [User]
    @Query private var attendings: [Attending]

    private var availableFellows: [User] {
        fellows.filter { $0.role == .fellow && !$0.isArchived }
    }

    private var availableAttendings: [Attending] {
        attendings.filter { !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Switch to Role") {
                    Button {
                        appState.devSignIn(role: .fellow)
                        // Auto-select first fellow if none selected
                        if appState.selectedFellowId == nil, let firstFellow = availableFellows.first {
                            appState.selectedFellowId = firstFellow.id
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.blue)
                            Text("Fellow")
                            Spacer()
                            if appState.userRole == .fellow {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    Button {
                        appState.devSignIn(role: .attending)
                        // Auto-select first attending if none selected
                        if appState.selectedAttendingId == nil, let firstAttending = availableAttendings.first {
                            appState.selectedAttendingId = firstAttending.id
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "stethoscope")
                                .foregroundColor(.green)
                            Text("Attending")
                            Spacer()
                            if appState.userRole == .attending {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    Button {
                        appState.devSignIn(role: .admin)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                                .foregroundColor(.purple)
                            Text("Admin")
                            Spacer()
                            if appState.userRole == .admin {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                Section {
                    Button("Return to Individual Mode") {
                        appState.devSignOut()
                        appState.setupIndividualMode()
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Switch Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
#endif

// MARK: - Add/Edit Attending Sheet

struct AddEditAttendingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let attending: Attending?
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phoneNumber: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Phone (optional)", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle(attending == nil ? "Add Attending" : "Edit Attending")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let attending = attending {
                    firstName = attending.firstName
                    lastName = attending.lastName
                    phoneNumber = attending.phoneNumber ?? ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAttending()
                    }
                    .fontWeight(.semibold)
                    .disabled(firstName.isEmpty)
                }
            }
        }
    }

    private func saveAttending() {
        if let existing = attending {
            existing.firstName = firstName
            existing.lastName = lastName
            existing.name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            existing.phoneNumber = phoneNumber.isEmpty ? nil : phoneNumber
        } else {
            let newAttending = Attending(firstName: firstName, lastName: lastName)
            newAttending.phoneNumber = phoneNumber.isEmpty ? nil : phoneNumber
            modelContext.insert(newAttending)
        }
        dismiss()
    }
}

// MARK: - Add/Edit Facility Sheet

struct AddEditFacilitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let facility: TrainingFacility?
    @State private var name: String = ""
    @State private var shortName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Facility Name", text: $name)
                    TextField("Short Name (optional)", text: $shortName)
                } footer: {
                    Text("Short name is displayed in compact views (e.g., 'TMC' for Texas Medical Center)")
                }
            }
            .navigationTitle(facility == nil ? "Add Hospital" : "Edit Hospital")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let fac = facility {
                    name = fac.name
                    shortName = fac.shortName ?? ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTrainingFacility()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveTrainingFacility() {
        if let existing = facility {
            existing.name = name
            existing.shortName = shortName.isEmpty ? nil : shortName
        } else {
            let newFacility = TrainingFacility(name: name, shortName: shortName.isEmpty ? nil : shortName)
            modelContext.insert(newFacility)
        }
        dismiss()
    }
}

// MARK: - Add Custom Procedure Sheet

struct AddCustomProcedureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    var existingProcedure: CustomProcedure?

    @State private var title: String = ""
    @State private var selectedCategoryId: String = ""

    // Get enabled specialty packs
    private var enabledPacks: [SpecialtyPack] {
        appState.getEnabledPacks()
    }

    // Combined categories from enabled packs (deduplicated)
    private var availableCategories: [ProcedureCategory] {
        var seen = Set<String>()
        var result: [ProcedureCategory] = []
        for pack in enabledPacks {
            for packCategory in pack.categories {
                if !seen.contains(packCategory.category.rawValue) {
                    seen.insert(packCategory.category.rawValue)
                    result.append(packCategory.category)
                }
            }
        }
        return result.sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Procedure Name", text: $title)
                }

                Section {
                    if availableCategories.isEmpty {
                        Text("No specialty packs enabled. Go to Settings to add one.")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Picker("Category", selection: $selectedCategoryId) {
                            ForEach(availableCategories) { category in
                                Text(category.rawValue).tag(category.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Category")
                }
            }
            .navigationTitle(existingProcedure == nil ? "Add Custom Procedure" : "Edit Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let procedure = existingProcedure {
                    title = procedure.title
                    selectedCategoryId = procedure.categoryRaw
                } else if let firstCategory = availableCategories.first {
                    selectedCategoryId = firstCategory.rawValue
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProcedure()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty || selectedCategoryId.isEmpty)
                }
            }
        }
    }

    private func saveProcedure() {
        let category = ProcedureCategory(rawValue: selectedCategoryId) ?? .other

        if let existing = existingProcedure {
            existing.title = title
            existing.categoryRaw = selectedCategoryId
        } else {
            let newProcedure = CustomProcedure(
                title: title,
                category: category,
                programId: nil,
                creatorId: nil
            )
            modelContext.insert(newProcedure)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Add Custom Access Site Sheet

struct AddCustomAccessSiteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Access Site Name", text: $name)
                } footer: {
                    Text("Add access sites specific to your procedures that aren't in the default list")
                }
            }
            .navigationTitle("Add Custom Access Site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newSite = CustomAccessSite(title: name, programId: nil)
                        modelContext.insert(newSite)
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Custom Complication Sheet

struct AddCustomComplicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Complication Name", text: $name)
                } footer: {
                    Text("Add complications specific to your specialty that aren't in the default list")
                }
            }
            .navigationTitle("Add Custom Complication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newComplication = CustomComplication(title: name, programId: nil)
                        modelContext.insert(newComplication)
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Export Sheet

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var cases: [CaseEntry]
    @Query private var facilities: [TrainingFacility]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        exportCSV()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Export as CSV")
                        }
                    }

                    Button {
                        exportExcel()
                    } label: {
                        HStack {
                            Image(systemName: "tablecells")
                            Text("Export as Excel")
                        }
                    }

                    Button {
                        exportPDF()
                    } label: {
                        HStack {
                            Image(systemName: "doc.richtext")
                            Text("Export as PDF")
                        }
                    }
                } header: {
                    Text("Procedure Counts")
                }

                Section {
                    Button {
                        exportProcedureLogCSV()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Export as CSV")
                        }
                    }

                    Button {
                        exportProcedureLogExcel()
                    } label: {
                        HStack {
                            Image(systemName: "tablecells")
                            Text("Export as Excel")
                        }
                    }

                    Button {
                        exportProcedureLogPDF()
                    } label: {
                        HStack {
                            Image(systemName: "doc.richtext")
                            Text("Export as PDF")
                        }
                    }
                } header: {
                    Text("Procedure Log")
                } footer: {
                    Text("Exports include: Date, Procedures, Access Sites, Attending, Facility, Complications, Outcome")
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func facilityName(for id: UUID?) -> String {
        guard let id = id else { return "" }
        return facilities.first { $0.id == id }?.name ?? ""
    }

    private func exportCSV() {
        // Export implementation
    }

    private func exportExcel() {
        // Export implementation
    }

    private func exportPDF() {
        // Export implementation
    }

    private func exportProcedureLogCSV() {
        // Export implementation
    }

    private func exportProcedureLogExcel() {
        // Export implementation - NEW
    }

    private func exportProcedureLogPDF() {
        // Export implementation
    }
}

// MARK: - Passcode Setup Sheet

struct PasscodeSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPasscodeSet: Bool

    @State private var passcode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var step: Int = 1
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.blue)

                Text(step == 1 ? "Enter New Passcode" : "Confirm Passcode")
                    .font(.headline)

                PasscodeDotsView(enteredCount: step == 1 ? passcode.count : confirmPasscode.count)

                if showError {
                    Text("Passcodes don't match")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                PasscodeKeypad(
                    enteredPasscode: step == 1 ? $passcode : $confirmPasscode,
                    onComplete: handleComplete,
                    onBiometricTap: nil
                )

                Spacer()
            }
            .padding()
            .navigationTitle("Set Passcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func handleComplete() {
        if step == 1 {
            step = 2
        } else {
            if passcode == confirmPasscode {
                let hash = hashPasscode(passcode)
                UserDefaults.standard.set(hash, forKey: "storedPasscodeHash")
                isPasscodeSet = true
                dismiss()
            } else {
                showError = true
                confirmPasscode = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showError = false
                }
            }
        }
    }

    private func hashPasscode(_ passcode: String) -> String {
        let data = Data(passcode.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Fellow Identity Picker Sheet

struct FellowIdentityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let fellows: [User]

    var body: some View {
        NavigationStack {
            List {
                if fellows.isEmpty {
                    Section {
                        Text("No fellows have been set up by the administrator yet.")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } else {
                    Section {
                        ForEach(fellows) { fellow in
                            Button {
                                appState.selectedFellowId = fellow.id
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(fellow.displayName)
                                            .foregroundColor(Color(UIColor.label))
                                        if !fellow.email.isEmpty {
                                            Text(fellow.email)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if appState.selectedFellowId == fellow.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Select Your Identity")
                    } footer: {
                        Text("Select the fellow profile that was created for you by the program administrator.")
                    }
                }
            }
            .navigationTitle("Fellow Identity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Attending Identity Picker Sheet

struct AttendingIdentityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let attendings: [Attending]

    var body: some View {
        NavigationStack {
            List {
                if attendings.isEmpty {
                    Section {
                        Text("No attendings have been set up by the administrator yet.")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } else {
                    Section {
                        ForEach(attendings) { attending in
                            Button {
                                appState.selectedAttendingId = attending.id
                                dismiss()
                            } label: {
                                HStack {
                                    Text(attending.name)
                                        .foregroundColor(Color(UIColor.label))
                                    Spacer()
                                    if appState.selectedAttendingId == attending.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Select Your Identity")
                    } footer: {
                        Text("Select the attending profile that matches you. This will be used for attestation.")
                    }
                }
            }
            .navigationTitle("Attending Identity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Default Facility Picker Sheet

struct DefaultFacilityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let facilities: [TrainingFacility]

    var body: some View {
        NavigationStack {
            List {
                if facilities.isEmpty {
                    Section {
                        Text("No facilities have been set up yet.")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } else {
                    Section {
                        // Option to clear default
                        Button {
                            appState.defaultFacilityId = nil
                            dismiss()
                        } label: {
                            HStack {
                                Text("No Default")
                                    .foregroundColor(Color(UIColor.label))
                                Spacer()
                                if appState.defaultFacilityId == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }

                        ForEach(facilities) { facility in
                            Button {
                                appState.defaultFacilityId = facility.id
                                dismiss()
                            } label: {
                                HStack {
                                    Text(facility.name)
                                        .foregroundColor(Color(UIColor.label))
                                    Spacer()
                                    if appState.defaultFacilityId == facility.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Select Default Facility")
                    } footer: {
                        Text("This facility will be pre-selected when adding new cases. You can change it for rotations.")
                    }
                }
            }
            .navigationTitle("Default Facility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Fellowship Specialty Picker Sheet

struct FellowshipSpecialtyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                // Fellowships Section
                Section {
                    ForEach(fellowshipSpecialties) { specialty in
                        specialtyRow(specialty)
                    }
                } header: {
                    Text("Fellowships")
                }

                // Residencies Section
                Section {
                    ForEach(residencySpecialties) { specialty in
                        specialtyRow(specialty)
                    }
                } header: {
                    Text("Residencies")
                }
            }
            .navigationTitle("Program Specialty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var fellowshipSpecialties: [FellowshipSpecialty] {
        [.cardiology, .gastroenterology, .pulmonaryCriticalCare, .nephrology, .painMedicine, .interventionalRadiology]
    }

    private var residencySpecialties: [FellowshipSpecialty] {
        [.generalSurgery, .orthopedicSurgery, .emergencyMedicine, .anesthesiology, .obgyn,
         .neurosurgery, .cardiothoracicSurgery, .vascularSurgery, .plasticSurgery, .urology,
         .entOtolaryngology, .ophthalmology, .internalMedicine, .familyMedicine, .pediatrics, .dermatology]
    }

    @ViewBuilder
    private func specialtyRow(_ specialty: FellowshipSpecialty) -> some View {
        Button {
            appState.individualFellowshipSpecialty = specialty
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: specialty.iconName)
                    .foregroundColor(.purple)
                    .font(.title3)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(specialty.displayName)
                        .foregroundColor(.primary)
                        .font(.body)

                    if specialty.isCardiology {
                        Text("Includes IC, EP, and Cardiac Imaging")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Auto-enables \(specialty.defaultPackIds.first ?? "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if appState.individualFellowshipSpecialty == specialty {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.body.weight(.semibold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(AppState())
        .modelContainer(for: [CaseEntry.self, Attending.self, TrainingFacility.self, CustomProcedure.self, CustomAccessSite.self, CustomComplication.self], inMemory: true)
}
