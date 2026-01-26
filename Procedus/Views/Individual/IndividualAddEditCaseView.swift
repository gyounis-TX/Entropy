// IndividualAddEditCaseView.swift
// Procedus - Unified
// Add/Edit case with FACILITY REQUIRED, specialty pack name headers, collapsible packs

import SwiftUI
import SwiftData

struct IndividualAddEditCaseView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(filter: #Predicate<Attending> { !$0.isArchived }, sort: \Attending.name)
    private var attendings: [Attending]
    
    @Query(filter: #Predicate<TrainingFacility> { !$0.isArchived }, sort: \TrainingFacility.name)
    private var facilities: [TrainingFacility]
    
    @Query(filter: #Predicate<CustomProcedure> { !$0.isArchived })
    private var customProcedures: [CustomProcedure]
    
    @Query(filter: #Predicate<CustomAccessSite> { !$0.isArchived })
    private var customAccessSites: [CustomAccessSite]
    
    @Query(filter: #Predicate<CustomComplication> { !$0.isArchived })
    private var customComplications: [CustomComplication]

    @Query(filter: #Predicate<CustomProcedureDetail> { !$0.isArchived })
    private var customProcedureDetails: [CustomProcedureDetail]

    @Query private var allUsers: [User]
    @Query private var allCases: [CaseEntry]
    @Query private var earnedBadgesQuery: [BadgeEarned]

    // Form state
    @State private var selectedAttendingId: UUID?
    @State private var selectedFacilityId: UUID?  // REQUIRED - no longer optional
    @State private var selectedWeekBucket: String
    @State private var selectedProcedureTagIds: Set<String> = []
    @State private var selectedAccessSites: Set<String> = []
    @State private var selectedOutcome: CaseOutcome = .success
    @State private var selectedComplications: Set<String> = []
    @State private var selectedDevices: [String: Set<String>] = [:]  // procedureId -> device names
    @State private var customDetailSelections: [String: Set<String>] = [:]  // detailId.uuidString -> selected option strings
    @State private var caseNotes: String = ""
    @State private var showingDeleteConfirmation = false

    // Case type and operator position (cardiology-specific)
    @State private var selectedCaseType: CaseType = .invasive
    @State private var selectedOperatorPosition: OperatorPosition? = nil

    // Noninvasive entry mode
    enum NoninvasiveEntryMode: String, CaseIterable, Identifiable {
        case caseEntry = "Case Entry"
        case bulkEntry = "Bulk Entry"
        var id: String { rawValue }
    }
    @State private var noninvasiveEntryMode: NoninvasiveEntryMode = .caseEntry
    @State private var bulkQuantities: [String: Int] = [:]  // procedureId -> quantity (0-99)
    @State private var bulkShowingSuccess = false
    @State private var bulkSavedCount = 0

    // Badge celebration state
    @State private var earnedBadges: [Badge] = []
    @State private var showingBadgeCelebration = false

    // PHI detection state
    @State private var notesPHIWarning: String?

    // Collapsible state - default ALL to COLLAPSED (closed)
    // We track what's EXPANDED (empty = all closed by default)
    @State private var expandedPackIds: Set<String> = []
    @State private var expandedCategoryIds: Set<String> = []
    
    private let existingCase: CaseEntry?
    private var isEditing: Bool { existingCase != nil }
    
    // Check if all selected procedures are from cardiac imaging pack (noninvasive)
    private var isCardiacImagingOnly: Bool {
        guard !selectedProcedureTagIds.isEmpty else { return false }
        return selectedProcedureTagIds.allSatisfy { tagId in
            tagId.hasPrefix("ci-")  // All cardiac imaging procedures start with "ci-"
        }
    }

    // MARK: - Cardiology-Specific Logic

    /// Whether to show the invasive/noninvasive toggle at top of form
    private var shouldShowCaseTypeToggle: Bool {
        appState.shouldShowCaseTypeToggle
    }

    /// Whether to show the operator position field (cardiology invasive or EP procedures)
    private var shouldShowOperatorPosition: Bool {
        appState.isCardiologyFellowship && (selectedCaseType == .invasive || selectedCaseType == .ep)
    }

    /// Whether to use simplified noninvasive form (no attending, access, outcome, complications)
    private var isSimplifiedNoninvasiveForm: Bool {
        // If cardiac imaging only mode (no IC or EP enabled) - always simplified
        if appState.isCardiacImagingOnlyMode {
            return true
        }
        // If toggle is showing and noninvasive selected (not EP)
        if shouldShowCaseTypeToggle && selectedCaseType == .noninvasive {
            return true
        }
        return false
    }

    /// Case types to show in the toggle based on enabled packs
    private var availableCaseTypes: [CaseType] {
        var types: [CaseType] = []
        let packIds = enabledPacks.map { $0.id }
        if packIds.contains("interventional-cardiology") {
            types.append(.invasive)
        }
        if packIds.contains("electrophysiology") {
            types.append(.ep)
        }
        if packIds.contains("cardiac-imaging") {
            types.append(.noninvasive)
        }
        return types
    }

    /// Filter enabled packs based on current case type selection
    private var filteredEnabledPacks: [SpecialtyPack] {
        let allEnabled = enabledPacks

        // If cardiac imaging only mode, show only cardiac imaging pack
        if appState.isCardiacImagingOnlyMode {
            return allEnabled.filter { $0.id == "cardiac-imaging" }
        }

        // If toggle is showing, filter based on selection
        if shouldShowCaseTypeToggle {
            switch selectedCaseType {
            case .noninvasive:
                // Noninvasive: only cardiac imaging
                return allEnabled.filter { $0.id == "cardiac-imaging" }
            case .ep:
                // EP: only electrophysiology
                return allEnabled.filter { $0.id == "electrophysiology" }
            case .invasive:
                // Invasive: only interventional cardiology
                return allEnabled.filter { $0.id == "interventional-cardiology" }
            }
        }

        // No toggle - show all enabled packs
        return allEnabled
    }

    // FACILITY IS REQUIRED - must have facility AND at least one procedure
    // Attending is required UNLESS using simplified noninvasive form
    // In institutional mode, also require identity selection
    private var canSave: Bool {
        // For bulk entry mode, check if any quantities are > 0
        if isSimplifiedNoninvasiveForm && !isEditing && noninvasiveEntryMode == .bulkEntry {
            let hasBulkQuantities = bulkQuantities.values.reduce(0, +) > 0
            let baseRequirements = selectedFacilityId != nil && hasBulkQuantities
            if appState.isIndividualMode {
                return baseRequirements
            } else {
                return baseRequirements && hasValidIdentity
            }
        }

        // Standard case entry mode
        let hasRequiredFields = selectedFacilityId != nil && !selectedProcedureTagIds.isEmpty
        // Attending not required for simplified noninvasive form or cardiac imaging only procedures
        let hasAttendingOrNoninvasive = selectedAttendingId != nil || isSimplifiedNoninvasiveForm || isCardiacImagingOnly

        let baseRequirements = hasRequiredFields && hasAttendingOrNoninvasive

        if appState.isIndividualMode {
            return baseRequirements
        } else {
            // In institutional mode, require identity selection
            return baseRequirements && hasValidIdentity
        }
    }

    // Check if we have a valid identity in institutional mode
    private var hasValidIdentity: Bool {
        appState.selectedFellowId != nil || appState.currentUser?.id != nil
    }

    // Fellow display name for notifications
    private var fellowDisplayName: String {
        if appState.isIndividualMode {
            return appState.individualDisplayName
        } else {
            // In institutional mode, get name from selected fellow or current user
            if let fellowId = appState.selectedFellowId,
               let fellow = allUsers.first(where: { $0.id == fellowId }) {
                return fellow.displayName
            }
            return appState.currentUser?.displayName ?? appState.individualDisplayName
        }
    }

    private var availableWeekBuckets: [String] {
        generateWeekBuckets(count: 52)
    }
    
    // Complications filtered by case type - IC-specific for invasive
    private var allComplications: [(id: String, title: String, isCustom: Bool)] {
        var result: [(id: String, title: String, isCustom: Bool)] = []
        var seenComplications = Set<String>()

        // For invasive cardiology cases, only show IC-specific complications
        // For noninvasive, show cardiac imaging complications
        let relevantPacks: [SpecialtyPack]
        if selectedCaseType == .noninvasive || isSimplifiedNoninvasiveForm {
            // Cardiac imaging complications only
            relevantPacks = enabledPacks.filter { $0.id == "cardiac-imaging" }
        } else {
            // Invasive: IC and EP complications only (not all packs)
            relevantPacks = enabledPacks.filter { $0.id == "interventional-cardiology" || $0.id == "electrophysiology" }
        }

        for pack in relevantPacks {
            for complication in pack.defaultComplications {
                if !seenComplications.contains(complication.rawValue) {
                    seenComplications.insert(complication.rawValue)
                    result.append((id: complication.rawValue, title: complication.rawValue, isCustom: false))
                }
            }
        }

        // Add custom complications
        for custom in customComplications {
            result.append((id: custom.id.uuidString, title: custom.title, isCustom: true))
        }

        // Sort alphabetically
        return result.sorted { $0.title < $1.title }
    }
    
    // Get enabled specialty packs
    private var enabledPacks: [SpecialtyPack] {
        appState.enabledSpecialtyPackIds.compactMap { packId in
            SpecialtyPackCatalog.allPacks.first { $0.id == packId }
        }
    }
    
    // MARK: - Initializers
    
    init(weekBucket: String? = nil) {
        self.existingCase = nil
        self._selectedWeekBucket = State(initialValue: weekBucket ?? CaseEntry.makeWeekBucket(for: Date()))
    }
    
    init(existingCase: CaseEntry) {
        self.existingCase = existingCase
        self._selectedWeekBucket = State(initialValue: existingCase.weekBucket)
        self._selectedAttendingId = State(initialValue: existingCase.supervisorId)
        self._selectedFacilityId = State(initialValue: existingCase.hospitalId)
        self._selectedProcedureTagIds = State(initialValue: Set(existingCase.procedureTagIds))
        self._selectedAccessSites = State(initialValue: Set(existingCase.accessSiteIds))
        self._selectedOutcome = State(initialValue: existingCase.outcome)
        self._selectedComplications = State(initialValue: Set(existingCase.complicationIds))
        self._caseNotes = State(initialValue: existingCase.notes ?? "")
        // Load existing device selections
        var devices: [String: Set<String>] = [:]
        for (procedureId, deviceList) in existingCase.procedureDevices {
            devices[procedureId] = Set(deviceList)
        }
        self._selectedDevices = State(initialValue: devices)
        // Load existing custom detail selections
        var details: [String: Set<String>] = [:]
        for (detailId, optionList) in existingCase.customDetailSelections {
            details[detailId] = Set(optionList)
        }
        self._customDetailSelections = State(initialValue: details)
        // Load case type and operator position
        self._selectedCaseType = State(initialValue: existingCase.caseType ?? .invasive)
        self._selectedOperatorPosition = State(initialValue: existingCase.operatorPosition)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Show warning if no identity selected in institutional mode
                if !appState.isIndividualMode && !hasValidIdentity {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Identity Not Selected")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Go to Settings > Identity to select your fellow profile before adding cases.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Case type toggle (cardiology with both imaging and other packs)
                if shouldShowCaseTypeToggle {
                    caseTypeToggleSection
                }

                // Attending / Facility / Timeframe dropdowns (side-by-side)
                combinedDropdownSection

                // Access sites section (hidden for simplified noninvasive form)
                if !isSimplifiedNoninvasiveForm {
                    accessSitesSection
                }

                // Operator position section (cardiology invasive only)
                if shouldShowOperatorPosition {
                    operatorPositionSection
                }

                // Entry mode toggle for noninvasive (Case Entry vs Bulk Entry)
                if isSimplifiedNoninvasiveForm && !isEditing {
                    noninvasiveEntryModeSection
                }

                // Procedures Section - varies by mode
                if isSimplifiedNoninvasiveForm && !isEditing && noninvasiveEntryMode == .bulkEntry {
                    // Bulk Entry: Show quantity counters for each imaging modality
                    bulkQuantitySection
                } else if isSimplifiedNoninvasiveForm && !isEditing && noninvasiveEntryMode == .caseEntry {
                    // Case Entry for Noninvasive: Show radio buttons (single selection)
                    noninvasiveCaseEntrySection
                } else {
                    // Standard procedures section (invasive or editing)
                    proceduresSection    // Uses filteredEnabledPacks based on case type
                }

                // Outcome and complications (hidden for simplified noninvasive form)
                if !isSimplifiedNoninvasiveForm {
                    outcomeSection
                    complicationsSection
                }

                notesSection

                // Media Section
                if isEditing, let existing = existingCase {
                    // Edit mode: show full media section
                    Section {
                        CaseMediaSection(
                            caseId: existing.id,
                            ownerId: getOrCreateIndividualUserId(),
                            ownerName: appState.individualDisplayName
                        )
                    } header: {
                        Text("Attachments")
                            .font(.caption)
                    } footer: {
                        Text("Add images or videos. PHI will be detected and must be redacted.")
                            .font(.caption2)
                    }
                } else if !isEditing {
                    // New case: show hint about adding media after saving
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Attachments")
                                    .font(.subheadline)
                                Text("Save case first, then add images/videos")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

                if isEditing {
                    deleteSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(isEditing ? "Edit Case" : "New Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCase() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? ProcedusTheme.primary : ProcedusTheme.textTertiary)
                        .disabled(!canSave)
                }
            }
            .alert("Delete Case", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { deleteCase() }
            } message: {
                Text("Are you sure you want to delete this case? This action cannot be undone.")
            }
            .alert("Studies Added!", isPresented: $bulkShowingSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("\(bulkSavedCount) imaging stud\(bulkSavedCount == 1 ? "y" : "ies") added to your log.")
            }
            .overlay {
                // Badge celebration overlay
                if showingBadgeCelebration && !earnedBadges.isEmpty {
                    MultipleBadgesCelebrationView(badges: earnedBadges) {
                        showingBadgeCelebration = false
                        earnedBadges = []
                        dismiss()
                    }
                    .transition(.opacity)
                }
            }
            .onAppear {
                // Pre-populate default facility for new cases
                if !isEditing && selectedFacilityId == nil {
                    if let defaultFacility = appState.defaultFacilityId {
                        selectedFacilityId = defaultFacility
                    }
                }
            }
        }
    }

    // MARK: - Combined Dropdown Section (Attending / Facility / Date as compact rows)

    private var combinedDropdownSection: some View {
        Section {
            VStack(spacing: 6) {
                // Attending row
                if !isSimplifiedNoninvasiveForm {
                    HStack(spacing: 8) {
                        Text("Attending")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 68, alignment: .leading)

                        if attendings.isEmpty {
                            Text("Add in Settings")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Spacer()
                        } else {
                            Menu {
                                Button("None") { selectedAttendingId = nil }
                                ForEach(attendings) { attending in
                                    Button(attending.name) {
                                        selectedAttendingId = attending.id
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(selectedAttendingId.flatMap { id in
                                        attendings.first { $0.id == id }?.name
                                    } ?? "Select")
                                        .font(.footnote)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                    Spacer(minLength: 2)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(UIColor.tertiarySystemFill))
                                .cornerRadius(8)
                            }
                            .foregroundColor(selectedAttendingId != nil ? .primary : .secondary)
                        }
                    }
                }

                // Facility row
                HStack(spacing: 8) {
                    Text("Facility")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 68, alignment: .leading)

                    if facilities.isEmpty {
                        Text("Add in Settings")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    } else {
                        Menu {
                            Button("None") { selectedFacilityId = nil }
                            ForEach(facilities) { facility in
                                Button(facility.name) {
                                    selectedFacilityId = facility.id
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedFacilityId.flatMap { id in
                                    facilities.first { $0.id == id }?.name
                                } ?? "Select")
                                    .font(.footnote)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                Spacer(minLength: 2)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.tertiarySystemFill))
                            .cornerRadius(8)
                        }
                        .foregroundColor(selectedFacilityId != nil ? .primary : .secondary)
                    }
                }

                // Date row
                HStack(spacing: 8) {
                    Text("Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 68, alignment: .leading)

                    Menu {
                        ForEach(availableWeekBuckets, id: \.self) { bucket in
                            Button(bucket.toWeekTimeframeLabel()) {
                                selectedWeekBucket = bucket
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedWeekBucket.toWeekTimeframeLabel())
                                .font(.footnote)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Spacer(minLength: 2)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.tertiarySystemFill))
                        .cornerRadius(8)
                    }
                    .foregroundColor(.primary)
                }
            }
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Attending Section

    private var attendingSection: some View {
        Section {
            if attendings.isEmpty {
                Text("Add in Settings")
                    .font(.clinicalCaption)
                    .foregroundStyle(ProcedusTheme.textTertiary)
            } else {
                HStack {
                    Spacer()
                    Menu {
                        Button("Select...") {
                            selectedAttendingId = nil
                        }
                        ForEach(attendings) { attending in
                            Button(attending.name) {
                                selectedAttendingId = attending.id
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(selectedAttendingId.flatMap { id in attendings.first { $0.id == id }?.name } ?? "Select...")
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.tertiarySystemFill))
                        .cornerRadius(10)
                    }
                    .foregroundColor(selectedAttendingId != nil ? .primary : .secondary)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        } header: {
            HStack(spacing: 2) {
                Text("Supervising Attending")
                Text("*").foregroundStyle(ProcedusTheme.error)
            }
            .font(.clinicalFootnote)
            .foregroundStyle(ProcedusTheme.textSecondary)
        }
    }
    
    // MARK: - Facility Section (REQUIRED)

    private var facilitySection: some View {
        Section {
            if facilities.isEmpty {
                Text("Add in Settings")
                    .font(.clinicalCaption)
                    .foregroundStyle(ProcedusTheme.textTertiary)
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        Menu {
                            Button("Select...") {
                                selectedFacilityId = nil
                            }
                            ForEach(facilities) { facility in
                                Button(facility.name) {
                                    selectedFacilityId = facility.id
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(selectedFacilityId.flatMap { id in facilities.first { $0.id == id }?.name } ?? "Select...")
                                    .font(.subheadline)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.tertiarySystemFill))
                            .cornerRadius(10)
                        }
                        .foregroundColor(selectedFacilityId != nil ? .primary : .secondary)
                        Spacer()
                    }

                    // Warning when facility not selected
                    if selectedFacilityId == nil {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(ProcedusTheme.warning)
                            Text("Facility is required")
                                .font(.caption)
                                .foregroundStyle(ProcedusTheme.warning)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }
        } header: {
            HStack(spacing: 2) {
                Text("Training Facility")
                Text("*").foregroundStyle(ProcedusTheme.error)
            }
            .font(.clinicalFootnote)
            .foregroundStyle(ProcedusTheme.textSecondary)
        }
    }
    
    // MARK: - Timeframe Section

    private var timeframeSection: some View {
        Section {
            HStack {
                Spacer()
                Menu {
                    ForEach(availableWeekBuckets, id: \.self) { bucket in
                        Button(bucket.toWeekTimeframeLabel()) {
                            selectedWeekBucket = bucket
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(selectedWeekBucket.toWeekTimeframeLabel())
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.tertiarySystemFill))
                    .cornerRadius(10)
                }
                .foregroundColor(.primary)
                Spacer()
            }
            .listRowBackground(Color.clear)
        } header: {
            Text("Procedure Timeframe")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        }
    }

    // MARK: - Case Type Toggle Section (Cardiology with both imaging and other packs)

    private var caseTypeToggleSection: some View {
        Section {
            Picker("Case Type", selection: $selectedCaseType) {
                ForEach(availableCaseTypes) { caseType in
                    Text(caseType.rawValue).tag(caseType)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedCaseType) { _, newValue in
                // Clear selected procedures when case type changes
                selectedProcedureTagIds.removeAll()
                selectedDevices.removeAll()
                bulkQuantities.removeAll()
                // Clear operator position when switching to noninvasive
                if newValue == .noninvasive {
                    selectedOperatorPosition = nil
                    // Default to case entry mode
                    noninvasiveEntryMode = .caseEntry
                    // Auto-expand cardiac imaging pack (but keep subcategories collapsed)
                    expandedPackIds.insert("cardiac-imaging")
                }
            }
        } header: {
            Text("Case Type")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        } footer: {
            switch selectedCaseType {
            case .invasive:
                Text("Invasive procedures requiring sterile access (cath lab)")
            case .ep:
                Text("Electrophysiology procedures (EP lab, device implants, ablations)")
            case .noninvasive:
                Text("Noninvasive imaging studies (echo, CT, MRI, nuclear). Choose entry mode below.")
                    .foregroundColor(.blue)
            }
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }

    // MARK: - Operator Position Section (Cardiology Invasive Only)

    private var operatorPositionSection: some View {
        Section {
            HStack(spacing: 16) {
                ForEach(OperatorPosition.allCases) { position in
                    Button {
                        selectedOperatorPosition = position
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: selectedOperatorPosition == position ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedOperatorPosition == position ? ProcedusTheme.primary : ProcedusTheme.textTertiary)
                                .font(.title3)
                            Text(position.rawValue)
                                .font(.clinicalBody)
                                .foregroundStyle(ProcedusTheme.textPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        } header: {
            Text("Operator Position")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        } footer: {
            Text("Your role during the procedure")
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }

    // MARK: - Access Sites Section

    private var accessSitesSection: some View {
        Section {
            LazyVGrid(columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ], spacing: 12) {
                accessSiteCheckbox(id: "Radial", title: "Radial")
                accessSiteCheckbox(id: "Femoral", title: "Femoral")
                accessSiteCheckbox(id: "Brachial", title: "Brachial")
                accessSiteCheckbox(id: "Pedal", title: "Pedal")
                accessSiteCheckbox(id: "Jugular", title: "Jugular")
                accessSiteCheckbox(id: "Antegrade", title: "Antegrade")
                
                ForEach(customAccessSites) { site in
                    customAccessSiteCheckbox(site: site)
                }
            }
        } header: {
            Text("Access Sites")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    private func accessSiteCheckbox(id: String, title: String) -> some View {
        Button {
            toggleAccessSite(id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selectedAccessSites.contains(id) ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(selectedAccessSites.contains(id) ? ProcedusTheme.info : Color(UIColor.tertiaryLabel))
                Text(title)
                    .font(.clinicalBody)
                    .foregroundStyle(Color(UIColor.label))
            }
        }
        .buttonStyle(.plain)
    }
    
    private func customAccessSiteCheckbox(site: CustomAccessSite) -> some View {
        let isSelected = selectedAccessSites.contains(site.id.uuidString)
        return Button {
            toggleAccessSite(site.id.uuidString)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isSelected ? ProcedusTheme.accent : Color(UIColor.tertiaryLabel))
                Text(site.title)
                    .font(.clinicalBody)
                    .foregroundStyle(Color(UIColor.label))
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(ProcedusTheme.accent)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func toggleAccessSite(_ id: String) {
        if selectedAccessSites.contains(id) {
            selectedAccessSites.remove(id)
        } else {
            selectedAccessSites.insert(id)
        }
    }
    
    // MARK: - Procedures Section (SPECIALTY PACK NAME as header, COLLAPSIBLE packs)
    
    private var proceduresSection: some View {
        Section {
            if filteredEnabledPacks.isEmpty {
                if shouldShowCaseTypeToggle && selectedCaseType == .noninvasive && !enabledPacks.contains(where: { $0.id == "cardiac-imaging" }) {
                    Text("Cardiac Imaging pack not enabled. Go to Settings to add it.")
                        .font(.clinicalBody)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                        .italic()
                } else {
                    Text("No specialty packs enabled. Go to Settings to add one.")
                        .font(.clinicalBody)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                        .italic()
                }
            } else {
                // Each specialty pack is COLLAPSIBLE with pack name as header
                // Filtered based on case type (invasive excludes cardiac imaging, noninvasive only cardiac imaging)
                ForEach(filteredEnabledPacks) { pack in
                    collapsiblePackSection(for: pack)
                }
            }
            
            // Custom procedures (if any)
            if !customProcedures.isEmpty {
                customProceduresSection
            }
        } header: {
            HStack(spacing: 2) {
                Text("Procedures")
                Text("*").foregroundStyle(ProcedusTheme.error)
            }
            .font(.clinicalFootnote)
            .foregroundStyle(ProcedusTheme.textSecondary)
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    // MARK: - Collapsible Specialty Pack Section
    
    @ViewBuilder
    private func collapsiblePackSection(for pack: SpecialtyPack) -> some View {
        // Default to COLLAPSED - only expanded if in expandedPackIds
        let isExpanded = expandedPackIds.contains(pack.id)
        let selectedCountForPack = countSelectedInPack(pack)

        // PACK HEADER - Tappable to expand/collapse entire pack
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded {
                    expandedPackIds.remove(pack.id)
                } else {
                    expandedPackIds.insert(pack.id)
                }
            }
        } label: {
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.textSecondary)
                    .frame(width: 16)

                // SPECIALTY PACK NAME as the header
                Text(pack.name)
                    .font(.clinicalBody)
                    .fontWeight(.bold)
                    .foregroundStyle(ProcedusTheme.primary)

                Spacer()

                if selectedCountForPack > 0 {
                    Text("\(selectedCountForPack)")
                        .font(.clinicalFootnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(ProcedusTheme.primary)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)

        // PACK CONTENTS - Categories within the pack (only if expanded)
        if isExpanded {
            ForEach(pack.categories) { categoryData in
                collapsibleCategorySection(for: categoryData, in: pack)
            }
            .padding(.leading, 12)
        }
    }
    
    // MARK: - Collapsible Category Section (within a pack)
    
    @ViewBuilder
    private func collapsibleCategorySection(for categoryData: PackCategory, in pack: SpecialtyPack) -> some View {
        let categoryKey = "\(pack.id)-\(categoryData.category.rawValue)"
        // Default to COLLAPSED - only expanded if in expandedCategoryIds
        let isExpanded = expandedCategoryIds.contains(categoryKey)
        let selectedCountForCategory = selectedCount(for: categoryData.category)

        // Category header
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded {
                    expandedCategoryIds.remove(categoryKey)
                } else {
                    expandedCategoryIds.insert(categoryKey)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(ProcedusTheme.textTertiary)
                    .frame(width: 12)

                Text(categoryData.category.rawValue)
                    .font(.clinicalBody)
                    .fontWeight(.medium)
                    .foregroundStyle(ProcedusTheme.textPrimary)

                CategoryBubble(category: categoryData.category, size: 18)

                Spacer()

                if selectedCountForCategory > 0 {
                    Text("\(selectedCountForCategory)")
                        .font(.clinicalFootnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(categoryData.category.color)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)

        // Procedures within category (only if expanded)
        if isExpanded {
            ForEach(categoryData.procedures) { procedure in
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: procedureBinding(for: procedure.id)) {
                        Text(procedure.title)
                            .font(.clinicalBody)
                            .foregroundStyle(ProcedusTheme.textPrimary)
                    }
                    .toggleStyle(ClinicalCheckboxToggleStyle())

                    // Show device selection if this is a PE/DVT procedure AND it's selected
                    if ThrombectomyDevice.isEligible(procedureId: procedure.id) && selectedProcedureTagIds.contains(procedure.id) {
                        deviceSelectionView(for: procedure.id)
                    }

                    // Show custom procedure details if applicable AND procedure is selected
                    if selectedProcedureTagIds.contains(procedure.id) && !applicableCustomDetails(for: procedure.id).isEmpty {
                        customDetailSelectionView(for: procedure.id)
                    }
                }
                .padding(.leading, 24)
            }
        }
    }

    // MARK: - Device Selection View (for PE/DVT procedures)

    @ViewBuilder
    private func deviceSelectionView(for procedureId: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Devices Used:")
                .font(.clinicalCaption)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .padding(.leading, 24)

            LazyVGrid(columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ], spacing: 8) {
                ForEach(ThrombectomyDevice.allCases) { device in
                    deviceCheckbox(device: device, procedureId: procedureId)
                }
            }
            .padding(.leading, 24)
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(Color(UIColor.tertiarySystemGroupedBackground).opacity(0.5))
        .cornerRadius(8)
        .padding(.leading, 4)
    }

    private func deviceCheckbox(device: ThrombectomyDevice, procedureId: String) -> some View {
        let isSelected = selectedDevices[procedureId]?.contains(device.rawValue) ?? false
        return Button {
            toggleDevice(device: device, for: procedureId)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? ProcedusTheme.info : Color(UIColor.tertiaryLabel))
                Text(device.rawValue)
                    .font(.clinicalCaption)
                    .foregroundStyle(ProcedusTheme.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }

    private func toggleDevice(device: ThrombectomyDevice, for procedureId: String) {
        var devices = selectedDevices[procedureId] ?? Set<String>()
        if devices.contains(device.rawValue) {
            devices.remove(device.rawValue)
        } else {
            devices.insert(device.rawValue)
        }
        selectedDevices[procedureId] = devices
    }

    // MARK: - Custom Procedure Details Selection

    /// Get custom details that apply to a given procedure
    private func applicableCustomDetails(for procedureId: String) -> [CustomProcedureDetail] {
        customProcedureDetails.filter { $0.appliesTo(procedureId: procedureId) }
    }

    @ViewBuilder
    private func customDetailSelectionView(for procedureId: String) -> some View {
        let applicableDetails = applicableCustomDetails(for: procedureId)

        if !applicableDetails.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(applicableDetails) { detail in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(detail.name):")
                            .font(.clinicalCaption)
                            .foregroundStyle(ProcedusTheme.textSecondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), alignment: .leading),
                            GridItem(.flexible(), alignment: .leading)
                        ], spacing: 8) {
                            ForEach(detail.options, id: \.self) { option in
                                customDetailOptionCheckbox(option: option, detail: detail)
                            }
                        }
                    }
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .background(Color(UIColor.tertiarySystemGroupedBackground).opacity(0.5))
            .cornerRadius(8)
            .padding(.leading, 4)
        }
    }

    private func customDetailOptionCheckbox(option: String, detail: CustomProcedureDetail) -> some View {
        let detailId = detail.id.uuidString
        let isSelected = customDetailSelections[detailId]?.contains(option) ?? false

        return Button {
            toggleCustomDetailOption(option: option, detailId: detailId)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? ProcedusTheme.accent : Color(UIColor.tertiaryLabel))
                Text(option)
                    .font(.clinicalCaption)
                    .foregroundStyle(ProcedusTheme.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }

    private func toggleCustomDetailOption(option: String, detailId: String) {
        var options = customDetailSelections[detailId] ?? Set<String>()
        if options.contains(option) {
            options.remove(option)
        } else {
            options.insert(option)
        }
        customDetailSelections[detailId] = options
    }

    // MARK: - Custom Procedures Section
    
    private var customProceduresSection: some View {
        let customCategoryKey = "custom-procedures"
        // Default to COLLAPSED - only expanded if in expandedCategoryIds
        let isExpanded = expandedCategoryIds.contains(customCategoryKey)
        let customSelectedCount = customProcedures.filter { selectedProcedureTagIds.contains($0.tagId) }.count

        return Group {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedCategoryIds.remove(customCategoryKey)
                    } else {
                        expandedCategoryIds.insert(customCategoryKey)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                        .frame(width: 16)

                    Text("Custom Procedures")
                        .font(.clinicalBody)
                        .fontWeight(.medium)
                        .foregroundStyle(ProcedusTheme.accent)

                    Spacer()

                    if customSelectedCount > 0 {
                        Text("\(customSelectedCount)")
                            .font(.clinicalFootnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(ProcedusTheme.accent)
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            // Only show if expanded
            if isExpanded {
                ForEach(customProcedures) { procedure in
                    Toggle(isOn: procedureBinding(for: procedure.tagId)) {
                        HStack {
                            Text(procedure.title)
                                .font(.clinicalBody)
                                .foregroundStyle(ProcedusTheme.textPrimary)
                            CategoryBubble(category: procedure.category, size: 16)
                        }
                    }
                    .toggleStyle(ClinicalCheckboxToggleStyle())
                    .padding(.leading, 24)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func countSelectedInPack(_ pack: SpecialtyPack) -> Int {
        var count = 0
        for categoryData in pack.categories {
            for procedure in categoryData.procedures {
                if selectedProcedureTagIds.contains(procedure.id) {
                    count += 1
                }
            }
        }
        return count
    }
    
    private func selectedCount(for category: ProcedureCategory) -> Int {
        var count = 0
        for tagId in selectedProcedureTagIds {
            if let foundCategory = SpecialtyPackCatalog.findCategory(for: tagId), foundCategory == category {
                count += 1
            }
        }
        return count
    }
    
    private func procedureBinding(for tagId: String) -> Binding<Bool> {
        Binding(
            get: { selectedProcedureTagIds.contains(tagId) },
            set: { isSelected in
                if isSelected { selectedProcedureTagIds.insert(tagId) }
                else { selectedProcedureTagIds.remove(tagId) }
            }
        )
    }

    // MARK: - Noninvasive Entry Mode Toggle

    private var noninvasiveEntryModeSection: some View {
        Section {
            Picker("Entry Mode", selection: $noninvasiveEntryMode) {
                ForEach(NoninvasiveEntryMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: noninvasiveEntryMode) { _, _ in
                // Clear selections when switching modes
                selectedProcedureTagIds.removeAll()
                bulkQuantities.removeAll()
            }
        } header: {
            Text("Entry Mode")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        } footer: {
            if noninvasiveEntryMode == .caseEntry {
                Text("Log a single imaging study with detailed selection.")
            } else {
                Text("Quickly log multiple studies by quantity per modality.")
            }
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }

    // MARK: - Noninvasive Case Entry (Radio Buttons - Single Selection)

    private var noninvasiveCaseEntrySection: some View {
        Section {
            // Get cardiac imaging procedures from the pack
            let imagingPack = filteredEnabledPacks.first { $0.id == "cardiac-imaging" }
            if let pack = imagingPack {
                ForEach(pack.categories, id: \.id) { packCategory in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedCategoryIds.contains("noninv-\(packCategory.id)") },
                            set: { expanded in
                                if expanded { expandedCategoryIds.insert("noninv-\(packCategory.id)") }
                                else { expandedCategoryIds.remove("noninv-\(packCategory.id)") }
                            }
                        )
                    ) {
                        ForEach(packCategory.procedures) { procedure in
                            noninvasiveRadioRow(procedure: procedure)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(packCategory.category.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(ProcedusTheme.textPrimary)
                            CategoryBubble(category: packCategory.category, size: 20)
                        }
                    }
                }
            } else {
                Text("No imaging procedures available")
                    .font(.subheadline)
                    .foregroundStyle(ProcedusTheme.textSecondary)
            }
        } header: {
            Text("Select Imaging Study")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        } footer: {
            if selectedProcedureTagIds.isEmpty {
                Text("Select one imaging study to log.")
            } else {
                Text("One study selected. Tap Save to log this case.")
            }
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }

    private func noninvasiveRadioRow(procedure: ProcedureTag) -> some View {
        let isSelected = selectedProcedureTagIds.contains(procedure.id)
        return Button {
            // Radio button behavior: select this, deselect others
            selectedProcedureTagIds.removeAll()
            selectedProcedureTagIds.insert(procedure.id)
        } label: {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? ProcedusTheme.primary : ProcedusTheme.textTertiary)
                    .font(.system(size: 20))

                Text(procedure.title)
                    .font(.subheadline)
                    .foregroundStyle(ProcedusTheme.textPrimary)

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bulk Quantity Section (Counters per Modality)

    /// Get all imaging procedures from the cardiac imaging pack
    private var imagingProcedures: [ProcedureTag] {
        guard let pack = filteredEnabledPacks.first(where: { $0.id == "cardiac-imaging" }) else {
            return []
        }
        var procedures: [ProcedureTag] = []
        for category in pack.categories {
            procedures.append(contentsOf: category.procedures)
        }
        return procedures
    }

    private var bulkQuantitySection: some View {
        Section {
            ForEach(imagingProcedures) { procedure in
                bulkQuantityRow(for: procedure)
            }
        } header: {
            Text("Bulk Entry - Studies by Modality")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        } footer: {
            let totalStudies = bulkQuantities.values.reduce(0, +)
            if totalStudies == 0 {
                Text("Use +/- to set the number of studies for each modality.")
            } else {
                Text("Total: \(totalStudies) stud\(totalStudies == 1 ? "y" : "ies") to log.")
                    .foregroundColor(.blue)
            }
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }

    private func bulkQuantityRow(for procedure: ProcedureTag) -> some View {
        let quantity = bulkQuantities[procedure.id] ?? 0

        return HStack {
            // Procedure name
            Text(procedure.title)
                .font(.subheadline)
                .foregroundStyle(ProcedusTheme.textPrimary)

            Spacer()

            // Quantity controls
            HStack(spacing: 12) {
                // Minus button
                Button {
                    let current = bulkQuantities[procedure.id] ?? 0
                    if current > 0 {
                        bulkQuantities[procedure.id] = current - 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(quantity > 0 ? ProcedusTheme.primary : ProcedusTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(quantity == 0)

                // Quantity display
                Text("\(quantity)")
                    .font(.headline)
                    .frame(minWidth: 36)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(quantity > 0 ? ProcedusTheme.primary : ProcedusTheme.textSecondary)

                // Plus button
                Button {
                    let current = bulkQuantities[procedure.id] ?? 0
                    if current < 99 {
                        bulkQuantities[procedure.id] = current + 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(quantity < 99 ? ProcedusTheme.primary : ProcedusTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(quantity >= 99)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Outcome Section

    private var outcomeSection: some View {
        Section {
            HStack(spacing: 8) {
                OutcomeButton(outcome: .success, isSelected: selectedOutcome == .success) {
                    selectedOutcome = .success
                }
                OutcomeButton(outcome: .complication, isSelected: selectedOutcome == .complication) {
                    selectedOutcome = .complication
                }
                OutcomeButton(outcome: .death, isSelected: selectedOutcome == .death) {
                    selectedOutcome = .death
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Outcome")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    // MARK: - Complications Section
    
    private var complicationsSection: some View {
        Section {
            DisclosureGroup {
                ForEach(allComplications, id: \.id) { complication in
                    Toggle(isOn: complicationBinding(for: complication.id)) {
                        HStack {
                            Text(complication.title)
                                .font(.clinicalBody)
                                .foregroundStyle(ProcedusTheme.textPrimary)
                            if complication.isCustom {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundStyle(ProcedusTheme.accent)
                            }
                        }
                    }
                    .toggleStyle(ClinicalCheckboxToggleStyle())
                }
            } label: {
                HStack {
                    Text("Complications")
                        .font(.clinicalBody)
                        .fontWeight(.medium)
                        .foregroundStyle(ProcedusTheme.textPrimary)
                    
                    Spacer()
                    
                    if !selectedComplications.isEmpty {
                        Text("\(selectedComplications.count)")
                            .font(.clinicalFootnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(ProcedusTheme.warning)
                            .clipShape(Capsule())
                    } else {
                        Text("None")
                            .font(.clinicalCaption)
                            .foregroundStyle(ProcedusTheme.textTertiary)
                    }
                }
            }
        } header: {
            Text("Complications")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    private func complicationBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selectedComplications.contains(id) },
            set: { isSelected in
                if isSelected { selectedComplications.insert(id) }
                else { selectedComplications.remove(id) }
            }
        )
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Do not include any Protected Health Information (PHI)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.bottom, 4)

                TextEditor(text: $caseNotes)
                    .frame(minHeight: 80)
                    .font(.clinicalBody)
                    .scrollContentBackground(.hidden)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                    .onChange(of: caseNotes) { _, newValue in
                        let result = PHITextValidator.shared.validate(newValue)
                        notesPHIWarning = result.warningMessage
                    }

                // PHI Warning Banner
                if let warning = notesPHIWarning {
                    PHIWarningBanner(message: warning)
                }
            }
        } header: {
            Text("Notes (Optional)")
                .font(.clinicalFootnote)
                .foregroundStyle(ProcedusTheme.textSecondary)
        } footer: {
            Text("Add personal notes about techniques, lessons learned, or case details. No patient identifiers.")
                .font(.caption2)
                .foregroundStyle(ProcedusTheme.textTertiary)
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }

    // MARK: - Delete Section
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "trash")
                    Text("Delete Case")
                        .font(.clinicalBody)
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    // MARK: - Actions
    
    private func saveCase() {
        // FACILITY IS REQUIRED
        guard let facilityId = selectedFacilityId else { return }

        // Attending is optional for cardiac imaging (noninvasive) procedures
        let attendingId = selectedAttendingId

        // In individual mode, use a stored UUID or generate one
        // In institutional mode, use the selected fellow ID (from identity picker)
        // Otherwise use the current user ID or fallback to individual mode UUID
        let userId: UUID
        if !appState.isIndividualMode {
            // Institutional mode - use selected fellow identity
            if let selectedFellowId = appState.selectedFellowId {
                userId = selectedFellowId
            } else if let currentUserId = appState.currentUser?.id {
                userId = currentUserId
            } else {
                // Fallback - shouldn't happen in institutional mode
                userId = getOrCreateIndividualUserId()
            }
        } else {
            // Individual mode
            userId = getOrCreateIndividualUserId()
        }

        var savedCaseId: UUID?

        // Convert device selections to storage format
        var deviceStorage: [String: [String]] = [:]
        for (procedureId, devices) in selectedDevices {
            if !devices.isEmpty && selectedProcedureTagIds.contains(procedureId) {
                deviceStorage[procedureId] = Array(devices)
            }
        }

        // Convert custom detail selections to storage format
        var customDetailStorage: [String: [String]] = [:]
        for (detailId, options) in customDetailSelections {
            if !options.isEmpty {
                customDetailStorage[detailId] = Array(options)
            }
        }

        if let existingCase = existingCase {
            existingCase.supervisorId = attendingId
            existingCase.hospitalId = facilityId
            existingCase.weekBucket = selectedWeekBucket
            existingCase.procedureTagIds = Array(selectedProcedureTagIds)
            existingCase.procedureDevices = deviceStorage
            existingCase.customDetailSelections = customDetailStorage
            existingCase.accessSiteIds = Array(selectedAccessSites)
            existingCase.outcomeRaw = selectedOutcome.rawValue
            existingCase.complicationIds = Array(selectedComplications)
            existingCase.notes = caseNotes.isEmpty ? nil : caseNotes
            existingCase.updatedAt = Date()

            // Save case type and operator position (cardiology-specific)
            existingCase.caseType = shouldShowCaseTypeToggle ? selectedCaseType : nil
            existingCase.operatorPosition = shouldShowOperatorPosition ? selectedOperatorPosition : nil

            // Update attestation status if changed to/from cardiac imaging only or noninvasive
            if isCardiacImagingOnly || isSimplifiedNoninvasiveForm {
                existingCase.attestationStatusRaw = AttestationStatus.notRequired.rawValue
            }
        } else {
            let now = Date()
            var caseIndex = 0

            // Check if using bulk entry mode
            if isSimplifiedNoninvasiveForm && noninvasiveEntryMode == .bulkEntry {
                // BULK ENTRY MODE: Create cases for each modality with quantities
                for (procedureId, quantity) in bulkQuantities where quantity > 0 {
                    for _ in 0..<quantity {
                        let newCase = CaseEntry(
                            fellowId: appState.isIndividualMode ? nil : userId,
                            ownerId: userId,
                            attendingId: nil,  // Noninvasive doesn't require attending
                            weekBucket: selectedWeekBucket,
                            facilityId: facilityId
                        )
                        newCase.procedureTagIds = [procedureId]
                        newCase.caseType = .noninvasive
                        newCase.outcomeRaw = CaseOutcome.success.rawValue
                        newCase.notes = caseNotes.isEmpty ? nil : caseNotes
                        newCase.isBulkEntry = true  // Mark as bulk entry
                        // Slightly offset timestamps for multiple cases
                        newCase.createdAt = now.addingTimeInterval(TimeInterval(caseIndex))
                        newCase.updatedAt = now
                        // Auto-attest noninvasive imaging
                        newCase.attestationStatusRaw = AttestationStatus.notRequired.rawValue

                        if caseIndex == 0 {
                            savedCaseId = newCase.id
                        }
                        caseIndex += 1
                        modelContext.insert(newCase)
                    }
                }
                bulkSavedCount = caseIndex
            } else {
                // STANDARD CASE ENTRY MODE
                let newCase = CaseEntry(
                    fellowId: appState.isIndividualMode ? nil : userId,
                    ownerId: userId,
                    attendingId: attendingId,
                    weekBucket: selectedWeekBucket,
                    facilityId: facilityId
                )
                newCase.procedureTagIds = Array(selectedProcedureTagIds)
                newCase.procedureDevices = deviceStorage
                newCase.customDetailSelections = customDetailStorage
                newCase.accessSiteIds = Array(selectedAccessSites)
                newCase.outcomeRaw = selectedOutcome.rawValue
                newCase.complicationIds = Array(selectedComplications)
                newCase.notes = caseNotes.isEmpty ? nil : caseNotes

                // Save case type and operator position (cardiology-specific)
                newCase.caseType = shouldShowCaseTypeToggle ? selectedCaseType : nil
                newCase.operatorPosition = shouldShowOperatorPosition ? selectedOperatorPosition : nil

                // Set attestation status based on mode and procedure type
                if appState.isIndividualMode || isCardiacImagingOnly || isSimplifiedNoninvasiveForm {
                    // Individual mode or cardiac imaging = no attestation required
                    newCase.attestationStatusRaw = AttestationStatus.notRequired.rawValue
                } else {
                    newCase.attestationStatusRaw = AttestationStatus.pending.rawValue

                    // Notify attending about new attestation request
                    if let attendingId = attendingId {
                        // Get procedure titles for notification
                        let procedureTitles = selectedProcedureTagIds.compactMap { tagId -> String? in
                            SpecialtyPackCatalog.findProcedure(by: tagId)?.title
                        }
                        NotificationManager.shared.notifyAttestationRequested(
                            toAttendingId: attendingId,
                            fellowName: fellowDisplayName,
                            caseId: newCase.id,
                            procedureCount: selectedProcedureTagIds.count,
                            procedureTitles: procedureTitles,
                            programId: nil
                        )
                    }
                }

                modelContext.insert(newCase)
                bulkSavedCount = 1
                savedCaseId = newCase.id
            }
        }

        try? modelContext.save()

        // Check if badges are enabled (default to true if not set)
        let badgesEnabled = UserDefaults.standard.object(forKey: "badgesEnabled") as? Bool ?? true

        // Check for newly earned badges if this is a new case (not editing) and badges are enabled
        if !isEditing && badgesEnabled, let caseId = savedCaseId {
            checkAndShowBadgeCelebration(userId: userId, savedCaseId: caseId)
        } else {
            // Show success alert for bulk entry mode, otherwise just dismiss
            if isSimplifiedNoninvasiveForm && noninvasiveEntryMode == .bulkEntry && bulkSavedCount > 0 {
                bulkShowingSuccess = true
            } else {
                dismiss()
            }
        }
    }

    private func checkAndShowBadgeCelebration(userId: UUID, savedCaseId: UUID) {
        // Get the saved case from allCases
        guard let savedCase = allCases.first(where: { $0.id == savedCaseId }) else {
            // Case not found, just dismiss
            if isSimplifiedNoninvasiveForm && noninvasiveEntryMode == .bulkEntry && bulkSavedCount > 0 {
                bulkShowingSuccess = true
            } else {
                dismiss()
            }
            return
        }

        // Get existing badges for this user
        let existingBadges = earnedBadgesQuery.filter { $0.fellowId == userId }

        // Check and award new badges
        let newBadges = BadgeService.shared.checkAndAwardBadges(
            for: userId,
            attestedCase: savedCase,
            allCases: allCases,
            existingBadges: existingBadges,
            modelContext: modelContext
        )

        // Create notifications for earned badges
        for earned in newBadges {
            if let badge = BadgeCatalog.badge(withId: earned.badgeId) {
                let notification = Notification(
                    userId: userId,
                    title: "Achievement Unlocked!",
                    message: "You earned the \"\(badge.title)\" badge!",
                    notificationType: NotificationType.badgeEarned.rawValue,
                    caseId: savedCaseId
                )
                modelContext.insert(notification)
            }
        }

        if !newBadges.isEmpty {
            try? modelContext.save()

            // Get the actual Badge objects to display
            earnedBadges = newBadges.compactMap { earned in
                BadgeCatalog.badge(withId: earned.badgeId)
            }

            if !earnedBadges.isEmpty {
                // Show badge celebration
                withAnimation {
                    showingBadgeCelebration = true
                }
                return
            }
        }

        // No badges earned, proceed with normal dismissal
        if isSimplifiedNoninvasiveForm && noninvasiveEntryMode == .bulkEntry && bulkSavedCount > 0 {
            bulkShowingSuccess = true
        } else {
            dismiss()
        }
    }
    
    /// Get or create a persistent user ID for individual mode
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
    
    private func deleteCase() {
        if let existingCase = existingCase {
            modelContext.delete(existingCase)
            try? modelContext.save()
        }
        dismiss()
    }
}

// MARK: - Helper Function

func generateWeekBuckets(count: Int) -> [String] {
    var buckets: [String] = []
    let calendar = Calendar(identifier: .iso8601)
    var currentDate = Date()
    
    for _ in 0..<count {
        let bucket = CaseEntry.makeWeekBucket(for: currentDate)
        buckets.append(bucket)
        currentDate = calendar.date(byAdding: .weekOfYear, value: -1, to: currentDate) ?? currentDate
    }
    
    return buckets
}

// MARK: - Preview

#Preview {
    IndividualAddEditCaseView()
        .environment(AppState())
        .modelContainer(for: [CaseEntry.self, Attending.self, TrainingFacility.self, CustomProcedure.self, CustomAccessSite.self, CustomComplication.self, CustomProcedureDetail.self], inMemory: true)
}
