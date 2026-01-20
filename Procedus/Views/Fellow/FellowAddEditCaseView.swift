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
    @Query private var users: [User]
    
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
    
    // Current fellow identity (from settings)
    @AppStorage("selectedFellowId") private var selectedFellowIdString = ""
    
    private var currentFellowId: UUID? {
        UUID(uuidString: selectedFellowIdString)
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
        let hasRequiredFields = selectedFacilityId != nil && !selectedProcedures.isEmpty
        let hasAttendingOrNoninvasive = selectedAttendingId != nil || isSimplifiedNoninvasiveForm || isCardiacImagingOnly
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

                    // Procedures Section (filtered by case type)
                    proceduresSection

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

                    // Delete Button (Edit mode only)
                    if isEditing {
                        deleteSection
                    }
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
                // Clear operator position when switching to noninvasive
                if newValue == .noninvasive {
                    selectedOperatorPosition = nil
                    // Auto-expand cardiac imaging categories for noninvasive cases
                    if let cardiacImagingPack = SpecialtyPackCatalog.pack(for: "cardiac-imaging") {
                        for category in cardiacImagingPack.categories {
                            procedureSectionsExpanded.insert("\(cardiacImagingPack.id)-\(category.id)")
                        }
                    }
                }
            }
        } header: {
            Text("Case Type")
                .font(.caption)
        } footer: {
            if selectedCaseType == .invasive {
                Text("Invasive procedures requiring sterile access (cath lab, EP lab)")
            } else {
                Text("Noninvasive imaging studies (echo, CT, MRI, nuclear)")
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
    
    // Combined complications from all packs (deduplicated)
    private var complicationsForSection: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for pack in currentPacks {
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
        guard let fellowId = currentFellowId else { return }

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

        if let existing = existingCase {
            // Update existing case
            existing.weekBucket = selectedWeek
            existing.attendingId = attendingId
            existing.facilityId = selectedFacilityId
            existing.procedureTagIds = Array(selectedProcedures)
            existing.procedureSubOptions = procedureSubOptions
            existing.procedureDevices = deviceStorage
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
            // Create new case with selected fellow ID
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
            newCase.accessSiteIds = Array(selectedAccessSites)
            newCase.complicationIds = Array(selectedComplications)
            newCase.outcome = selectedOutcome
            newCase.notes = caseNotes.isEmpty ? nil : caseNotes

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
                let notification = Notification(
                    userId: attendingId,  // Set to attending so only attending sees it
                    title: "New Case for Attestation",
                    message: "\(fellowLastName) submitted a case with \(selectedProcedures.count) procedure(s) for your attestation.",
                    notificationType: "attestationRequest",
                    caseId: newCase.id,
                    attendingId: attendingId
                )
                modelContext.insert(notification)
            }
        }

        // Save
        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Case saved successfully!")
            print("   - Case ID: \(savedCaseId?.uuidString ?? "unknown")")
            print("   - Fellow ID: \(fellowId)")
            print("   - Week: \(selectedWeek)")
            print("   - Procedures: \(selectedProcedures.count)")
            #endif
        } catch {
            print("❌ Error saving context: \(error)")
        }

        dismiss()
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
