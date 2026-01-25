// RootView.swift
// Procedus - Unified
// Root navigation with onboarding and mode selection

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

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
    
    @State private var individualSelectedTab: FellowTab = .log

    @ViewBuilder
    private var individualTabView: some View {
        FellowContentWrapper(selectedTab: $individualSelectedTab) {
            TabView(selection: $individualSelectedTab) {
                IndividualLogView()
                    .tabItem {
                        Label("Case Log", systemImage: "list.clipboard")
                    }
                    .tag(FellowTab.log)

                MyImageLibraryView()
                    .tabItem {
                        Label("Images", systemImage: "photo.on.rectangle.angled")
                    }
                    .tag(FellowTab.images)

                AnalyticsView()
                    .tabItem {
                        Label("Analytics", systemImage: "chart.bar")
                    }
                    .tag(FellowTab.analytics)

                DutyHoursView()
                    .tabItem {
                        Label("Hours", systemImage: "clock")
                    }
                    .tag(FellowTab.hours)
            }
        }
    }

    @State private var institutionalFellowSelectedTab: FellowTab = .log

    @ViewBuilder
    private var institutionalTabView: some View {
        switch appState.userRole {
        case .fellow:
            FellowContentWrapper(selectedTab: $institutionalFellowSelectedTab) {
                TabView(selection: $institutionalFellowSelectedTab) {
                    IndividualLogView()
                        .tabItem {
                            Label("Case Log", systemImage: "list.clipboard")
                        }
                        .tag(FellowTab.log)

                    MyImageLibraryView()
                        .tabItem {
                            Label("Images", systemImage: "photo.on.rectangle.angled")
                        }
                        .tag(FellowTab.images)

                    AnalyticsView()
                        .tabItem {
                            Label("Analytics", systemImage: "chart.bar")
                        }
                        .tag(FellowTab.analytics)

                    DutyHoursView()
                        .tabItem {
                            Label("Hours", systemImage: "clock")
                        }
                        .tag(FellowTab.hours)
                }
            }

        case .attending:
            AttendingContentWrapper {
                TabView {
                    AttestationQueueView()
                        .tabItem {
                            Label("Attestation", systemImage: "checkmark.seal")
                        }

                    AttendingImageLibraryView()
                        .tabItem {
                            Label("Images", systemImage: "photo.on.rectangle.angled")
                        }

                    AttendingAnalyticsView()
                        .tabItem {
                            Label("Analytics", systemImage: "chart.bar")
                        }
                }
            }
            
        case .admin:
            AdminContentWrapper {
                TabView {
                    AdminDashboardView()
                        .tabItem {
                            Label("Admin", systemImage: "gear.badge")
                        }
                }
            }
        }
    }
}

// MARK: - Fellow Tab Enum

enum FellowTab: Int, Hashable {
    case log = 0
    case images = 1
    case analytics = 2
    case hours = 3
}

// MARK: - Fellow Content Wrapper (Unified Top Bar)

struct FellowContentWrapper<Content: View>: View {
    @Binding var selectedTab: FellowTab
    @ViewBuilder let content: () -> Content

    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Query private var notifications: [Procedus.Notification]
    @Query(sort: \CaseEntry.createdAt, order: .reverse) private var allCases: [CaseEntry]
    @Query(filter: #Predicate<Attending> { !$0.isArchived }) private var attendings: [Attending]
    @Query(filter: #Predicate<TrainingFacility> { !$0.isArchived }) private var facilities: [TrainingFacility]

    @State private var showingSettings = false
    @State private var showingNotifications = false
    @State private var showingAddCase = false
    @State private var showingExportOptions = false

    /// Only show add case and export buttons on the Log tab
    private var showCaseLogActions: Bool {
        selectedTab == .log
    }

    private var currentUserId: UUID {
        if appState.isIndividualMode {
            let key = "individualUserUUID"
            if let uuidString = UserDefaults.standard.string(forKey: key),
               let uuid = UUID(uuidString: uuidString) {
                return uuid
            }
            let newUUID = UUID()
            UserDefaults.standard.set(newUUID.uuidString, forKey: key)
            return newUUID
        }
        return appState.selectedFellowId ?? appState.currentUser?.id ?? UUID()
    }

    private var unreadNotificationCount: Int {
        return notifications.filter { $0.userId == currentUserId && !$0.isRead && !$0.isCleared }.count
    }

    private var myCases: [CaseEntry] {
        allCases.filter { $0.ownerId == currentUserId || $0.fellowId == currentUserId }
    }

    // Colors for light/dark mode
    private var barBackgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : .white
    }

    private var inactiveIconColor: Color {
        colorScheme == .dark ? Color(UIColor.secondaryLabel) : Color(UIColor.darkGray)
    }

    private var activeIconColor: Color {
        ProcedusTheme.primary
    }

    /// Settings gear color - Fellow blue
    private var settingsGearColor: Color {
        ProcedusTheme.primary
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color(UIColor.separator) : Color(UIColor.separator)
    }

    /// Title text for current tab
    private var currentTabTitle: String {
        switch selectedTab {
        case .log: return "Log"
        case .images: return "Images"
        case .analytics: return "Analytics"
        case .hours: return "Hours"
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Main content (TabView) - pushed down to make room for top bar
            content()
                .padding(.top, 64)

            // Unified top bar
            unifiedTopBar
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsSheet(role: appState.isIndividualMode ? .fellow : appState.userRole, userId: currentUserId)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingAddCase) {
            IndividualAddEditCaseView(weekBucket: CaseEntry.makeWeekBucket(for: Date()))
        }
        .sheet(isPresented: $showingExportOptions) {
            FellowExportSheet(
                cases: myCases,
                fellowName: appState.currentUser?.fullName ?? "Fellow",
                attendings: Array(attendings),
                facilities: Array(facilities)
            )
        }
    }

    // MARK: - Unified Top Bar

    private var unifiedTopBar: some View {
        HStack(spacing: 12) {
            // Left: Notification logo + Settings gear
            HStack(spacing: 10) {
                NotificationBellButton(
                    role: .fellow,
                    badgeCount: unreadNotificationCount
                ) {
                    showingNotifications = true
                }

                // Settings gear icon (Fellow blue)
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(settingsGearColor)
                        .frame(width: 28, height: 28)
                }
            }

            Spacer()

            // Center: Tab title
            Text(currentTabTitle)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(ProcedusTheme.textPrimary)

            Spacer()

            // Right: Export and Add buttons (only on Log tab)
            if showCaseLogActions {
                HStack(spacing: 16) {
                    Button {
                        showingExportOptions = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                            .foregroundStyle(myCases.isEmpty ? inactiveIconColor.opacity(0.5) : inactiveIconColor)
                    }
                    .disabled(myCases.isEmpty)

                    Button {
                        showingAddCase = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(activeIconColor)
                    }
                }
            } else {
                // Placeholder to balance the layout when buttons aren't shown
                HStack(spacing: 16) {
                    Color.clear.frame(width: 18, height: 18)
                    Color.clear.frame(width: 18, height: 18)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            barBackgroundColor
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Attending Content Wrapper (Unified Top Bar)

struct AttendingContentWrapper<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Query private var notifications: [Procedus.Notification]

    @State private var showingSettings = false
    @State private var showingNotifications = false

    private var currentUserId: UUID {
        appState.currentUser?.id ?? UUID()
    }

    private var unreadNotificationCount: Int {
        return notifications.filter { $0.userId == currentUserId && !$0.isRead && !$0.isCleared }.count
    }

    // Colors for light/dark mode
    private var barBackgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : .white
    }

    private var inactiveIconColor: Color {
        colorScheme == .dark ? Color(UIColor.secondaryLabel) : Color(UIColor.darkGray)
    }

    /// Settings gear color - Attending green
    private var settingsGearColor: Color {
        ProcedusTheme.success
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Main content (TabView) - pushed down to make room for top bar
            content()
                .padding(.top, 64)

            // Unified top bar
            attendingTopBar
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsSheet(role: .attending, userId: currentUserId)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
    }

    // MARK: - Attending Top Bar

    private var attendingTopBar: some View {
        HStack(spacing: 12) {
            // Left: Notification logo + Settings gear
            HStack(spacing: 10) {
                NotificationBellButton(
                    role: .attending,
                    badgeCount: unreadNotificationCount
                ) {
                    showingNotifications = true
                }

                // Settings gear icon (Attending green)
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(settingsGearColor)
                        .frame(width: 28, height: 28)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            barBackgroundColor
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Admin Content Wrapper (Unified Top Bar)

struct AdminContentWrapper<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Query private var notifications: [Procedus.Notification]

    @State private var showingSettings = false
    @State private var showingNotifications = false

    private var currentUserId: UUID {
        appState.currentUser?.id ?? UUID()
    }

    private var unreadNotificationCount: Int {
        return notifications.filter { $0.userId == currentUserId && !$0.isRead && !$0.isCleared }.count
    }

    // Colors for light/dark mode
    private var barBackgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : .white
    }

    private var inactiveIconColor: Color {
        colorScheme == .dark ? Color(UIColor.secondaryLabel) : Color(UIColor.darkGray)
    }

    /// Settings gear color - Admin pink
    private var settingsGearColor: Color {
        Color.pink
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Main content (TabView) - pushed down to make room for top bar
            content()
                .padding(.top, 64)

            // Unified top bar
            adminTopBar
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsSheet(role: .admin, userId: currentUserId)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
    }

    // MARK: - Admin Top Bar

    private var adminTopBar: some View {
        HStack(spacing: 12) {
            // Left: Notification logo + Settings gear
            HStack(spacing: 10) {
                NotificationBellButton(
                    role: .admin,
                    badgeCount: unreadNotificationCount
                ) {
                    showingNotifications = true
                }

                // Settings gear icon (Admin pink)
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(settingsGearColor)
                        .frame(width: 28, height: 28)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            barBackgroundColor
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
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

            Image("LumenusLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 150, height: 150)

            Text("Welcome to Lumenus")
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

// MARK: - Preview

#Preview {
    RootView()
        .environment(AppState())
        .modelContainer(for: [CaseEntry.self, Attending.self, TrainingFacility.self], inMemory: true)
}
