// RootView.swift
// Procedus - Unified
// Root navigation with onboarding and mode selection

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else {
                mainContentView
            }
        }
    }
    
    @ViewBuilder
    private var mainContentView: some View {
        if appState.isIndividualMode {
            individualTabView
        } else {
            institutionalTabView
        }
    }
    
    @ViewBuilder
    private var individualTabView: some View {
        TabView {
            IndividualLogView()
                .tabItem {
                    Label("Log", systemImage: "list.clipboard")
                }

            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar")
                }

            BadgeDashboardView()
                .tabItem {
                    Label("Badges", systemImage: "trophy")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
    
    @ViewBuilder
    private var institutionalTabView: some View {
        switch appState.userRole {
        case .fellow:
            TabView {
                IndividualLogView()
                    .tabItem {
                        Label("Log", systemImage: "list.clipboard")
                    }

                AnalyticsView()
                    .tabItem {
                        Label("Analytics", systemImage: "chart.bar")
                    }

                BadgeDashboardView()
                    .tabItem {
                        Label("Badges", systemImage: "trophy")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            
        case .attending:
            TabView {
                AttestationQueueView()
                    .tabItem {
                        Label("Attestation", systemImage: "checkmark.seal")
                    }

                AttendingAnalyticsView()
                    .tabItem {
                        Label("Analytics", systemImage: "chart.bar")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            
        case .admin:
            TabView {
                AdminDashboardView()
                    .tabItem {
                        Label("Admin", systemImage: "gear.badge")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var showingModeSelection = false
    @State private var showingIndividualSetup = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "stethoscope.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(ProcedusTheme.primary)

            Text("Welcome to Procedus")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Track your procedural training with ease")
                .font(.subheadline)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)

            Spacer()

            VStack(spacing: 16) {
                // Individual Mode Button
                Button {
                    showingIndividualSetup = true
                } label: {
                    HStack {
                        Image(systemName: "person.fill")
                        Text("Individual Mode")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ProcedusTheme.primary)
                    .cornerRadius(12)
                }

                // Institutional Mode Button
                Button {
                    showingModeSelection = true
                } label: {
                    HStack {
                        Image(systemName: "building.2.fill")
                        Text("Join Institution")
                    }
                    .font(.headline)
                    .foregroundStyle(ProcedusTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ProcedusTheme.primary.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .sheet(isPresented: $showingModeSelection) {
            InstitutionalSetupView()
        }
        .sheet(isPresented: $showingIndividualSetup) {
            IndividualSetupView()
        }
    }
}

// MARK: - Individual Setup View

struct IndividualSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedPGYLevel: PGYLevel? = nil
    @State private var selectedSpecialty: FellowshipSpecialty? = nil

    var body: some View {
        NavigationStack {
            Form {
                // Welcome section
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 50))
                            .foregroundStyle(ProcedusTheme.primary)

                        Text("Set Up Your Profile")
                            .font(.headline)

                        Text("Tell us a bit about yourself to personalize your experience.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                // Name section
                Section {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                } header: {
                    Text("Your Name")
                } footer: {
                    Text("This will appear on your procedure logs and reports.")
                }

                // Training Year section
                Section {
                    Picker("PGY Level", selection: $selectedPGYLevel) {
                        Text("Select Level").tag(nil as PGYLevel?)
                        ForEach(PGYLevel.allCases) { level in
                            Text(level.displayName).tag(level as PGYLevel?)
                        }
                    }
                } header: {
                    Text("Training Year")
                } footer: {
                    Text("Your post-graduate year helps organize analytics by training level.")
                }

                // Fellowship Type section
                Section {
                    Picker("Fellowship Type", selection: $selectedSpecialty) {
                        Text("Select Specialty").tag(nil as FellowshipSpecialty?)
                        ForEach(FellowshipSpecialty.allCases) { specialty in
                            Text(specialty.displayName).tag(specialty as FellowshipSpecialty?)
                        }
                    }
                } header: {
                    Text("Fellowship Type")
                } footer: {
                    Text("This will enable the appropriate procedure packs for your specialty.")
                }

                // Continue button
                Section {
                    Button {
                        completeSetup()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Get Started")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty)
                }
            }
            .navigationTitle("Individual Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Skip") {
                        skipSetup()
                    }
                }
            }
        }
    }

    private func completeSetup() {
        // Save profile info
        UserDefaults.standard.set(firstName, forKey: "individualFirstName")
        UserDefaults.standard.set(lastName, forKey: "individualLastName")

        if let pgyLevel = selectedPGYLevel {
            appState.individualPGYLevel = pgyLevel
        }

        if let specialty = selectedSpecialty {
            appState.individualFellowshipSpecialty = specialty
            // Enable packs for this specialty
            appState.enablePacksForSpecialty(specialty)
        }

        // Complete onboarding
        appState.setupIndividualMode()
        dismiss()
    }

    private func skipSetup() {
        // Complete onboarding without saving profile
        appState.setupIndividualMode()
        dismiss()
    }
}

// MARK: - Institutional Setup View

struct InstitutionalSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query private var programs: [Program]
    @Query private var users: [User]

    @State private var inviteCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String?

    // Join result
    @State private var matchedProgram: Program?
    @State private var determinedRole: UserRole?
    @State private var showingRoleSetup = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Invite Code", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.title3, design: .monospaced))
                } header: {
                    Text("Enter your program's invite code")
                } footer: {
                    Text("Get this code from your program administrator.")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(ProcedusTheme.error)
                    }
                }

                Section {
                    Button {
                        joinProgram()
                    } label: {
                        HStack {
                            Spacer()
                            if isJoining {
                                ProgressView()
                            } else {
                                Text("Join Program")
                            }
                            Spacer()
                        }
                    }
                    .disabled(inviteCode.count < 6 || isJoining)
                }

                #if DEBUG
                Section("Dev Mode") {
                    Button("Sign in as Fellow") {
                        appState.devSignIn(role: .fellow)
                        appState.hasCompletedOnboarding = true
                        dismiss()
                    }
                    Button("Sign in as Attending") {
                        appState.devSignIn(role: .attending)
                        appState.hasCompletedOnboarding = true
                        dismiss()
                    }
                    Button("Sign in as Admin") {
                        appState.devSignIn(role: .admin)
                        appState.hasCompletedOnboarding = true
                        dismiss()
                    }
                }
                #endif
            }
            .navigationTitle("Join Institution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showingRoleSetup) {
                if let program = matchedProgram, let role = determinedRole {
                    RoleSetupView(program: program, role: role) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func joinProgram() {
        isJoining = true
        errorMessage = nil

        let code = inviteCode.uppercased().trimmingCharacters(in: .whitespaces)

        // Search for matching program by invite code
        for program in programs {
            if program.fellowInviteCode == code {
                matchedProgram = program
                determinedRole = .fellow
                isJoining = false
                showingRoleSetup = true
                return
            }
            if program.attendingInviteCode == code {
                matchedProgram = program
                determinedRole = .attending
                isJoining = false
                showingRoleSetup = true
                return
            }
            if program.adminInviteCode == code {
                matchedProgram = program
                determinedRole = .admin
                isJoining = false
                showingRoleSetup = true
                return
            }
        }

        // No matching code found
        isJoining = false
        errorMessage = "Invalid invite code. Please check the code and try again."
    }
}

// MARK: - Role Setup View

struct RoleSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    let program: Program
    let role: UserRole
    let onComplete: () -> Void

    @Query private var users: [User]

    // Form fields
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var selectedUserId: UUID?
    @State private var isSaving = false

    // Fellow migration
    @State private var hasPreviousData = false
    @State private var showingMigrationWizard = false

    // Available users for this role
    private var availableUsers: [User] {
        users.filter { $0.role == role && $0.programId == program.id && !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Program info
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(program.name)
                                .font(.headline)
                            Text(program.institutionName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        RoleBadge(role: role)
                    }
                } header: {
                    Text("Program")
                }

                // Identity selection or creation based on role
                if role == .admin {
                    adminSetupSection
                } else if !availableUsers.isEmpty {
                    identitySelectionSection

                    // Migration option for fellows
                    if role == .fellow {
                        migrationSection
                    }

                    // Complete button
                    Section {
                        Button {
                            completeSetup()
                        } label: {
                            HStack {
                                Spacer()
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Text("Complete Setup")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(!canComplete || isSaving)
                    }
                } else {
                    // No pre-created accounts - show error
                    noAccountsSection
                }
            }
            .navigationTitle("Account Setup")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showingMigrationWizard) {
                IndividualToInstitutionalMigrationView()
            }
        }
    }

    // MARK: - Admin Setup Section

    private var adminSetupSection: some View {
        Section {
            TextField("First Name", text: $firstName)
            TextField("Last Name", text: $lastName)
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
        } header: {
            Text("Your Information")
        } footer: {
            Text("As program administrator, you'll be able to manage fellows, attendings, and program settings.")
        }
    }

    // MARK: - Identity Selection Section

    private var identitySelectionSection: some View {
        Section {
            ForEach(availableUsers) { user in
                Button {
                    selectedUserId = user.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.fullName)
                                .foregroundColor(Color(UIColor.label))
                            if !user.email.isEmpty {
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if selectedUserId == user.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))
                        }
                    }
                }
            }
        } header: {
            Text("Select Your Account")
        } footer: {
            Text("Your administrator has pre-created accounts. Select the one that belongs to you.")
        }
    }

    // MARK: - No Accounts Section

    private var noAccountsSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)

                Text("No Account Found")
                    .font(.headline)

                Text("Your program administrator has not created your \(role == .fellow ? "fellow" : "attending") account yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Please contact your administrator and ask them to add your account with your email address.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Migration Section

    private var migrationSection: some View {
        Section {
            Toggle("I have data from Individual Mode", isOn: $hasPreviousData)
        } footer: {
            if hasPreviousData {
                Text("After completing setup, you'll be guided through migrating your existing cases and procedures.")
            } else {
                Text("Enable this if you've been logging cases in Individual Mode and want to transfer them.")
            }
        }
    }

    // MARK: - Validation

    private var canComplete: Bool {
        if role == .admin {
            return !firstName.isEmpty && !lastName.isEmpty
        }
        // For fellows and attendings, must select a pre-created account
        return selectedUserId != nil
    }

    // MARK: - Complete Setup

    private func completeSetup() {
        isSaving = true

        var userToSignIn: User?

        if role == .admin {
            // Admin creates their own user account
            let newUser = User(
                email: email,
                firstName: firstName,
                lastName: lastName,
                role: role,
                accountMode: .institutional,
                programId: program.id
            )
            modelContext.insert(newUser)
            userToSignIn = newUser
        } else if let existingUserId = selectedUserId,
                  let existingUser = availableUsers.first(where: { $0.id == existingUserId }) {
            // Fellow/Attending uses pre-created account
            existingUser.programId = program.id
            existingUser.accountMode = .institutional
            userToSignIn = existingUser
        }

        guard let user = userToSignIn else {
            isSaving = false
            return
        }

        // Save context
        try? modelContext.save()

        // Set up app state
        appState.setupInstitutionalMode(user: user)

        // Store selected identity for role
        if role == .fellow {
            UserDefaults.standard.set(user.id.uuidString, forKey: "selectedFellowId")
        } else if role == .attending {
            UserDefaults.standard.set(user.id.uuidString, forKey: "selectedAttendingId")
        }

        isSaving = false

        // Show migration wizard if needed, otherwise complete
        if hasPreviousData && role == .fellow {
            showingMigrationWizard = true
        } else {
            onComplete()
        }
    }
}

// MARK: - Role Badge

struct RoleBadge: View {
    let role: UserRole

    var body: some View {
        Text(role.displayName)
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(roleColor)
            .cornerRadius(6)
    }

    private var roleColor: Color {
        switch role {
        case .fellow: return .blue
        case .attending: return .green
        case .admin: return .purple
        }
    }
}

// MARK: - Attending Queue View

struct AttendingQueueView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \CaseEntry.createdAt, order: .reverse) private var allCases: [CaseEntry]
    @Query private var allUsers: [User]
    @Query private var notifications: [Procedus.Notification]
    @Query private var programs: [Program]

    @State private var showingNotifications = false
    @State private var showingAttestAllConfirm = false
    #if DEBUG
    @State private var showAllPending = true
    #endif

    private var currentProgram: Program? { programs.first }

    private var evaluationsRequired: Bool {
        currentProgram?.evaluationsEnabled == true && currentProgram?.evaluationsRequired == true
    }

    private var pendingCases: [CaseEntry] {
        #if DEBUG
        if showAllPending {
            return allCases.filter {
                $0.attestationStatus == .pending || $0.attestationStatus == .requested
            }
        }
        #endif
        // In production, only show cases where this attending is the supervisor
        guard let currentUserId = appState.currentUser?.id else { return [] }
        return allCases.filter {
            ($0.attestationStatus == .pending || $0.attestationStatus == .requested) &&
            $0.supervisorId == currentUserId
        }
    }

    private var unreadNotificationCount: Int {
        guard let userId = appState.currentUser?.id else { return 0 }
        return notifications.filter { $0.userId == userId && !$0.isRead }.count
    }

    private func fellowName(for caseEntry: CaseEntry) -> String {
        allUsers.first { $0.id == caseEntry.fellowId || $0.id == caseEntry.ownerId }?.lastName ?? "Unknown"
    }

    // Get unique procedure categories for a case
    private func procedureCategories(for caseEntry: CaseEntry) -> [ProcedureCategory] {
        var seen = Set<ProcedureCategory>()
        var result: [ProcedureCategory] = []
        for procedureId in caseEntry.procedureTagIds {
            if let category = SpecialtyPackCatalog.findCategory(for: procedureId) {
                if !seen.contains(category) {
                    seen.insert(category)
                    result.append(category)
                }
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Notification bell header
                    HStack {
                        Button {
                            showingNotifications = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.2))
                                    .frame(width: 44, height: 44)

                                if unreadNotificationCount > 0 {
                                    Text("\(unreadNotificationCount)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    // Title
                    HStack {
                        Text("Attestations")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    #if DEBUG
                    // Debug toggle
                    HStack {
                        Text("Show ALL pending (debug)")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Spacer()
                        Toggle("", isOn: $showAllPending)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    #endif

                    if pendingCases.isEmpty {
                        ContentUnavailableView(
                            "No Pending Cases",
                            systemImage: "checkmark.seal",
                            description: Text("All cases have been attested")
                        )
                        .padding(.top, 60)
                    } else {
                        // Info section with Attest All button
                        VStack(spacing: 12) {
                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(pendingCases.count) pending attestations")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    if evaluationsRequired {
                                        Text("Tap a case to review and complete required evaluations")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Tap a case to review individually, or attest all at once")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                // Attest All button (hidden when evaluations required)
                                if !evaluationsRequired && pendingCases.count > 1 {
                                    Button {
                                        showingAttestAllConfirm = true
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text("Attest All")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                            Text("I supervised")
                                                .font(.caption)
                                            Text("these cases")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.green)
                                        .cornerRadius(12)
                                    }
                                }
                            }

                            // Show info message when evaluations are required
                            if evaluationsRequired && pendingCases.count > 1 {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("Bulk attestation disabled — evaluations are required")
                                        .font(.caption)
                                        .foregroundColor(Color(UIColor.secondaryLabel))
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // Cases list
                        VStack(spacing: 0) {
                            ForEach(Array(pendingCases.enumerated()), id: \.element.id) { index, caseEntry in
                                NavigationLink {
                                    AttestationDetailView(caseEntry: caseEntry)
                                } label: {
                                    HStack(spacing: 12) {
                                        // Fellow name
                                        Text(fellowName(for: caseEntry))
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(Color(UIColor.label))

                                        // Category bubbles
                                        HStack(spacing: 4) {
                                            ForEach(procedureCategories(for: caseEntry).prefix(3), id: \.self) { category in
                                                CategoryBubble(category: category, size: 24)
                                            }
                                        }

                                        Spacer()

                                        // Date range
                                        Text(caseEntry.weekBucket.toWeekTimeframeLabel())
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }

                                if index < pendingCases.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNotifications) {
                NotificationsSheet(role: .attending, userId: appState.currentUser?.id)
            }
            .alert("Attest All Cases?", isPresented: $showingAttestAllConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Attest All") {
                    attestAllCases()
                }
            } message: {
                Text("This will attest all \(pendingCases.count) pending cases. You are confirming that you supervised all these cases.")
            }
        }
    }

    private func attestAllCases() {
        guard let userId = appState.currentUser?.id else { return }
        for caseEntry in pendingCases {
            caseEntry.attestationStatus = .attested
            caseEntry.attestedAt = Date()
            caseEntry.attestorId = userId
        }
        try? modelContext.save()
    }
}

// MARK: - Attestation Detail View

struct AttestationDetailView: View {
    let caseEntry: CaseEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var allUsers: [User]
    @Query private var attendings: [Attending]
    @Query private var facilities: [TrainingFacility]

    @State private var comment = ""
    @State private var showingRejectDialog = false
    @State private var rejectionReason = ""

    private var fellowName: String {
        allUsers.first { $0.id == caseEntry.fellowId || $0.id == caseEntry.ownerId }?.displayName ?? "Unknown Fellow"
    }

    private var attendingName: String {
        attendings.first { $0.id == caseEntry.attendingId }?.name ?? ""
    }

    private var facilityName: String {
        facilities.first { $0.id == caseEntry.facilityId }?.name ?? ""
    }

    // Get unique procedure categories for this case
    private var procedureCategories: [ProcedureCategory] {
        var seen = Set<ProcedureCategory>()
        var result: [ProcedureCategory] = []
        for procedureId in caseEntry.procedureTagIds {
            if let category = SpecialtyPackCatalog.findCategory(for: procedureId) {
                if !seen.contains(category) {
                    seen.insert(category)
                    result.append(category)
                }
            }
        }
        return result
    }

    var body: some View {
        Form {
            // Case Information
            Section {
                HStack {
                    Text("Fellow")
                    Spacer()
                    Text(fellowName)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Week")
                    Spacer()
                    Text(caseEntry.weekBucket.toWeekTimeframeLabel())
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Procedures")
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(procedureCategories.prefix(5), id: \.self) { category in
                            CategoryBubble(category: category, size: 20)
                        }
                        Text("\(caseEntry.procedureTagIds.count)")
                            .foregroundColor(.secondary)
                    }
                }
                if !facilityName.isEmpty {
                    HStack {
                        Text("Facility")
                        Spacer()
                        Text(facilityName)
                            .foregroundColor(.secondary)
                    }
                }
                HStack {
                    Text("Outcome")
                    Spacer()
                    Text(caseEntry.outcome.rawValue)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Case Details")
            }

            // Comment Section
            Section {
                TextField("Add a comment...", text: $comment, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("Comment (Optional)")
            }

            // Attest Button - Green, prominent
            Section {
                Button {
                    attestCase()
                } label: {
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Attest")
                                .fontWeight(.bold)
                        }
                        .font(.headline)
                        Text("I supervised this trainee for this case")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(10)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Reject Button
            Section {
                Button {
                    showingRejectDialog = true
                } label: {
                    HStack {
                        Image(systemName: "xmark.seal.fill")
                        Text("Reject Case")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Review Case")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reject Case", isPresented: $showingRejectDialog) {
            TextField("Reason for rejection", text: $rejectionReason)
            Button("Cancel", role: .cancel) {
                rejectionReason = ""
            }
            Button("Reject", role: .destructive) {
                rejectCase()
            }
            .disabled(rejectionReason.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Please provide a reason for rejecting this case. The fellow will be notified.")
        }
    }

    private func attestCase() {
        guard let userId = appState.currentUser?.id else { return }
        caseEntry.attestationStatus = .attested
        caseEntry.attestedAt = Date()
        caseEntry.attestorId = userId
        caseEntry.attestationComment = comment.isEmpty ? nil : comment
        try? modelContext.save()

        // Check and award badges for the fellow
        if let fellowId = caseEntry.fellowId ?? caseEntry.ownerId {
            checkAndAwardBadges(for: fellowId)
        }

        dismiss()
    }

    private func rejectCase() {
        guard let userId = appState.currentUser?.id else { return }
        caseEntry.attestationStatus = .rejected
        caseEntry.rejectionReason = rejectionReason.trimmingCharacters(in: .whitespaces)
        caseEntry.attestorId = userId
        caseEntry.attestationComment = comment.isEmpty ? nil : comment

        // Create database notification for the fellow
        if let fellowId = caseEntry.fellowId ?? caseEntry.ownerId {
            let reason = rejectionReason.trimmingCharacters(in: .whitespaces)
            let notification = Procedus.Notification(
                userId: fellowId,
                title: "Case Rejected",
                message: "Your case was rejected. Reason: \(reason.prefix(200))",
                notificationType: NotificationType.caseRejected.rawValue,
                caseId: caseEntry.id
            )
            modelContext.insert(notification)
        }

        try? modelContext.save()
        dismiss()
    }

    private func checkAndAwardBadges(for fellowId: UUID) {
        let casesDescriptor = FetchDescriptor<CaseEntry>()
        guard let allCases = try? modelContext.fetch(casesDescriptor) else { return }

        let badgesDescriptor = FetchDescriptor<BadgeEarned>(
            predicate: #Predicate<BadgeEarned> { $0.fellowId == fellowId }
        )
        let existingBadges = (try? modelContext.fetch(badgesDescriptor)) ?? []

        let newBadges = BadgeService.shared.checkAndAwardBadges(
            for: fellowId,
            attestedCase: caseEntry,
            allCases: allCases,
            existingBadges: existingBadges,
            modelContext: modelContext
        )

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
}

// MARK: - Simple Attestation Detail View (Backward Compatibility)

struct SimpleAttestationDetailView: View {
    let caseEntry: CaseEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var comment = ""
    @State private var showingRejectDialog = false
    @State private var rejectionReason = ""

    var body: some View {
        Form {
            Section("Case Details") {
                LabeledContent("Week", value: caseEntry.weekBucket.toWeekTimeframeLabel())
                LabeledContent("Procedures", value: "\(caseEntry.procedureTagIds.count)")
                LabeledContent("Outcome", value: caseEntry.outcome.rawValue)
            }

            Section("Comment (Optional)") {
                TextField("Add a comment...", text: $comment, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Button {
                    attestCase()
                } label: {
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Attest")
                                .fontWeight(.bold)
                        }
                        Text("I supervised this trainee for this case")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(10)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    showingRejectDialog = true
                } label: {
                    HStack {
                        Image(systemName: "xmark.seal.fill")
                        Text("Reject Case")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Review Case")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reject Case", isPresented: $showingRejectDialog) {
            TextField("Reason for rejection", text: $rejectionReason)
            Button("Cancel", role: .cancel) {
                rejectionReason = ""
            }
            Button("Reject", role: .destructive) {
                rejectCase()
            }
            .disabled(rejectionReason.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Please provide a reason for rejecting this case. The fellow will be notified.")
        }
    }

    private func attestCase() {
        guard let userId = appState.currentUser?.id else { return }
        caseEntry.attestationStatus = .attested
        caseEntry.attestedAt = Date()
        caseEntry.attestorId = userId
        caseEntry.attestationComment = comment.isEmpty ? nil : comment
        try? modelContext.save()

        // Check and award badges for the fellow
        if let fellowId = caseEntry.fellowId ?? caseEntry.ownerId {
            checkAndAwardBadges(for: fellowId)
        }

        dismiss()
    }

    private func rejectCase() {
        guard let userId = appState.currentUser?.id else { return }
        caseEntry.attestationStatus = .rejected
        caseEntry.rejectionReason = rejectionReason.trimmingCharacters(in: .whitespaces)
        caseEntry.attestorId = userId
        caseEntry.attestationComment = comment.isEmpty ? nil : comment

        // Create database notification for the fellow
        if let fellowId = caseEntry.fellowId ?? caseEntry.ownerId {
            let reason = rejectionReason.trimmingCharacters(in: .whitespaces)
            let notification = Procedus.Notification(
                userId: fellowId,
                title: "Case Rejected",
                message: "Your case was rejected. Reason: \(reason.prefix(200))",
                notificationType: NotificationType.caseRejected.rawValue,
                caseId: caseEntry.id
            )
            modelContext.insert(notification)
        }

        try? modelContext.save()
        dismiss()
    }

    private func checkAndAwardBadges(for fellowId: UUID) {
        let casesDescriptor = FetchDescriptor<CaseEntry>()
        guard let allCases = try? modelContext.fetch(casesDescriptor) else { return }

        let badgesDescriptor = FetchDescriptor<BadgeEarned>(
            predicate: #Predicate<BadgeEarned> { $0.fellowId == fellowId }
        )
        let existingBadges = (try? modelContext.fetch(badgesDescriptor)) ?? []

        let newBadges = BadgeService.shared.checkAndAwardBadges(
            for: fellowId,
            attestedCase: caseEntry,
            allCases: allCases,
            existingBadges: existingBadges,
            modelContext: modelContext
        )

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
}

// MARK: - Preview

#Preview {
    RootView()
        .environment(AppState())
        .modelContainer(for: [CaseEntry.self, Attending.self, TrainingFacility.self], inMemory: true)
}
