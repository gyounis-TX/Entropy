import SwiftUI
import SwiftData

struct AddEditCaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    
    @Query private var programs: [Program]
    @Query private var attendings: [Attending]
    @Query private var facilities: [TrainingFacility]
    @Query private var customProcedures: [CustomProcedure]
    @Query private var customAccessSites: [CustomAccessSite]
    @Query private var customComplications: [CustomComplication]
    @Query private var customCategories: [CustomCategory]
    @Query(filter: #Predicate<CustomProcedureDetail> { !$0.isArchived })
    private var customProcedureDetails: [CustomProcedureDetail]
    @Query private var users: [User]
    @Query private var allCases: [CaseEntry]
    @Query private var earnedBadgesQuery: [BadgeEarned]
    
    // Get current program
    private var currentProgram: Program? {
        programs.first
    }
    
    // Specialties that use access sites and closure devices
    private static let accessSiteSpecialties: Set<String> = [
        "interventional-cardiology",
        "interventional-radiology",
        "vascular-surgery",
        "neurosurgery",
        "clinical-cardiac-ep",
        "advanced-heart-failure",
        "structural-heart",
        "pulmonary-critical-care"
    ]
    
    // Check if current specialty uses access sites
    private var showsAccessSites: Bool {
        guard let program = currentProgram else { return false }
        return program.specialtyPackIds.contains { Self.accessSiteSpecialties.contains($0) }
    }
    
    // Check if closure devices should be shown (same specialties as access sites)
    private var showsClosureDevices: Bool {
        showsAccessSites
    }
    
    // Get ALL specialty packs from admin selection
    private var currentPacks: [SpecialtyPack] {
        guard let program = currentProgram else { return [] }
        return program.specialtyPackIds.compactMap { SpecialtyPackCatalog.pack(for: $0) }
    }
    
    // Check if any packs are selected
    private var hasSpecialtyPacks: Bool {
        !currentPacks.isEmpty
    }
    
    // Combined categories from all packs (deduplicated by category name, with merged procedures by TITLE)
    private var allCategories: [MergedCategory] {
        var categoryMap: [String: MergedCategory] = [:]
        
        for pack in currentPacks {
            for packCategory in pack.categories {
                let categoryName = packCategory.category.rawValue
                
                if var existing = categoryMap[categoryName] {
                    // Merge procedures, deduplicating by procedure TITLE (not ID)
                    for procedure in packCategory.procedures {
                        if !existing.procedureTitles.contains(procedure.title) {
                            existing.procedureTitles.insert(procedure.title)
                            existing.procedures.append(procedure)
                        }
                    }
                    categoryMap[categoryName] = existing
                } else {
                    // Create new merged category
                    var procedureTitles = Set<String>()
                    var procedures: [ProcedureTag] = []
                    for procedure in packCategory.procedures {
                        procedureTitles.insert(procedure.title)
                        procedures.append(procedure)
                    }
                    categoryMap[categoryName] = MergedCategory(
                        category: packCategory.category,
                        procedures: procedures,
                        procedureTitles: procedureTitles
                    )
                }
            }
        }
        
        // Sort with Closure Devices last
        return categoryMap.values.sorted { cat1, cat2 in
            // Closure Devices always goes last
            if cat1.category == .closureDevices { return false }
            if cat2.category == .closureDevices { return true }
            // Otherwise sort alphabetically
            return cat1.category.rawValue < cat2.category.rawValue
        }
    }
    
    // Helper struct for merged categories
    private struct MergedCategory: Identifiable {
        let category: ProcedureCategory
        var procedures: [ProcedureTag]
        var procedureTitles: Set<String>
        
        var id: String { category.rawValue }
    }
    
    // Computed sorted/filtered versions
    private var sortedAttendingsActive: [Attending] {
        attendings.filter { !$0.isArchived }.sorted { $0.name < $1.name }
    }
    
    private var sortedFacilitiesActive: [TrainingFacility] {
        facilities.filter { !$0.isArchived }.sorted { $0.name < $1.name }
    }
    
    private var activeProcedures: [CustomProcedure] {
        customProcedures.filter { !$0.isArchived }
    }
    
    private var activeAccessSites: [CustomAccessSite] {
        customAccessSites.filter { !$0.isArchived }
    }
    
    private var activeComplications: [CustomComplication] {
        customComplications.filter { !$0.isArchived }
    }
    
    // Existing case for editing
    let existingCase: CaseEntry?
    
    // Form state
    @State private var selectedWeek: String
    @State private var selectedFacilityId: UUID?
    @State private var selectedAttendingId: UUID?
    @State private var selectedProcedures: Set<String> = []
    @State private var selectedAccessSites: Set<String> = []
    @State private var selectedComplications: Set<String> = []
    @State private var selectedOutcome: CaseOutcome = .success
    @State private var procedureSubOptions: [String: String] = [:]  // procedureId -> selected sub-option
    @State private var selectedDevices: [String: Set<String>] = [:]  // procedureId -> device names (for PE/DVT)
    @State private var customDetailSelections: [String: Set<String>] = [:]  // detailId.uuidString -> selected option strings
    @State private var caseNotes: String = ""

    // Case type and operator position (cardiology-specific)
    @State private var selectedCaseType: CaseType = .invasive
    @State private var selectedOperatorPosition: OperatorPosition? = nil

    // UI state
    @State private var weeks: [WeekOption] = []
    @State private var procedureSectionsExpanded: Set<String> = []
    @State private var complicationsExpanded = false
    @State private var showingDeleteConfirmation = false
    @State private var isSaving = false
    @State private var showingSubOptionSheet = false
    @State private var pendingProcedure: ProcedureTag? = nil
    @State private var customSubOption: String = ""

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
    
    // Current fellow identity (from appState - more reliable than @AppStorage)
    private var currentFellowId: UUID? {
        appState.selectedFellowId
    }
    
    private var isEditing: Bool {
        existingCase != nil
    }

    // Check if all selected procedures are from cardiac imaging pack (noninvasive)
    private var isCardiacImagingOnly: Bool {
        guard !selectedProcedures.isEmpty else { return false }
        return selectedProcedures.allSatisfy { tagId in
            tagId.hasPrefix("ci-")  // All cardiac imaging procedures start with "ci-"
        }
    }

    // MARK: - Cardiology-Specific Logic

    /// Whether the program is a cardiology fellowship
    private var isCardiologyProgram: Bool {
        currentProgram?.fellowshipSpecialty?.isCardiology == true
    }

    /// Whether the program has cardiac imaging enabled
    private var hasCardiacImaging: Bool {
        currentProgram?.specialtyPackIds.contains("cardiac-imaging") == true
    }

    /// Whether the program has other cardiology packs (IC or EP) enabled
    private var hasOtherCardiologyPacks: Bool {
        guard let packIds = currentProgram?.specialtyPackIds else { return false }
        return packIds.contains("interventional-cardiology") || packIds.contains("electrophysiology")
    }

    /// Whether to show the invasive/noninvasive toggle
    private var shouldShowCaseTypeToggle: Bool {
        hasCardiacImaging && hasOtherCardiologyPacks
    }

    /// Whether to show operator position (cardiology invasive only)
    private var shouldShowOperatorPosition: Bool {
        isCardiologyProgram && selectedCaseType == .invasive
    }

    /// Whether using simplified noninvasive form
    private var isSimplifiedNoninvasiveForm: Bool {
        // If only cardiac imaging is enabled (no IC or EP)
        if hasCardiacImaging && !hasOtherCardiologyPacks {
            return true
        }
        // If toggle is showing and noninvasive selected
        if shouldShowCaseTypeToggle && selectedCaseType == .noninvasive {
            return true
        }
        return false
    }

    /// Filter packs based on case type
    private var filteredCurrentPacks: [SpecialtyPack] {
        // If only cardiac imaging mode
        if hasCardiacImaging && !hasOtherCardiologyPacks {
            return currentPacks.filter { $0.id == "cardiac-imaging" }
        }

        // If toggle is showing, filter based on selection
        if shouldShowCaseTypeToggle {
            if selectedCaseType == .noninvasive {
                return currentPacks.filter { $0.id == "cardiac-imaging" }
            } else {
                return currentPacks.filter { $0.id != "cardiac-imaging" }
            }
        }

        return currentPacks
    }

    private var canSave: Bool {
        // Attending is required UNLESS using simplified noninvasive form or cardiac imaging only
        let hasAttendingOrNoninvasive = selectedAttendingId != nil || isSimplifiedNoninvasiveForm || isCardiacImagingOnly

        // For bulk entry mode, check if any quantities are > 0
        if isSimplifiedNoninvasiveForm && !isEditing && noninvasiveEntryMode == .bulkEntry {
            let hasBulkQuantities = bulkQuantities.values.reduce(0, +) > 0
            return selectedFacilityId != nil && hasBulkQuantities && hasSpecialtyPacks && currentFellowId != nil
        }

        // Standard case entry mode
        let hasRequiredFields = selectedFacilityId != nil && !selectedProcedures.isEmpty
        return hasRequiredFields && hasAttendingOrNoninvasive && hasSpecialtyPacks && currentFellowId != nil
    }
    
    init(weekBucket: String = "", existingCase: CaseEntry? = nil) {
        self.existingCase = existingCase
        let initialWeek = existingCase?.weekBucket ?? weekBucket
        _selectedWeek = State(initialValue: initialWeek.isEmpty ? String.weekBucket(from: Date()) : initialWeek)

        if let existing = existingCase {
            _selectedAttendingId = State(initialValue: existing.attendingId)
            _selectedFacilityId = State(initialValue: existing.facilityId)
            _selectedProcedures = State(initialValue: Set(existing.procedureTagIds))
            _procedureSubOptions = State(initialValue: existing.procedureSubOptions)
            _selectedAccessSites = State(initialValue: Set(existing.accessSiteIds))
            _selectedComplications = State(initialValue: Set(existing.complicationIds))
            _selectedOutcome = State(initialValue: existing.outcome)
            _caseNotes = State(initialValue: existing.notes ?? "")
            // Load existing device selections
            var devices: [String: Set<String>] = [:]
            for (procedureId, deviceList) in existing.procedureDevices {
                devices[procedureId] = Set(deviceList)
            }
            _selectedDevices = State(initialValue: devices)
            // Load existing custom detail selections
            var details: [String: Set<String>] = [:]
            for (detailId, optionList) in existing.customDetailSelections {
                details[detailId] = Set(optionList)
            }
            _customDetailSelections = State(initialValue: details)
            // Load case type and operator position
            _selectedCaseType = State(initialValue: existing.caseType ?? .invasive)
            _selectedOperatorPosition = State(initialValue: existing.operatorPosition)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Check if fellow is selected
                if currentFellowId == nil {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text("No Fellow Selected")
                                .font(.headline)
                            Text("Go to Settings and select your identity before logging cases.")
                                .font(.subheadline)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } else if !hasSpecialtyPacks {
                    // Check if specialty pack is configured
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text("No Specialty Pack Selected")
                                .font(.headline)
                            Text("An administrator must set up the program and select a specialty pack before cases can be logged.")
                                .font(.subheadline)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } else {
                    // Case type toggle (cardiology with both imaging and other packs)
                    if shouldShowCaseTypeToggle {
                        caseTypeToggleSection
                    }

                    // Procedure Timeframe Section
                    timeframeSection

                    // Entry mode toggle for noninvasive (Case Entry vs Bulk Entry)
                    if isSimplifiedNoninvasiveForm && !isEditing {
                        noninvasiveEntryModeSection
                    }

                    // Attending Section (hidden for simplified noninvasive form)
                    if !isSimplifiedNoninvasiveForm {
                        attendingSection
                    }

                    // Facility Section (always shown)
                    facilitySection

                    // Access Sites Section - only for specific specialties AND not simplified noninvasive
                    if showsAccessSites && !isSimplifiedNoninvasiveForm {
                        accessSitesSection
                    }

                    // Operator Position Section (cardiology invasive only)
                    if shouldShowOperatorPosition {
                        operatorPositionSection
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
                        proceduresSection
                    }

                    // Complications Section (hidden for simplified noninvasive form)
                    if !isSimplifiedNoninvasiveForm {
                        complicationsSection
                    }

                    // Outcome Section (hidden for simplified noninvasive form)
                    if !isSimplifiedNoninvasiveForm {
                        outcomeSection
                    }

                    // Attestation Status (Edit mode only, not for noninvasive)
                    if isEditing && !isSimplifiedNoninvasiveForm, let existing = existingCase {
                        attestationSection(for: existing)
                    }

                    // Notes Section
                    notesSection

                    // Media Section (Edit mode only - case must exist first)
                    if isEditing, let existing = existingCase, let fellowId = currentFellowId {
                        Section {
                            CaseMediaSection(
                                caseId: existing.id,
                                ownerId: fellowId,
                                ownerName: users.first { $0.id == fellowId }?.displayName ?? "Fellow"
                            )
                        } header: {
                            Text("Attachments")
                                .font(.caption)
                        } footer: {
                            Text("Add images or videos. PHI will be detected and must be redacted.")
                                .font(.caption2)
                        }
                    }

                    // Delete Button (Edit mode only)
                    if isEditing {
                        deleteSection
                    }

                    #if DEBUG
                    // Debug section showing save requirements
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DEBUG - Save Requirements:")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text("• Fellow ID: \(currentFellowId != nil ? "✅" : "❌ MISSING")")
                                .font(.caption2)
                            Text("• Facility: \(selectedFacilityId != nil ? "✅" : "❌ MISSING")")
                                .font(.caption2)
                            Text("• Procedures: \(selectedProcedures.isEmpty ? "❌ NONE SELECTED" : "✅ \(selectedProcedures.count)")")
                                .font(.caption2)
                            Text("• Attending: \(selectedAttendingId != nil ? "✅" : (isCardiacImagingOnly || isSimplifiedNoninvasiveForm ? "✅ (not required)" : "❌ MISSING"))")
                                .font(.caption2)
                            Text("• Specialty Packs: \(hasSpecialtyPacks ? "✅" : "❌ MISSING")")
                                .font(.caption2)
                            Text("• canSave: \(canSave ? "✅ YES" : "❌ NO")")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(canSave ? .green : .red)

                            Divider().padding(.vertical, 4)

                            Text("DEBUG - Noninvasive Entry:")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text("• hasCardiacImaging: \(hasCardiacImaging ? "✅" : "❌")")
                                .font(.caption2)
                            Text("• hasOtherCardiologyPacks: \(hasOtherCardiologyPacks ? "✅" : "❌")")
                                .font(.caption2)
                            Text("• shouldShowCaseTypeToggle: \(shouldShowCaseTypeToggle ? "✅" : "❌")")
                                .font(.caption2)
                            Text("• selectedCaseType: \(selectedCaseType.rawValue)")
                                .font(.caption2)
                            Text("• isSimplifiedNoninvasiveForm: \(isSimplifiedNoninvasiveForm ? "✅" : "❌")")
                                .font(.caption2)
                            Text("• noninvasiveEntryMode: \(noninvasiveEntryMode.rawValue)")
                                .font(.caption2)
                            Text("• ENTRY MODE TOGGLE VISIBLE: \(isSimplifiedNoninvasiveForm && !isEditing ? "✅ YES" : "❌ NO")")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(isSimplifiedNoninvasiveForm && !isEditing ? .green : .red)
                            Text("• Bulk Quantities Total: \(bulkQuantities.values.reduce(0, +))")
                                .font(.caption2)
                        }
                        .foregroundColor(.orange)
                    } header: {
                        Text("Debug Info")
                    }
                    #endif
                }
            }
            .navigationTitle(isEditing ? "Edit Case" : "New Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.subheadline)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCase()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .disabled(!canSave || isSaving)
                }
            }
            .onAppear {
                weeks = generateWeekOptions()
                // All categories start collapsed

                // Pre-populate default facility for new cases
                if !isEditing && selectedFacilityId == nil {
                    if let defaultFacility = appState.defaultFacilityId {
                        selectedFacilityId = defaultFacility
                    }
                }
            }
            .alert("Delete Case", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteCase()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this case? This action cannot be undone.")
            }
            .sheet(isPresented: $showingSubOptionSheet) {
                if let procedure = pendingProcedure {
                    SubOptionSelectionSheet(
                        procedure: procedure,
                        customSubOption: $customSubOption,
                        onSelect: { option in
                            selectSubOption(option, for: procedure)
                        },
                        onCancel: {
                            showingSubOptionSheet = false
                            pendingProcedure = nil
                        }
                    )
                }
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
        }
    }
    
    // MARK: - Timeframe Section

    private var timeframeSection: some View {
        Section {
            Picker("Procedure Timeframe", selection: $selectedWeek) {
                ForEach(weeks) { week in
                    Text(week.label)
                        .font(.subheadline)
                        .tag(week.bucket)
                }
            }
            .font(.subheadline)
        } header: {
            Text("Timeframe")
                .font(.caption)
        }
    }

    // MARK: - Case Type Toggle Section (Cardiology with both imaging and other packs)

    private var caseTypeToggleSection: some View {
        Section {
            Picker("Case Type", selection: $selectedCaseType) {
                ForEach(CaseType.allCases) { caseType in
                    Text(caseType.rawValue).tag(caseType)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedCaseType) { _, newValue in
                // Clear selected procedures when case type changes
                selectedProcedures.removeAll()
                selectedDevices.removeAll()
                procedureSubOptions.removeAll()
                bulkQuantities.removeAll()
                // Clear operator position when switching to noninvasive
                if newValue == .noninvasive {
                    selectedOperatorPosition = nil
                    // Default to case entry mode
                    noninvasiveEntryMode = .caseEntry
                }
            }
        } header: {
            Text("Case Type")
                .font(.caption)
        } footer: {
            if selectedCaseType == .invasive {
                Text("Invasive procedures requiring sterile access (cath lab, EP lab)")
            } else {
                Text("Noninvasive imaging studies (echo, CT, MRI, nuclear). Bulk entry available below.")
                    .foregroundColor(.blue)
            }
        }
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
                                .foregroundColor(selectedOperatorPosition == position ? Color(red: 0.05, green: 0.35, blue: 0.65) : Color(UIColor.tertiaryLabel))
                                .font(.title3)
                            Text(position.rawValue)
                                .font(.subheadline)
                                .foregroundColor(Color(UIColor.label))
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        } header: {
            Text("Operator Position")
                .font(.caption)
        } footer: {
            Text("Your role during the procedure")
        }
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
            .onChange(of: noninvasiveEntryMode) { _, newValue in
                // Clear selections when switching modes
                selectedProcedures.removeAll()
                bulkQuantities.removeAll()
            }
        } header: {
            Text("Entry Mode")
                .font(.caption)
        } footer: {
            if noninvasiveEntryMode == .caseEntry {
                Text("Log a single imaging study with detailed selection.")
            } else {
                Text("Quickly log multiple studies by quantity per modality.")
            }
        }
    }

    // MARK: - Noninvasive Case Entry (Radio Buttons - Single Selection)

    private var noninvasiveCaseEntrySection: some View {
        Section {
            // Get cardiac imaging procedures from the pack
            let imagingPack = filteredCurrentPacks.first { $0.id == "cardiac-imaging" }
            if let pack = imagingPack {
                ForEach(pack.categories, id: \.id) { packCategory in
                    DisclosureGroup(
                        isExpanded: bindingForExpansion(key: "noninv-\(packCategory.id)")
                    ) {
                        ForEach(packCategory.procedures) { procedure in
                            noninvasiveRadioRow(procedure: procedure)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(packCategory.category.rawValue)
                                .font(.subheadline)
                                .foregroundColor(Color(UIColor.label))
                            CategoryBubble(category: packCategory.category, size: 20)
                        }
                    }
                }
            } else {
                Text("No imaging procedures available")
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
        } header: {
            Text("Select Imaging Study")
                .font(.caption)
        } footer: {
            if selectedProcedures.isEmpty {
                Text("Select one imaging study to log.")
            } else {
                Text("One study selected. Tap Save to log this case.")
            }
        }
    }

    private func noninvasiveRadioRow(procedure: ProcedureTag) -> some View {
        let isSelected = selectedProcedures.contains(procedure.id)
        return Button {
            // Radio button behavior: select this, deselect others
            selectedProcedures.removeAll()
            selectedProcedures.insert(procedure.id)
        } label: {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? Color(red: 0.05, green: 0.35, blue: 0.65) : Color(UIColor.tertiaryLabel))
                    .font(.system(size: 20))

                Text(procedure.title)
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.label))

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bulk Quantity Section (Counters per Modality)

    /// Get all imaging procedures from the cardiac imaging pack
    private var imagingProcedures: [ProcedureTag] {
        guard let pack = filteredCurrentPacks.first(where: { $0.id == "cardiac-imaging" }) else {
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
                .font(.caption)
        } footer: {
            let totalStudies = bulkQuantities.values.reduce(0, +)
            if totalStudies == 0 {
                Text("Use +/- to set the number of studies for each modality.")
            } else {
                Text("Total: \(totalStudies) stud\(totalStudies == 1 ? "y" : "ies") to log.")
                    .foregroundColor(.blue)
            }
        }
    }

    private func bulkQuantityRow(for procedure: ProcedureTag) -> some View {
        let quantity = bulkQuantities[procedure.id] ?? 0

        return HStack {
            // Procedure name
            Text(procedure.title)
                .font(.subheadline)
                .foregroundColor(Color(UIColor.label))

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
                        .foregroundColor(quantity > 0 ? Color(red: 0.05, green: 0.35, blue: 0.65) : Color(UIColor.tertiaryLabel))
                }
                .buttonStyle(.plain)
                .disabled(quantity == 0)

                // Quantity display
                Text("\(quantity)")
                    .font(.headline)
                    .frame(minWidth: 36)
                    .multilineTextAlignment(.center)
                    .foregroundColor(quantity > 0 ? Color(red: 0.05, green: 0.35, blue: 0.65) : Color(UIColor.secondaryLabel))

                // Plus button
                Button {
                    let current = bulkQuantities[procedure.id] ?? 0
                    if current < 99 {
                        bulkQuantities[procedure.id] = current + 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(quantity < 99 ? Color(red: 0.05, green: 0.35, blue: 0.65) : Color(UIColor.tertiaryLabel))
                }
                .buttonStyle(.plain)
                .disabled(quantity >= 99)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Attending Section
    
    private var attendingSection: some View {
        Section {
            if sortedAttendingsActive.isEmpty {
                Text("No attendings added yet. Contact your program administrator.")
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .italic()
            } else {
                Picker("Attending", selection: $selectedAttendingId) {
                    Text("Select Attending")
                        .font(.subheadline)
                        .tag(nil as UUID?)
                    ForEach(sortedAttendingsActive) { attending in
                        Text(attending.name)
                            .font(.subheadline)
                            .tag(attending.id as UUID?)
                    }
                }
                .font(.subheadline)
            }
        } header: {
            Text("Attending")
                .font(.caption)
        }
    }
    
    // MARK: - Facility Section
    
    private var facilitySection: some View {
        Section {
            if sortedFacilitiesActive.isEmpty {
                Text("No facilities added yet. Contact your program administrator.")
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .italic()
            } else {
                Picker("Facility", selection: $selectedFacilityId) {
                    Text("Select Facility")
                        .font(.subheadline)
                        .tag(nil as UUID?)
                    ForEach(sortedFacilitiesActive) { facility in
                        Text(facility.shortName ?? facility.name)
                            .font(.subheadline)
                            .tag(facility.id as UUID?)
                    }
                }
                .font(.subheadline)
            }
        } header: {
            Text("Facility")
                .font(.caption)
        }
    }
    
    // MARK: - Procedures Section
    
    // Admin custom categories that should be visible to fellows (filtered by program)
    private var adminCustomCategories: [CustomCategory] {
        let programId = currentProgram?.id
        return customCategories.filter { $0.programId == programId }.sorted { $0.name < $1.name }
    }
    
    // Admin custom procedures (visible to all fellows in the program) - those without a creatorId are global/admin
    private var adminCustomProcedures: [CustomProcedure] {
        let programId = currentProgram?.id
        return customProcedures.filter {
            $0.creatorId == nil &&
            !$0.isArchived &&
            $0.programId == programId
        }
    }

    // Fellow's own custom procedures
    private var fellowOwnProcedures: [CustomProcedure] {
        guard let fellowId = currentFellowId else { return [] }
        return customProcedures.filter {
            $0.creatorId == fellowId &&
            !$0.isArchived
        }
    }
    
    // Build procedures section for each specialty pack
    @ViewBuilder
    private var proceduresSection: some View {
        packProceduresSection
        customCategoriesSection
    }

    @ViewBuilder
    private var packProceduresSection: some View {
        // Use filteredCurrentPacks based on case type (invasive/noninvasive)
        ForEach(filteredCurrentPacks, id: \.id) { pack in
            Section {
                packCategoriesList(for: pack)
            } header: {
                Text(pack.name)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
    }

    @ViewBuilder
    private func packCategoriesList(for pack: SpecialtyPack) -> some View {
        ForEach(pack.categories, id: \.id) { packCategory in
            if packCategory.category == .closureDevices && !showsClosureDevices {
                EmptyView()
            } else {
                packCategoryDisclosure(pack: pack, packCategory: packCategory)
            }
        }
    }

    private func packCategoryDisclosure(pack: SpecialtyPack, packCategory: PackCategory) -> some View {
        let categoryKey = "\(pack.id)-\(packCategory.id)"
        return DisclosureGroup(
            isExpanded: bindingForExpansion(key: categoryKey)
        ) {
            packCategoryContent(packCategory: packCategory)
        } label: {
            HStack(spacing: 8) {
                Text(packCategory.category.rawValue)
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.label))
                CategoryBubble(category: packCategory.category, size: 20)
            }
        }
    }

    @ViewBuilder
    private func packCategoryContent(packCategory: PackCategory) -> some View {
        ForEach(packCategory.procedures) { procedure in
            VStack(alignment: .leading, spacing: 4) {
                if procedure.hasSubOptions {
                    procedureRowWithSubOptions(procedure, category: packCategory.category)
                } else {
                    procedureRow(
                        id: procedure.id,
                        title: procedure.title,
                        category: packCategory.category
                    )
                }

                // Show device selection if this is a PE/DVT procedure AND it's selected
                if ThrombectomyDevice.isEligible(procedureId: procedure.id) && selectedProcedures.contains(procedure.id) {
                    deviceSelectionView(for: procedure.id)
                }

                // Show custom procedure details if applicable AND procedure is selected
                if selectedProcedures.contains(procedure.id) && !applicableCustomDetails(for: procedure.id).isEmpty {
                    customDetailSelectionView(for: procedure.id)
                }
            }
        }

        // Admin custom procedures for this category
        let adminForCategory = adminCustomProcedures.filter { $0.categoryRaw == packCategory.category.rawValue }
        ForEach(adminForCategory) { custom in
            procedureRow(
                id: custom.tagId,
                title: custom.title,
                category: packCategory.category,
                isCustom: true,
                customLabel: "Program"
            )
        }

        // Fellow's own custom procedures for this category
        let fellowForCategory = fellowOwnProcedures.filter { $0.categoryRaw == packCategory.category.rawValue }
        ForEach(fellowForCategory) { custom in
            procedureRow(
                id: custom.tagId,
                title: custom.title,
                category: packCategory.category,
                isCustom: true,
                customLabel: "My Custom"
            )
        }
    }

    // MARK: - Device Selection View (for PE/DVT procedures)

    @ViewBuilder
    private func deviceSelectionView(for procedureId: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Devices Used:")
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
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
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(UIColor.tertiarySystemGroupedBackground).opacity(0.5))
        .cornerRadius(8)
        .padding(.leading, 20)
    }

    private func deviceCheckbox(device: ThrombectomyDevice, procedureId: String) -> some View {
        let isSelected = selectedDevices[procedureId]?.contains(device.rawValue) ?? false
        return Button {
            toggleDevice(device: device, for: procedureId)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? Color(red: 0.05, green: 0.35, blue: 0.65) : Color(UIColor.tertiaryLabel))
                Text(device.rawValue)
                    .font(.caption)
                    .foregroundColor(Color(UIColor.label))
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
                            .font(.caption)
                            .foregroundColor(Color(UIColor.secondaryLabel))

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
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color(UIColor.tertiarySystemGroupedBackground).opacity(0.5))
            .cornerRadius(8)
            .padding(.leading, 20)
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
                    .foregroundColor(isSelected ? Color(red: 0.4, green: 0.6, blue: 0.9) : Color(UIColor.tertiaryLabel))
                Text(option)
                    .font(.caption)
                    .foregroundColor(Color(UIColor.label))
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

    @ViewBuilder
    private var customCategoriesSection: some View {
        if !adminCustomCategories.isEmpty {
            Section {
                ForEach(adminCustomCategories) { category in
                    customCategoryDisclosure(category: category)
                }
            } header: {
                Text("Custom Categories")
                    .font(.caption)
            }
        }
    }

    private func customCategoryDisclosure(category: CustomCategory) -> some View {
        let categoryIdPrefix = "custom:\(category.id.uuidString)"
        return DisclosureGroup(
            isExpanded: bindingForExpansion(key: categoryIdPrefix)
        ) {
            customCategoryContent(category: category, categoryIdPrefix: categoryIdPrefix)
        } label: {
            HStack(spacing: 8) {
                Text(category.name)
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.label))
                Text(category.letter)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Color(hex: category.colorHex) ?? .gray)
                    .clipShape(Circle())
            }
        }
    }

    @ViewBuilder
    private func customCategoryContent(category: CustomCategory, categoryIdPrefix: String) -> some View {
        let procsInCategory = adminCustomProcedures.filter { $0.customCategoryId == category.id }
        if procsInCategory.isEmpty {
            Text("No procedures in this category")
                .font(.caption)
                .foregroundColor(Color(UIColor.tertiaryLabel))
                .italic()
        } else {
            ForEach(procsInCategory) { proc in
                customCategoryProcedureRow(
                    id: proc.tagId,
                    title: proc.title,
                    category: category,
                    customLabel: "Program"
                )
            }
        }

        let fellowProcs = fellowOwnProcedures.filter { $0.customCategoryId == category.id }
        ForEach(fellowProcs) { proc in
            customCategoryProcedureRow(
                id: proc.tagId,
                title: proc.title,
                category: category,
                customLabel: "My Custom"
            )
        }
    }

    private func bindingForExpansion(key: String) -> Binding<Bool> {
        Binding(
            get: { procedureSectionsExpanded.contains(key) },
            set: { expanded in
                if expanded {
                    procedureSectionsExpanded.insert(key)
                } else {
                    procedureSectionsExpanded.remove(key)
                }
            }
        )
    }
    
    private func customCategoryProcedureRow(id: String, title: String, category: CustomCategory, customLabel: String = "Custom") -> some View {
        Button {
            toggleProcedure(id)
        } label: {
            HStack {
                Image(systemName: selectedProcedures.contains(id) ? "checkmark.square.fill" : "square")
                    .foregroundColor(selectedProcedures.contains(id) ? Color(red: 0.05, green: 0.35, blue: 0.65) : Color(UIColor.tertiaryLabel))
                    .font(.system(size: 20))
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.label))
                
                Text("(\(customLabel))")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
    
    private func procedureRow(id: String, title: String, category: ProcedureCategory, isCustom: Bool = false, customLabel: String = "Custom") -> some View {
        Button {
            toggleProcedure(id)
        } label: {
            HStack {
                Image(systemName: selectedProcedures.contains(id) ? "checkmark.square.fill" : "square")
                    .foregroundColor(selectedProcedures.contains(id) ? Color(red: 0.05, green: 0.35, blue: 0.65) : Color(UIColor.tertiaryLabel))
                    .font(.system(size: 20))
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.label))
                
                if isCustom {
                    Text("(\(customLabel))")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
    
    private func procedureRowWithSubOptions(_ procedure: ProcedureTag, category: ProcedureCategory) -> some View {
        let isSelected = selectedProcedures.contains(procedure.id)
        let selectedSubOption = procedureSubOptions[procedure.id]
        
        return Button {
            if procedure.hasSubOptions {
                if isSelected {
                    // Deselect
                    selectedProcedures.remove(procedure.id)
                    procedureSubOptions.removeValue(forKey: procedure.id)
                } else {
                    // Show sub-option picker
                    pendingProcedure = procedure
                    customSubOption = ""
                    showingSubOptionSheet = true
                }
            } else {
                toggleProcedure(procedure.id)
            }
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? Color(red: 0.05, green: 0.35, blue: 0.65) : Color(UIColor.tertiaryLabel))
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(procedure.title)
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.label))
                    
                    if let subOption = selectedSubOption {
                        Text("Site: \(subOption)")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.05, green: 0.35, blue: 0.65))
                    } else if procedure.hasSubOptions {
                        Text("Tap to select site")
                            .font(.caption)
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                }
                
                Spacer()
                
                if procedure.hasSubOptions {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func toggleProcedure(_ id: String) {
        if selectedProcedures.contains(id) {
            selectedProcedures.remove(id)
        } else {
            selectedProcedures.insert(id)
        }
    }
    
    private func selectSubOption(_ option: String, for procedure: ProcedureTag) {
        selectedProcedures.insert(procedure.id)
        procedureSubOptions[procedure.id] = option
        showingSubOptionSheet = false
        pendingProcedure = nil
        customSubOption = ""
    }
    
    // MARK: - Access Sites Section (2x2 Grid)
    
    private var accessSitesForSection: [(id: String, title: String)] {
        var sites: [(id: String, title: String)] = []
        // Combine access sites from all packs
        var seen = Set<String>()
        for pack in currentPacks {
            for site in pack.defaultAccessSites {
                if !seen.contains(site.rawValue) {
                    seen.insert(site.rawValue)
                    sites.append((id: site.rawValue, title: site.rawValue))
                }
            }
        }
        // Add custom access sites
        sites.append(contentsOf: activeAccessSites.map { (id: "custom:\($0.id.uuidString)", title: $0.title) })
        return sites
    }
    
    private var accessSitesSection: some View {
        Section {
            // Create 2-column grid with rows of 2
            let sites = accessSitesForSection
            if sites.isEmpty {
                Text("No access sites available")
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .italic()
            } else {
                ForEach(0..<((sites.count + 1) / 2), id: \.self) { rowIndex in
                    HStack(spacing: 16) {
                        let firstIndex = rowIndex * 2
                        if firstIndex < sites.count {
                            accessSiteCheckbox(id: sites[firstIndex].id, title: sites[firstIndex].title)
                        }
                        
                        let secondIndex = firstIndex + 1
                        if secondIndex < sites.count {
                            accessSiteCheckbox(id: sites[secondIndex].id, title: sites[secondIndex].title)
                        } else {
                            Spacer()
                        }
                    }
                }
            }
        } header: {
            Text("Access Sites")
                .font(.caption)
        }
    }
    
    private func accessSiteCheckbox(id: String, title: String) -> some View {
        Button {
            if selectedAccessSites.contains(id) {
                selectedAccessSites.remove(id)
            } else {
                selectedAccessSites.insert(id)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedAccessSites.contains(id) ? "checkmark.square.fill" : "square")
                    .foregroundColor(selectedAccessSites.contains(id) ? Color(red: 0.05, green: 0.35, blue: 0.65) : Color(UIColor.tertiaryLabel))
                    .font(.system(size: 18))
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.label))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Complications Section (Collapsible Dropdown)

    // Complications filtered by case type - IC-specific for invasive
    private var complicationsForSection: [String] {
        var seen = Set<String>()
        var result: [String] = []

        // For invasive cardiology cases, only show IC-specific complications
        // For noninvasive, show cardiac imaging complications
        let relevantPacks: [SpecialtyPack]
        if selectedCaseType == .noninvasive || isSimplifiedNoninvasiveForm {
            // Cardiac imaging complications only
            relevantPacks = currentPacks.filter { $0.id == "cardiac-imaging" }
        } else {
            // Invasive: IC and EP complications only (not all packs)
            relevantPacks = currentPacks.filter { $0.id == "interventional-cardiology" || $0.id == "electrophysiology" }
        }

        for pack in relevantPacks {
            for complication in pack.defaultComplications {
                if !seen.contains(complication.rawValue) {
                    seen.insert(complication.rawValue)
                    result.append(complication.rawValue)
                }
            }
        }
        return result.sorted()
    }
    
    private var complicationsSection: some View {
        Section {
            DisclosureGroup(
                isExpanded: $complicationsExpanded
            ) {
                // Built-in complications from all packs
                ForEach(complicationsForSection, id: \.self) { complication in
                    complicationCheckbox(id: complication, title: complication)
                }
                
                // Custom complications
                ForEach(activeComplications) { custom in
                    complicationCheckbox(id: "custom:\(custom.id.uuidString)", title: custom.title)
                }
            } label: {
                HStack {
                    Text("Complications")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.label))
                    
                    Spacer()
                    
                    if !selectedComplications.isEmpty {
                        Text("\(selectedComplications.count) selected")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.85, green: 0.25, blue: 0.25))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.85, green: 0.25, blue: 0.25).opacity(0.1))
                            .cornerRadius(8)
                    } else {
                        Text("None")
                            .font(.caption)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                }
            }
        } header: {
            Text("Complications")
                .font(.caption)
        } footer: {
            Text("Select any complications that occurred during this case")
                .font(.caption2)
        }
    }
    
    private func complicationCheckbox(id: String, title: String) -> some View {
        Button {
            if selectedComplications.contains(id) {
                selectedComplications.remove(id)
            } else {
                selectedComplications.insert(id)
            }
        } label: {
            HStack {
                Image(systemName: selectedComplications.contains(id) ? "checkmark.square.fill" : "square")
                    .foregroundColor(selectedComplications.contains(id) ? Color(red: 0.85, green: 0.25, blue: 0.25) : Color(UIColor.tertiaryLabel))
                    .font(.system(size: 20))
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.label))
                
                Spacer()
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Outcome Section
    
    private var outcomeSection: some View {
        Section {
            Picker("Outcome", selection: $selectedOutcome) {
                ForEach(CaseOutcome.allCases) { outcome in
                    Text(outcome.rawValue)
                        .font(.subheadline)
                        .tag(outcome)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Outcome")
                .font(.caption)
        }
    }
    
    // MARK: - Attestation Section
    
    private func attestationSection(for caseEntry: CaseEntry) -> some View {
        Section {
            HStack {
                AttestationStatusBadge(status: caseEntry.attestationStatus)
                
                Spacer()
                
                if caseEntry.attestationStatus == .attested {
                    Text("Verified")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
        } header: {
            Text("Attestation Status")
                .font(.caption)
        }
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
                    .font(.subheadline)
                    .scrollContentBackground(.hidden)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
            }
        } header: {
            Text("Notes (Optional)")
                .font(.caption)
        } footer: {
            Text("Add personal notes about techniques, lessons learned, or case details. No patient identifiers.")
                .font(.caption2)
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Delete Case")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveCase() {
        #if DEBUG
        print("📝 saveCase() called")
        print("   - currentFellowId: \(currentFellowId?.uuidString ?? "NIL")")
        print("   - appState.selectedFellowId: \(appState.selectedFellowId?.uuidString ?? "NIL")")
        #endif

        guard let fellowId = currentFellowId else {
            #if DEBUG
            print("❌ saveCase() returning early - no fellowId!")
            #endif
            return
        }

        // Cardiac imaging cases don't require an attending
        let attendingId = selectedAttendingId

        isSaving = true

        // Get fellow name for notification
        let fellowLastName = users.first { $0.id == fellowId }?.lastName ?? "Fellow"

        var savedCaseId: UUID?

        // Convert device selections to storage format
        var deviceStorage: [String: [String]] = [:]
        for (procedureId, devices) in selectedDevices {
            if !devices.isEmpty && selectedProcedures.contains(procedureId) {
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

        if let existing = existingCase {
            // Update existing case
            existing.weekBucket = selectedWeek
            existing.attendingId = attendingId
            existing.facilityId = selectedFacilityId
            existing.procedureTagIds = Array(selectedProcedures)
            existing.procedureSubOptions = procedureSubOptions
            existing.procedureDevices = deviceStorage
            existing.customDetailSelections = customDetailStorage
            existing.accessSiteIds = Array(selectedAccessSites)
            existing.complicationIds = Array(selectedComplications)
            existing.outcome = selectedOutcome
            existing.notes = caseNotes.isEmpty ? nil : caseNotes
            existing.updatedAt = Date()

            // Save case type and operator position (cardiology-specific)
            existing.caseType = shouldShowCaseTypeToggle ? selectedCaseType : nil
            existing.operatorPosition = shouldShowOperatorPosition ? selectedOperatorPosition : nil

            // Update attestation status for cardiac imaging or noninvasive
            if isCardiacImagingOnly || isSimplifiedNoninvasiveForm {
                existing.attestationStatus = .notRequired
            }
            savedCaseId = existing.id
        } else {
            let now = Date()
            var caseIndex = 0

            // Check if using new bulk entry mode
            if isSimplifiedNoninvasiveForm && !isEditing && noninvasiveEntryMode == .bulkEntry {
                // BULK ENTRY MODE: Create cases for each modality with quantities
                for (procedureId, quantity) in bulkQuantities where quantity > 0 {
                    for _ in 0..<quantity {
                        let newCase = CaseEntry(
                            fellowId: fellowId,
                            ownerId: fellowId,
                            attendingId: nil,  // Noninvasive doesn't require attending
                            weekBucket: selectedWeek,
                            programId: currentProgram?.id,
                            facilityId: selectedFacilityId
                        )
                        newCase.procedureTagIds = [procedureId]
                        newCase.caseType = .noninvasive
                        newCase.outcome = .success
                        newCase.notes = caseNotes.isEmpty ? nil : caseNotes
                        newCase.isBulkEntry = true  // Mark as bulk entry
                        // Slightly offset timestamps for multiple cases
                        newCase.createdAt = now.addingTimeInterval(TimeInterval(caseIndex))
                        newCase.updatedAt = now
                        // Auto-attest noninvasive imaging
                        newCase.attestationStatus = .notRequired

                        if caseIndex == 0 {
                            savedCaseId = newCase.id
                        }
                        caseIndex += 1

                        modelContext.insert(newCase)
                    }
                }
                bulkSavedCount = caseIndex
            } else {
                // STANDARD CASE ENTRY MODE (including noninvasive case entry)
                let newCase = CaseEntry(
                    fellowId: fellowId,
                    ownerId: fellowId,  // Also set ownerId to match fellowId
                    attendingId: attendingId,
                    weekBucket: selectedWeek,
                    programId: currentProgram?.id,
                    facilityId: selectedFacilityId
                )
                newCase.procedureTagIds = Array(selectedProcedures)
                newCase.procedureSubOptions = procedureSubOptions
                newCase.procedureDevices = deviceStorage
                newCase.customDetailSelections = customDetailStorage
                newCase.accessSiteIds = Array(selectedAccessSites)
                newCase.complicationIds = Array(selectedComplications)
                newCase.outcome = selectedOutcome
                newCase.notes = caseNotes.isEmpty ? nil : caseNotes
                newCase.createdAt = now
                newCase.updatedAt = now

                // Save case type and operator position (cardiology-specific)
                newCase.caseType = shouldShowCaseTypeToggle ? selectedCaseType : nil
                newCase.operatorPosition = shouldShowOperatorPosition ? selectedOperatorPosition : nil

                // Set attestation status based on procedure type
                if isCardiacImagingOnly || isSimplifiedNoninvasiveForm {
                    newCase.attestationStatus = .notRequired
                }

                savedCaseId = newCase.id
                modelContext.insert(newCase)

                // Only create notification for attending if not noninvasive
                if !isCardiacImagingOnly && !isSimplifiedNoninvasiveForm, let attendingId = attendingId {
                    // Get procedure titles for notification
                    let procedureTitles = selectedProcedures.compactMap { tagId -> String? in
                        SpecialtyPackCatalog.findProcedure(by: tagId)?.title
                    }
                    let procedureList = procedureTitles.prefix(3).joined(separator: ", ")
                    let suffix = procedureTitles.count > 3 ? " + \(procedureTitles.count - 3) more" : ""
                    let message = procedureTitles.isEmpty ?
                        "\(fellowLastName) submitted a case of \(selectedProcedures.count) procedure(s) for your attestation." :
                        "\(fellowLastName) submitted a case of \(procedureList)\(suffix) for your attestation."

                    let notification = Notification(
                        userId: attendingId,  // Set to attending so only attending sees it
                        title: "New Case for Attestation",
                        message: message,
                        notificationType: NotificationType.attestationRequested.rawValue,
                        caseId: newCase.id,
                        attendingId: attendingId
                    )
                    modelContext.insert(notification)
                }

                bulkSavedCount = 1
            }
        }

        // Save
        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Case(s) saved successfully!")
            print("   - Case ID: \(savedCaseId?.uuidString ?? "unknown")")
            print("   - Fellow ID: \(fellowId)")
            print("   - Week: \(selectedWeek)")
            print("   - Procedures: \(selectedProcedures.count)")
            print("   - Bulk count: \(bulkSavedCount)")
            #endif
        } catch {
            print("❌ Error saving context: \(error)")
        }

        // Check if badges are enabled
        let badgesEnabled = UserDefaults.standard.bool(forKey: "badgesEnabled")

        // Check for newly earned badges if this is a new case (not editing) and badges are enabled
        if !isEditing && badgesEnabled, let caseId = savedCaseId {
            checkAndShowBadgeCelebration(fellowId: fellowId, savedCaseId: caseId)
        } else {
            // Show success alert for bulk entry mode, otherwise just dismiss
            if isSimplifiedNoninvasiveForm && !isEditing && noninvasiveEntryMode == .bulkEntry && bulkSavedCount > 0 {
                bulkShowingSuccess = true
            } else {
                dismiss()
            }
        }
    }

    private func checkAndShowBadgeCelebration(fellowId: UUID, savedCaseId: UUID) {
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

        // Get existing badges for this fellow
        let existingBadges = earnedBadgesQuery.filter { $0.fellowId == fellowId }

        // Check and award new badges
        let newBadges = BadgeService.shared.checkAndAwardBadges(
            for: fellowId,
            attestedCase: savedCase,
            allCases: allCases,
            existingBadges: existingBadges,
            modelContext: modelContext
        )

        // Create notifications for earned badges
        for earned in newBadges {
            if let badge = BadgeCatalog.badge(withId: earned.badgeId) {
                let notification = Notification(
                    userId: fellowId,
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
    
    private func deleteCase() {
        if let existing = existingCase {
            modelContext.delete(existing)
        }
        dismiss()
    }
}

// MARK: - Sub Option Selection Sheet

struct SubOptionSelectionSheet: View {
    let procedure: ProcedureTag
    @Binding var customSubOption: String
    let onSelect: (String) -> Void
    let onCancel: () -> Void
    
    @State private var showingCustomField = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let options = procedure.subOptions {
                        ForEach(options, id: \.self) { option in
                            Button {
                                onSelect(option)
                            } label: {
                                HStack {
                                    Text(option)
                                        .font(.subheadline)
                                        .foregroundColor(Color(UIColor.label))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(Color(UIColor.tertiaryLabel))
                                }
                            }
                        }
                    }
                    
                    if procedure.allowsCustomSubOption {
                        Button {
                            showingCustomField = true
                        } label: {
                            HStack {
                                Text("Other...")
                                    .font(.subheadline)
                                    .foregroundColor(Color(UIColor.label))
                                Spacer()
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                            }
                        }
                    }
                } header: {
                    Text("Select Site for \(procedure.title)")
                        .font(.caption)
                } footer: {
                    Text("Choose the anatomical site where this procedure was performed.")
                        .font(.caption2)
                }
                
                if showingCustomField {
                    Section {
                        TextField("Enter custom site", text: $customSubOption)
                            .font(.subheadline)
                        
                        Button {
                            if !customSubOption.isEmpty {
                                onSelect(customSubOption)
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Use Custom Site")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                            }
                        }
                        .disabled(customSubOption.isEmpty)
                    } header: {
                        Text("Custom Site")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Select Site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.subheadline)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    AddEditCaseView(weekBucket: String.weekBucket(from: Date()))
        .environment(AppState())
}
