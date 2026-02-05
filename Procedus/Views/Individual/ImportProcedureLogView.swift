// ImportProcedureLogView.swift
// Procedus - Unified
// Import existing procedure logs from Excel/CSV with mapping UI

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Import Procedure Log View (Main Entry Point)

struct ImportProcedureLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(filter: #Predicate<Attending> { !$0.isArchived }) private var attendings: [Attending]
    @Query(filter: #Predicate<TrainingFacility> { !$0.isArchived }) private var facilities: [TrainingFacility]
    @Query(filter: #Predicate<CustomProcedure> { !$0.isArchived }) private var customProcedures: [CustomProcedure]

    private var enabledPacks: [SpecialtyPack] {
        SpecialtyPackCatalog.allPacks.filter { appState.enabledSpecialtyPackIds.contains($0.id) }
    }
    
    @State private var importStep: ImportStep = .selectFile
    @State private var selectedFileURL: URL?
    @State private var headers: [String] = []
    @State private var dataRows: [[String]] = []
    @State private var columnMapping = ColumnMapping()
    @State private var importedCases: [ImportedCase] = []
    @State private var showingFilePicker = false
    @State private var errorMessage: String?
    @State private var isProcessing = false
    @State private var importResult: ImportResult?
    @State private var unmappedAttendingEntries: [MappedAttendingEntry] = []
    @State private var showDuplicateFileAlert = false
    @State private var attendingChecklistEntries: [AttendingChecklistEntry] = []
    @State private var showAttendingConfirmation = false
    @State private var showSimilarProceduresSheet = false
    @State private var similarProcedureMatches: [SimilarProcedureMatch] = []
    @State private var pendingProcedureMapping: PendingProcedureMapping?
    @State private var mappingConfirmation: MappingConfirmationData?

    // Role mapping state (Issue 4)
    @State private var unmappedRoleEntries: [MappedRoleEntry] = []

    // Facility mapping state (Issue 2)
    @State private var unmappedFacilityEntries: [MappedFacilityEntry] = []
    @State private var facilityMappingMode: FacilityMappingMode = .bulk
    @State private var bulkFacilityId: UUID? = nil
    @State private var attendingFacilityMap: [String: UUID] = [:]
    @State private var procedureFacilityMap: [String: UUID] = [:]
    @State private var caseFacilityMap: [Int: UUID] = [:]
    @State private var showingAddFacilitySheet = false

    // Merge detection state (Issue 5)
    @State private var mergeGroups: [MergeGroup] = []

    // Excel sheet selection state
    @State private var availableSheets: [String] = []
    @State private var selectedSheet: String?
    @State private var showingSheetPicker = false
    @State private var loadedFileData: Data?
    @State private var loadedFileIsXLSX = false

    // Batch multi-sheet import state
    @State private var sheetProcedureMappings: [SheetProcedureMapping] = []
    @State private var showingBatchSheetMapper = false

    // Per-sheet column mapping state
    @State private var sheetImportDataList: [SheetImportData] = []
    @State private var currentSheetIndex: Int = 0

    enum ImportStep {
        case selectFile
        case mapColumns
        case reviewCases
        case mapAttendings
        case mapRoles
        case mapFacilities
        case mapProcedures
        case mergeCases
        case confirm
        case complete
    }
    
    struct ImportResult {
        let totalRows: Int
        let importedCount: Int
        let skippedCount: Int
        let customProceduresCreated: Int
        let attendingsCreated: Int
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator
                importProgressView
                
                // Content based on step
                switch importStep {
                case .selectFile:
                    selectFileView
                case .mapColumns:
                    mapColumnsView
                case .reviewCases:
                    reviewCasesView
                case .mapAttendings:
                    mapAttendingsView
                case .mapRoles:
                    mapRolesView
                case .mapFacilities:
                    mapFacilitiesView
                case .mapProcedures:
                    mapProceduresView
                case .mergeCases:
                    mergeCasesView
                case .confirm:
                    confirmView
                case .complete:
                    completeView
                }
            }
            .overlay {
                if isProcessing {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .controlSize(.large)
                                Text("Processing file...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(24)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                }
            }
            .navigationTitle("Import Procedure Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if let prev = previousStep(from: importStep) {
                        Button {
                            importStep = prev
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                    } else if importStep != .complete {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if previousStep(from: importStep) != nil && importStep != .complete {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.commaSeparatedText, UTType(filenameExtension: "xlsx")!, UTType(filenameExtension: "xls")!],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("Import Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .alert("File Already Imported", isPresented: $showDuplicateFileAlert) {
                Button("Import Again") {
                    continueAfterDuplicateCheck()
                }
                Button("Cancel", role: .cancel) {
                    selectedFileURL = nil
                    headers = []
                    dataRows = []
                }
            } message: {
                Text("A file with the same name and row count has been previously imported. Re-importing may create duplicate cases. Do you want to continue?")
            }
            .sheet(item: $mappingConfirmation) { _ in
                mappingConfirmationSheetView
            }
            .sheet(isPresented: $showSimilarProceduresSheet) {
                similarProceduresSheetView
            }
            .sheet(isPresented: $showingSheetPicker, onDismiss: {
                // Defer parsing to the next run loop iteration so the sheet dismissal
                // animation completes and SwiftUI finishes its layout pass first.
                if selectedSheet != nil && loadedFileData != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        parseFileWithSelectedSheet()
                    }
                }
            }) {
                sheetPickerView
            }
            .sheet(isPresented: $showingBatchSheetMapper, onDismiss: {
                let hasSelected = sheetProcedureMappings.contains { $0.isSelected }
                if hasSelected && loadedFileData != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        parseBatchSheets()
                    }
                }
            }) {
                batchSheetMapperView
            }
        }
    }

    // MARK: - Sheet Picker View

    private var sheetPickerView: some View {
        NavigationStack {
            List {
                Section {
                    Text("This Excel file contains multiple sheets. Select the sheet containing your procedure log data.")
                        .font(.subheadline)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }

                Section("Available Sheets") {
                    ForEach(availableSheets, id: \.self) { sheet in
                        Button {
                            selectedSheet = sheet
                        } label: {
                            HStack {
                                Image(systemName: "tablecells")
                                    .foregroundStyle(ProcedusTheme.textSecondary)
                                Text(sheet)
                                    .foregroundStyle(ProcedusTheme.textPrimary)
                                Spacer()
                                if selectedSheet == sheet {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(ProcedusTheme.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Clear data so onDismiss doesn't trigger parsing
                        loadedFileData = nil
                        selectedFileURL = nil
                        availableSheets = []
                        selectedSheet = nil
                        showingSheetPicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        // Just dismiss - onDismiss will handle parsing
                        showingSheetPicker = false
                    }
                    .disabled(selectedSheet == nil)
                }
            }
        }
    }

    // MARK: - Batch Sheet Mapper View

    private var batchSheetMapperView: some View {
        NavigationStack {
            List {
                Section {
                    Text("This Excel file contains multiple sheets. Each sheet will be imported as a separate procedure type. Verify the procedure mapping for each sheet below.")
                        .font(.subheadline)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }

                Section("Sheets") {
                    ForEach($sheetProcedureMappings) { $mapping in
                        BatchSheetRow(
                            mapping: $mapping,
                            enabledPacks: enabledPacks,
                            customProcedures: customProcedures
                        )
                    }
                }

                Section {
                    let selectedCount = sheetProcedureMappings.filter(\.isSelected).count
                    let totalCount = sheetProcedureMappings.count
                    HStack {
                        Text("\(selectedCount) of \(totalCount) sheets selected")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.textSecondary)
                        Spacer()
                        Button(selectedCount == totalCount ? "Deselect All" : "Select All") {
                            let newValue = selectedCount < totalCount
                            for i in sheetProcedureMappings.indices {
                                sheetProcedureMappings[i].isSelected = newValue
                            }
                        }
                        .font(.caption)
                    }
                }
            }
            .navigationTitle("Map Sheets to Procedures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        loadedFileData = nil
                        selectedFileURL = nil
                        sheetProcedureMappings = []
                        showingBatchSheetMapper = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import Selected") {
                        showingBatchSheetMapper = false
                    }
                    .disabled(
                        !sheetProcedureMappings.contains(where: { $0.isSelected }) ||
                        sheetProcedureMappings.contains(where: { $0.isSelected && $0.mappedProcedure.status != .mapped })
                    )
                }
            }
        }
    }

    // MARK: - Navigation

    private func previousStep(from step: ImportStep) -> ImportStep? {
        switch step {
        case .selectFile, .complete:
            return nil
        case .mapColumns:
            return .selectFile
        case .reviewCases:
            return .mapColumns
        case .mapAttendings:
            return .reviewCases
        case .mapRoles:
            return attendingChecklistEntries.isEmpty ? .reviewCases : .mapAttendings
        case .mapFacilities:
            if !unmappedRoleEntries.isEmpty { return .mapRoles }
            if !attendingChecklistEntries.isEmpty { return .mapAttendings }
            return .reviewCases
        case .mapProcedures:
            return .mapFacilities
        case .mergeCases:
            let hasUnmappedProcs = importedCases.contains { $0.unmappedProcedureCount > 0 }
            return hasUnmappedProcs ? .mapProcedures : .mapFacilities
        case .confirm:
            if !mergeGroups.isEmpty { return .mergeCases }
            let hasUnmappedProcs = importedCases.contains { $0.unmappedProcedureCount > 0 }
            if hasUnmappedProcs { return .mapProcedures }
            return .mapFacilities
        }
    }

    // MARK: - Progress View

    private var importProgressView: some View {
        HStack(spacing: 3) {
            ForEach(0..<9) { index in
                Capsule()
                    .fill(importStep.rawValue >= index ? ProcedusTheme.primary : ProcedusTheme.textTertiary)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Step 1: Select File

    private var selectFileView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "doc.badge.arrow.up")
                    .font(.system(size: 64))
                    .foregroundStyle(ProcedusTheme.primary)
                    .padding(.top, 32)

                Text("Import Your Procedure Log")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Select an Excel or CSV file containing your existing procedure log data.")
                    .font(.subheadline)
                    .foregroundStyle(ProcedusTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Procedus Classic Migration Info
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "arrow.triangle.merge")
                            .foregroundStyle(ProcedusTheme.accent)
                        Text("Migrating from Procedus Classic?")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text("Your procedures will be automatically mapped to the new format. The system recognizes procedures from the original Procedus app and matches them to the updated procedure catalog.")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)

                    HStack(spacing: 16) {
                        Label("Auto-mapping", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(ProcedusTheme.success)
                        Label("Manual review", systemImage: "hand.point.up.fill")
                            .font(.caption2)
                            .foregroundStyle(ProcedusTheme.accent)
                    }
                }
                .padding()
                .background(ProcedusTheme.accent.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 32)

                // Supported formats
                VStack(alignment: .leading, spacing: 8) {
                    Text("Supported formats:")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)

                    HStack {
                        Label("CSV", systemImage: "doc.text")
                        Label("Excel (.xlsx)", systemImage: "tablecells")
                        Label("Excel (.xls)", systemImage: "tablecells")
                    }
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.textSecondary)

                    Text("Multi-sheet Excel files supported - you'll be prompted to select the sheet to import.")
                        .font(.caption2)
                        .foregroundStyle(ProcedusTheme.textTertiary)
                }
                .padding()
                .background(ProcedusTheme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal, 32)

                if enabledPacks.isEmpty {
                    // Warning: no specialty packs configured
                    VStack(spacing: 8) {
                        Label("Specialty Packs Required", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(ProcedusTheme.warning)
                        Text("You must select your specialty packs in Settings before importing a procedure log.")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(ProcedusTheme.warning.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                }

                if attendings.isEmpty {
                    // Warning: no attendings configured
                    VStack(spacing: 8) {
                        Label("Attendings Required", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(ProcedusTheme.warning)
                        Text("You must add at least one attending in Settings before importing a procedure log.")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(ProcedusTheme.warning.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                }

                if enabledPacks.isEmpty || attendings.isEmpty {
                    Button {
                        dismiss()
                    } label: {
                        Text("Go to Settings")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ProcedusTheme.primary)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                } else {
                    Button {
                        showingFilePicker = true
                    } label: {
                        Label("Select File", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ProcedusTheme.primary)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                }

                // How to export from Procedus Classic
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to export from Procedus Classic:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(ProcedusTheme.textSecondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Open the original Procedus app")
                        Text("2. Go to Settings > Export Data")
                        Text("3. Choose CSV or Excel format")
                        Text("4. Save or share the file to import here")
                    }
                    .font(.caption2)
                    .foregroundStyle(ProcedusTheme.textTertiary)
                }
                .padding()
                .background(ProcedusTheme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal, 32)

                Spacer(minLength: 32)
            }
        }
    }
    
    // MARK: - Step 2: Map Columns
    
    private var mapColumnsView: some View {
        Form {
            // Per-sheet header for batch imports
            if !sheetImportDataList.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Sheet \(currentSheetIndex + 1) of \(sheetImportDataList.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(ProcedusTheme.primary.opacity(0.15))
                                .foregroundStyle(ProcedusTheme.primary)
                                .cornerRadius(6)
                            Spacer()
                            Text("\(dataRows.count) rows")
                                .font(.caption)
                                .foregroundStyle(ProcedusTheme.textTertiary)
                        }
                        Text(sheetImportDataList[currentSheetIndex].sheetName)
                            .font(.headline)
                        Text("Procedure: \(sheetImportDataList[currentSheetIndex].procedureName)")
                            .font(.subheadline)
                            .foregroundStyle(ProcedusTheme.textSecondary)
                    }
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Found \(dataRows.count) rows across \(headers.count) columns")
                            .font(.subheadline)
                            .foregroundStyle(ProcedusTheme.textSecondary)
                        if let url = selectedFileURL {
                            Text(url.lastPathComponent)
                                .font(.caption)
                                .foregroundStyle(ProcedusTheme.textTertiary)
                        }
                    }
                }
            }

            // Data preview
            Section("Data Preview") {
                ScrollView(.horizontal, showsIndicators: true) {
                    let columnWidths = previewColumnWidths
                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                        // Header row
                        GridRow {
                            ForEach(0..<headers.count, id: \.self) { i in
                                Text(headers[i])
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .frame(width: columnWidths[i], alignment: .leading)
                                    .lineLimit(1)
                            }
                        }
                        Divider()
                        // First 3 data rows
                        ForEach(0..<min(3, dataRows.count), id: \.self) { rowIdx in
                            GridRow {
                                ForEach(0..<headers.count, id: \.self) { colIdx in
                                    Text(colIdx < dataRows[rowIdx].count ? dataRows[rowIdx][colIdx] : "")
                                        .font(.caption2)
                                        .frame(width: columnWidths[colIdx], alignment: .leading)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if sheetImportDataList.isEmpty && sheetProcedureMappings.isEmpty {
                Section("Required") {
                    if columnMapping.sheetProcedureName != nil {
                        Toggle(isOn: $columnMapping.useSheetNameAsProcedure) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use sheet name as procedure")
                                    .font(.subheadline)
                                if let name = columnMapping.sheetProcedureName {
                                    Text("\"\(name)\"")
                                        .font(.caption)
                                        .foregroundStyle(ProcedusTheme.primary)
                                }
                            }
                        }
                        .tint(ProcedusTheme.primary)
                    }

                    if !columnMapping.useSheetNameAsProcedure {
                        columnPicker(title: "Procedures", selection: $columnMapping.proceduresColumn, required: true)
                    }
                }
            }

            Section("Recommended") {
                columnPicker(title: "Date/Week", selection: $columnMapping.dateColumn, required: false)
                columnPicker(title: "Attending/Supervisor", selection: $columnMapping.attendingColumn, required: false)
                columnPicker(title: "Facility/Hospital", selection: $columnMapping.facilityColumn, required: false)
            }

            Section("Optional") {
                columnPicker(title: "Access Sites", selection: $columnMapping.accessSitesColumn, required: false)
                columnPicker(title: "Complications", selection: $columnMapping.complicationsColumn, required: false)
                columnPicker(title: "Outcome", selection: $columnMapping.outcomeColumn, required: false)
                columnPicker(title: "Operator Role", selection: $columnMapping.roleColumn, required: false)
                columnPicker(title: "Patient Name/ID", selection: $columnMapping.patientColumn, required: false)
                columnPicker(title: "Patient Age", selection: $columnMapping.ageColumn, required: false)
                columnPicker(title: "Notes", selection: $columnMapping.notesColumn, required: false)
            }

            if sheetImportDataList.isEmpty && !columnMapping.useSheetNameAsProcedure {
                Section("Procedure Delimiter") {
                    Picker("Procedures separated by", selection: $columnMapping.procedureDelimiter) {
                        Text("Semicolon (;)").tag(";")
                        Text("Comma (,)").tag(",")
                        Text("Pipe (|)").tag("|")
                        Text("Newline").tag("\n")
                    }
                }
            }

            // Navigation and action buttons
            if !sheetImportDataList.isEmpty {
                // Per-sheet navigation
                Section {
                    HStack(spacing: 12) {
                        if currentSheetIndex > 0 {
                            Button {
                                saveCurrentSheetMapping()
                                currentSheetIndex -= 1
                                loadSheetAtCurrentIndex()
                            } label: {
                                Label("Previous", systemImage: "chevron.left")
                            }
                            .buttonStyle(.borderless)
                        }

                        Spacer()

                        if currentSheetIndex < sheetImportDataList.count - 1 {
                            Button {
                                saveCurrentSheetMapping()
                                currentSheetIndex += 1
                                loadSheetAtCurrentIndex()
                            } label: {
                                Label("Next Sheet", systemImage: "chevron.right")
                                    .labelStyle(.titleAndIcon)
                            }
                            .buttonStyle(.borderless)
                        } else {
                            // Last sheet — import all
                            Button {
                                saveCurrentSheetMapping()
                                processBatchImport()
                            } label: {
                                if isProcessing {
                                    ProgressView()
                                } else {
                                    Text("Import All \(sheetImportDataList.count) Sheets")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderless)
                            .disabled(isProcessing)
                        }
                    }
                }
            } else {
                // Single-sheet continue button
                Section {
                    Button {
                        processImport()
                    } label: {
                        if isProcessing {
                            VStack(spacing: 4) {
                                ProgressView()
                                Text("Processing \(dataRows.count) rows...")
                                    .font(.caption)
                                    .foregroundStyle(ProcedusTheme.textSecondary)
                            }
                        } else {
                            Text("Continue")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isColumnMappingValid || isProcessing)
                }
            }
        }
    }

    /// Save the current column mapping edits back to the sheet data list.
    private func saveCurrentSheetMapping() {
        guard !sheetImportDataList.isEmpty,
              currentSheetIndex < sheetImportDataList.count else { return }
        sheetImportDataList[currentSheetIndex].columnMapping = columnMapping
    }

    /// Load the sheet at `currentSheetIndex` into the active view state.
    private func loadSheetAtCurrentIndex() {
        guard currentSheetIndex < sheetImportDataList.count else { return }
        let sheet = sheetImportDataList[currentSheetIndex]
        headers = sheet.headers
        dataRows = sheet.rows
        columnMapping = sheet.columnMapping
    }
    
    private func columnPicker(title: String, selection: Binding<Int?>, required: Bool) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            if required {
                Text("*").foregroundStyle(ProcedusTheme.error)
            }
            Spacer()
            Picker("", selection: selection) {
                Text("Not mapped").tag(nil as Int?)
                ForEach(0..<headers.count, id: \.self) { index in
                    Text(headers[index]).tag(index as Int?)
                }
            }
            .labelsHidden()
        }
    }
    
    private var isColumnMappingValid: Bool {
        columnMapping.useSheetNameAsProcedure || columnMapping.proceduresColumn != nil
    }

    /// Calculate fixed column widths based on header and data content
    private var previewColumnWidths: [CGFloat] {
        let previewRows = Array(dataRows.prefix(3))
        return (0..<headers.count).map { colIdx in
            let headerLen = headers[colIdx].count
            let maxDataLen = previewRows.map { row in
                colIdx < row.count ? row[colIdx].count : 0
            }.max() ?? 0
            let charWidth: CGFloat = 6.5 // approximate caption2 char width
            let computed = CGFloat(max(headerLen, maxDataLen)) * charWidth + 16
            return min(max(computed, 80), 200)
        }
    }

    // MARK: - Step 3: Review Cases
    
    private var reviewCasesView: some View {
        VStack {
            // Summary header
            HStack {
                VStack(alignment: .leading) {
                    Text("\(importedCases.count) Cases")
                        .font(.headline)
                    Text("\(importedCases.filter { $0.isFullyMapped }.count) ready to import")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.success)
                }
                Spacer()
                let unmappedCount = importedCases.filter { !$0.isFullyMapped }.count
                if unmappedCount > 0 {
                    Text("\(unmappedCount) need attention")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.warning)
                }
            }
            .padding()
            .background(ProcedusTheme.cardBackground)
            
            List {
                ForEach(importedCases) { importedCase in
                    ImportedCaseRow(importedCase: importedCase)
                }
            }
            .listStyle(.plain)
            
            // Continue button
            Button {
                // Build attending checklist entries for unrecognized names
                buildAttendingChecklistEntries()

                if !attendingChecklistEntries.isEmpty {
                    showAttendingConfirmation = false
                    importStep = .mapAttendings
                } else {
                    advanceToNextStepAfterAttendings()
                }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ProcedusTheme.primary)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
    }

    /// Normalize an attending name for consistent lookup (trim whitespace, commas, periods, lowercase)
    private func normalizeAttendingName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: ",."))
            .lowercased()
    }

    /// Build the checklist of unique unmapped attending names from imported cases
    private func buildAttendingChecklistEntries() {
        var seen = Set<String>()
        var entries: [AttendingChecklistEntry] = []
        var countMap: [String: Int] = [:]

        // First pass: count cases per normalized name
        for importedCase in importedCases {
            let allNoninvasive = !importedCase.mappedProcedures.isEmpty &&
                importedCase.mappedProcedures.allSatisfy { proc in
                    proc.matchedTagId?.hasPrefix("ci-") == true
                }
            if allNoninvasive { continue }

            guard importedCase.mappedAttendingId == nil,
                  let name = importedCase.attendingName,
                  !name.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            let normalized = normalizeAttendingName(name)
            countMap[normalized, default: 0] += 1
        }

        // Second pass: build unique entries
        for importedCase in importedCases {
            let allNoninvasive = !importedCase.mappedProcedures.isEmpty &&
                importedCase.mappedProcedures.allSatisfy { proc in
                    proc.matchedTagId?.hasPrefix("ci-") == true
                }
            if allNoninvasive { continue }

            guard importedCase.mappedAttendingId == nil,
                  let name = importedCase.attendingName,
                  !name.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            let cleaned = name.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: ",."))

            let normalized = normalizeAttendingName(name)
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)

            let parts = cleaned.components(separatedBy: " ")
            let firstName = parts.first ?? ""
            let lastName = parts.dropFirst().joined(separator: " ")

            entries.append(AttendingChecklistEntry(
                originalName: cleaned,
                caseCount: countMap[normalized] ?? 1,
                defaultFirstName: firstName,
                defaultLastName: lastName
            ))
        }

        attendingChecklistEntries = entries.sorted { $0.caseCount > $1.caseCount }
    }
    
    // MARK: - Step 4: Map Attendings

    private var mapAttendingsView: some View {
        VStack {
            if showAttendingConfirmation {
                attendingConfirmationView
            } else {
                attendingChecklistView
            }
        }
    }

    // MARK: Phase 1: Attending Checklist

    private var attendingChecklistView: some View {
        VStack {
            Text("Add Unrecognized Attendings")
                .font(.headline)
                .padding(.top)

            Text("Checked names will be added as new attendings. Uncheck to map to an existing one.")
                .font(.caption)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            List {
                ForEach($attendingChecklistEntries) { $entry in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $entry.addAsNew) {
                            HStack {
                                Text(entry.originalName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(entry.caseCount) case\(entry.caseCount == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundStyle(ProcedusTheme.textTertiary)
                            }
                        }
                        .toggleStyle(ClinicalCheckboxToggleStyle())

                        if !entry.addAsNew {
                            Picker("Map to existing", selection: $entry.existingAttendingId) {
                                Text("Select attending...").tag(UUID?.none)
                                ForEach(attendings) { att in
                                    Text(att.fullName).tag(UUID?.some(att.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.subheadline)
                            .onChange(of: entry.existingAttendingId) { _, newId in
                                if let newId,
                                   let att = attendings.first(where: { $0.id == newId }) {
                                    if let idx = attendingChecklistEntries.firstIndex(where: { $0.id == entry.id }) {
                                        attendingChecklistEntries[idx].existingAttendingName = att.fullName
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)

            Button {
                // Validate: unchecked entries must have an existing attending selected
                let invalidEntries = attendingChecklistEntries.filter { !$0.addAsNew && $0.existingAttendingId == nil }
                if !invalidEntries.isEmpty {
                    errorMessage = "Please select an existing attending for all unchecked names, or check them to add as new."
                    return
                }
                showAttendingConfirmation = true
            } label: {
                Text("Add All & Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ProcedusTheme.primary)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
    }

    // MARK: Phase 2: Attending Confirmation

    private var attendingConfirmationView: some View {
        VStack {
            Text("Confirm Attending Mappings")
                .font(.headline)
                .padding(.top)

            Text("Review the mappings below.")
                .font(.caption)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            List {
                ForEach(attendingChecklistEntries) { entry in
                    HStack(spacing: 8) {
                        if entry.addAsNew {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(ProcedusTheme.accent)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(ProcedusTheme.success)
                        }

                        Text(entry.originalName)
                            .font(.subheadline)

                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(ProcedusTheme.textTertiary)

                        if entry.addAsNew {
                            (Text("\(entry.defaultFirstName) \(entry.defaultLastName)")
                                .foregroundStyle(ProcedusTheme.accent) +
                            Text(" (new)")
                                .foregroundStyle(ProcedusTheme.textTertiary))
                                .font(.subheadline)
                        } else if let name = entry.existingAttendingName {
                            Text(name)
                                .font(.subheadline)
                                .foregroundStyle(ProcedusTheme.success)
                        }
                    }
                }
            }
            .listStyle(.plain)

            VStack(spacing: 10) {
                Button {
                    confirmAndApplyAttendingMappings()
                } label: {
                    Text("Confirm & Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ProcedusTheme.success)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }

                Button {
                    showAttendingConfirmation = false
                } label: {
                    Text("Go Back")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ProcedusTheme.textTertiary.opacity(0.12))
                        .foregroundStyle(ProcedusTheme.textSecondary)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    /// Create new attendings for checked entries and apply all mappings to imported cases
    private func confirmAndApplyAttendingMappings() {
        // Create new attendings for checked entries
        for i in 0..<attendingChecklistEntries.count {
            let entry = attendingChecklistEntries[i]
            if entry.addAsNew {
                let newAttending = Attending(
                    firstName: entry.defaultFirstName,
                    lastName: entry.defaultLastName
                )
                modelContext.insert(newAttending)
                attendingChecklistEntries[i].existingAttendingId = newAttending.id
                attendingChecklistEntries[i].existingAttendingName = newAttending.fullName
            }
        }

        // Persist new attendings before referencing their IDs
        try? modelContext.save()

        // Also populate unmappedAttendingEntries for performImport compatibility
        unmappedAttendingEntries = attendingChecklistEntries.map { entry in
            MappedAttendingEntry(
                originalName: entry.originalName,
                mappedAttendingId: entry.existingAttendingId,
                mappedAttendingName: entry.existingAttendingName,
                status: entry.addAsNew ? .newlyCreated : .mapped
            )
        }

        // Apply mappings to imported cases
        for i in 0..<importedCases.count {
            guard importedCases[i].mappedAttendingId == nil,
                  let name = importedCases[i].attendingName else { continue }
            let normalized = normalizeAttendingName(name)
            for entry in attendingChecklistEntries {
                if normalizeAttendingName(entry.originalName) == normalized,
                   let attId = entry.existingAttendingId {
                    importedCases[i].mappedAttendingId = attId
                    break
                }
            }
        }

        advanceToNextStepAfterAttendings()
    }

    /// Determine the next step after attending mapping, skipping inapplicable steps
    private func advanceToNextStepAfterAttendings() {
        // Check for role mapping
        buildRoleMappingEntries()
        if !unmappedRoleEntries.isEmpty {
            importStep = .mapRoles
            return
        }
        advanceToNextStepAfterRoles()
    }

    private func advanceToNextStepAfterRoles() {
        // Always show facility mapping
        buildFacilityMappingEntries()
        importStep = .mapFacilities
    }

    private func advanceToNextStepAfterFacilities() {
        let hasUnmapped = importedCases.contains { $0.unmappedProcedureCount > 0 }
        if hasUnmapped {
            importStep = .mapProcedures
        } else {
            advanceToNextStepAfterProcedures()
        }
    }

    private func advanceToNextStepAfterProcedures() {
        detectMergeGroups()
        if !mergeGroups.isEmpty {
            importStep = .mergeCases
        } else {
            importStep = .confirm
        }
    }

    /// Apply all attending mappings from the mapping entries to the imported cases
    private func applyAllAttendingMappings() {
        let normalizedMap: [String: MappedAttendingEntry] = Dictionary(
            unmappedAttendingEntries.map { (normalizeAttendingName($0.originalName), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for i in 0..<importedCases.count {
            guard importedCases[i].mappedAttendingId == nil,
                  let name = importedCases[i].attendingName else { continue }
            let normalized = normalizeAttendingName(name)
            if let entry = normalizedMap[normalized], let attendingId = entry.mappedAttendingId {
                importedCases[i].mappedAttendingId = attendingId
            }
        }
    }

    // MARK: - Step 5: Map Roles

    private func buildRoleMappingEntries() {
        var roleCount: [String: Int] = [:]
        for imported in importedCases {
            guard let role = imported.operatorRole, !role.isEmpty else { continue }
            let trimmed = role.trimmingCharacters(in: .whitespaces)
            roleCount[trimmed, default: 0] += 1
        }

        unmappedRoleEntries = roleCount.map { (value, count) in
            var position: OperatorPosition? = nil
            let lower = value.lowercased()
            if ["primary", "first", "1", "primary operator"].contains(lower) {
                position = .primary
            } else if ["secondary", "second", "2", "assistant", "secondary operator"].contains(lower) {
                position = .secondary
            }
            return MappedRoleEntry(originalValue: value, mappedPosition: position, caseCount: count)
        }
        .sorted { $0.caseCount > $1.caseCount }
    }

    private func applyRoleMappings() {
        let roleMap: [String: OperatorPosition] = Dictionary(
            unmappedRoleEntries.compactMap { entry -> (String, OperatorPosition)? in
                guard let pos = entry.mappedPosition else { return nil }
                return (entry.originalValue.lowercased(), pos)
            },
            uniquingKeysWith: { first, _ in first }
        )

        for i in 0..<importedCases.count {
            guard let role = importedCases[i].operatorRole else { continue }
            let lower = role.trimmingCharacters(in: .whitespaces).lowercased()
            if let position = roleMap[lower] {
                importedCases[i].mappedOperatorPosition = position
            }
        }
    }

    private var mapRolesView: some View {
        VStack {
            Text("Map Operator Roles")
                .font(.headline)
                .padding(.top)

            Text("Map the role values from your file to Primary or Secondary operator positions.")
                .font(.caption)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            List {
                ForEach($unmappedRoleEntries) { $entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(entry.originalValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(entry.caseCount) case\(entry.caseCount == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(ProcedusTheme.textTertiary)
                        }

                        Picker("Position", selection: $entry.mappedPosition) {
                            Text("Skip").tag(OperatorPosition?.none)
                            Text("Primary").tag(OperatorPosition?.some(.primary))
                            Text("Secondary").tag(OperatorPosition?.some(.secondary))
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)

            Button {
                applyRoleMappings()
                advanceToNextStepAfterRoles()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ProcedusTheme.primary)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
    }

    // MARK: - Step 6: Map Facilities

    private func buildFacilityMappingEntries() {
        var facilityCount: [String: Int] = [:]
        for imported in importedCases {
            guard imported.mappedFacilityId == nil,
                  let name = imported.facilityName,
                  !name.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            facilityCount[trimmed, default: 0] += 1
        }

        unmappedFacilityEntries = facilityCount.map { (name, count) in
            MappedFacilityEntry(originalName: name, status: .unmapped, caseCount: count)
        }
        .sorted { $0.caseCount > $1.caseCount }
    }

    private func applyFacilityMappings() {
        // Cascade: All → Per Attending → Per Procedure → Per Case
        // Each layer overrides the previous where a value is set.

        // Layer 1: All Cases (bulk)
        if let fId = bulkFacilityId {
            for i in 0..<importedCases.count {
                importedCases[i].mappedFacilityId = fId
            }
        }

        // Layer 2: Per Attending overrides
        for i in 0..<importedCases.count {
            guard let attName = importedCases[i].attendingName else { continue }
            let key = attName.trimmingCharacters(in: .whitespaces).lowercased()
            if let fId = attendingFacilityMap[key] {
                importedCases[i].mappedFacilityId = fId
            }
        }

        // Layer 3: Per Procedure overrides
        for i in 0..<importedCases.count {
            for procName in importedCases[i].procedureNames {
                let key = procName.trimmingCharacters(in: .whitespaces).lowercased()
                if let fId = procedureFacilityMap[key] {
                    importedCases[i].mappedFacilityId = fId
                    break
                }
            }
        }

        // Layer 4: Per Case overrides (highest priority)
        for (index, fId) in caseFacilityMap {
            guard index < importedCases.count else { continue }
            importedCases[index].mappedFacilityId = fId
        }
    }

    private var mapFacilitiesView: some View {
        VStack {
            Text("Map Facilities")
                .font(.headline)
                .padding(.top)

            Text("Assign facilities to your imported cases. Choose a mapping mode below.")
                .font(.caption)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Picker("Mode", selection: $facilityMappingMode) {
                ForEach(FacilityMappingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Group {
                switch facilityMappingMode {
                case .bulk:
                    facilityBulkModeView
                case .perAttending:
                    facilityPerAttendingView
                case .perProcedure:
                    facilityPerProcedureView
                case .perCase:
                    facilityPerCaseView
                }
            }

            HStack(spacing: 12) {
                Button {
                    // Skip - no facility mapping
                    advanceToNextStepAfterFacilities()
                } label: {
                    Text("Skip")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ProcedusTheme.textTertiary.opacity(0.12))
                        .foregroundStyle(ProcedusTheme.textSecondary)
                        .cornerRadius(12)
                }

                Button {
                    applyFacilityMappings()
                    advanceToNextStepAfterFacilities()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ProcedusTheme.primary)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingAddFacilitySheet) {
            AddEditFacilitySheet(facility: nil)
        }
    }

    private var facilityBulkModeView: some View {
        List {
            Section {
                Picker("Facility for all cases", selection: $bulkFacilityId) {
                    Text("Not Set").tag(UUID?.none)
                    ForEach(facilities) { facility in
                        Text(facility.name).tag(UUID?.some(facility.id))
                    }
                }
            }

            Section {
                Button {
                    showingAddFacilitySheet = true
                } label: {
                    Label("Add New Facility", systemImage: "plus.circle")
                        .foregroundStyle(ProcedusTheme.accent)
                }
            }

            if !unmappedFacilityEntries.isEmpty {
                Section("Unrecognized Facilities") {
                    ForEach(unmappedFacilityEntries) { entry in
                        HStack {
                            Text(entry.originalName)
                                .font(.subheadline)
                            Spacer()
                            Text("\(entry.caseCount) case\(entry.caseCount == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(ProcedusTheme.textTertiary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var facilityPerAttendingView: some View {
        List {
            let uniqueAttendings = Array(Set(importedCases.compactMap { $0.attendingName?.trimmingCharacters(in: .whitespaces) })).sorted()
            ForEach(uniqueAttendings, id: \.self) { attName in
                let key = attName.lowercased()
                VStack(alignment: .leading, spacing: 4) {
                    Text(attName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("", selection: Binding(
                        get: { attendingFacilityMap[key] },
                        set: { attendingFacilityMap[key] = $0 }
                    )) {
                        Text("Not Set").tag(UUID?.none)
                        ForEach(facilities) { facility in
                            Text(facility.name).tag(UUID?.some(facility.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Section {
                Button {
                    showingAddFacilitySheet = true
                } label: {
                    Label("Add New Facility", systemImage: "plus.circle")
                        .foregroundStyle(ProcedusTheme.accent)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var facilityPerProcedureView: some View {
        List {
            let uniqueProcs = Array(Set(importedCases.flatMap { $0.procedureNames.map { $0.trimmingCharacters(in: .whitespaces) } })).sorted()
            ForEach(uniqueProcs, id: \.self) { procName in
                let key = procName.lowercased()
                VStack(alignment: .leading, spacing: 4) {
                    Text(procName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("", selection: Binding(
                        get: { procedureFacilityMap[key] },
                        set: { procedureFacilityMap[key] = $0 }
                    )) {
                        Text("Not Set").tag(UUID?.none)
                        ForEach(facilities) { facility in
                            Text(facility.name).tag(UUID?.some(facility.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Section {
                Button {
                    showingAddFacilitySheet = true
                } label: {
                    Label("Add New Facility", systemImage: "plus.circle")
                        .foregroundStyle(ProcedusTheme.accent)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var facilityPerCaseView: some View {
        List {
            ForEach(Array(importedCases.enumerated()), id: \.offset) { index, imported in
                // Skip noninvasive-only cases
                let allNoninvasive = !imported.mappedProcedures.isEmpty &&
                    imported.mappedProcedures.allSatisfy { $0.matchedTagId?.hasPrefix("ci-") == true }
                if !allNoninvasive {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                if let d = imported.date {
                                    Text(d, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(ProcedusTheme.textTertiary)
                                }
                                Text(imported.procedureNames.joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if let att = imported.attendingName {
                                Text(att)
                                    .font(.caption2)
                                    .foregroundStyle(ProcedusTheme.textSecondary)
                            }
                        }
                        Picker("", selection: Binding(
                            get: { caseFacilityMap[index] },
                            set: { caseFacilityMap[index] = $0 }
                        )) {
                            Text("Not Set").tag(UUID?.none)
                            ForEach(facilities) { facility in
                                Text(facility.name).tag(UUID?.some(facility.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }

            Section {
                Button {
                    showingAddFacilitySheet = true
                } label: {
                    Label("Add New Facility", systemImage: "plus.circle")
                        .foregroundStyle(ProcedusTheme.accent)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Step 7: Map Procedures

    private var mapProceduresView: some View {
        VStack {
            Text("Map Unrecognized Procedures")
                .font(.headline)
                .padding(.top)
            
            Text("We couldn't automatically match some procedures. Please select the correct match or create a custom procedure.")
                .font(.caption)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            List {
                ForEach($importedCases) { $importedCase in
                    ForEach($importedCase.mappedProcedures) { $mappedProcedure in
                        if mappedProcedure.status == .unmapped {
                            ProcedureMappingRow(
                                mappedProcedure: $mappedProcedure,
                                enabledPacks: enabledPacks,
                                customProcedures: customProcedures,
                                onProcedureMapped: { originalName, tagId, title, confidence in
                                    handleProcedureMappingComplete(
                                        originalName: originalName,
                                        matchedTagId: tagId,
                                        matchedTitle: title,
                                        matchConfidence: confidence
                                    )
                                }
                            )
                        }
                    }
                }
            }
            .listStyle(.plain)
            
            Button {
                advanceToNextStepAfterProcedures()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ProcedusTheme.primary)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
    }

    // MARK: - Step 8: Merge Cases

    private func detectMergeGroups() {
        mergeGroups = []
        guard importedCases.count > 1 else { return }

        var groupMap: [String: [Int]] = [:]

        for (index, imported) in importedCases.enumerated() {
            guard let date = imported.date else { continue }
            let dateStr = CaseEntry.makeWeekBucket(for: date) + "-" + Self.dayString(from: date)

            // Include age in key when available (different ages = different patients)
            let ageSuffix: String
            if let age = imported.patientAge, !age.isEmpty {
                ageSuffix = "|age:" + age.trimmingCharacters(in: .whitespaces).lowercased()
            } else {
                ageSuffix = ""
            }

            if let patientId = imported.patientIdentifier, !patientId.isEmpty {
                // Group by date + patient identifier + age
                let key = dateStr + "|" + patientId.trimmingCharacters(in: .whitespaces).lowercased() + ageSuffix
                groupMap[key, default: []].append(index)
            } else if let att = imported.attendingName, !att.isEmpty {
                // Group by date + attending + age (fallback)
                let key = dateStr + "|att:" + att.trimmingCharacters(in: .whitespaces).lowercased() + ageSuffix
                groupMap[key, default: []].append(index)
            }
        }

        for (_, indices) in groupMap {
            guard indices.count >= 2 else { continue }

            // Check for duplicate procedure names — duplicates mean different patients
            var procedureNameCounts: [String: Int] = [:]
            for idx in indices {
                for procName in importedCases[idx].procedureNames {
                    let normalized = procName.trimmingCharacters(in: .whitespaces).lowercased()
                    procedureNameCounts[normalized, default: 0] += 1
                }
            }
            let hasDuplicateProcedures = procedureNameCounts.values.contains(where: { $0 > 1 })
            if hasDuplicateProcedures {
                // Same procedure appearing multiple times means different patients — skip merge
                continue
            }

            // Build group label
            let first = importedCases[indices[0]]
            let dateLabel: String
            if let d = first.date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                dateLabel = formatter.string(from: d)
            } else {
                dateLabel = first.weekBucket
            }

            let identifier: String
            if let patId = first.patientIdentifier, !patId.isEmpty {
                identifier = "Patient " + String(patId.prefix(10))
            } else if let att = first.attendingName {
                identifier = "Dr. " + att
            } else {
                identifier = "Unknown"
            }

            // Include age in label if available
            let ageLabel: String
            if let age = first.patientAge, !age.isEmpty {
                ageLabel = " (Age \(age))"
            } else {
                ageLabel = ""
            }

            let label = "\(dateLabel) — \(identifier)\(ageLabel) (\(indices.count) procedures)"

            mergeGroups.append(MergeGroup(
                groupLabel: label,
                caseIndices: indices,
                shouldMerge: true
            ))
        }

        mergeGroups.sort { $0.groupLabel < $1.groupLabel }
    }

    private static func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func applyMerges() {
        // Collect indices to remove (in reverse order to avoid shifting)
        var indicesToRemove: [Int] = []

        for group in mergeGroups where group.shouldMerge {
            guard group.caseIndices.count >= 2 else { continue }
            let primaryIdx = group.caseIndices[0]

            for secondaryIdx in group.caseIndices.dropFirst() {
                let secondary = importedCases[secondaryIdx]

                // Merge procedure names
                importedCases[primaryIdx].procedureNames.append(contentsOf: secondary.procedureNames)

                // Merge mapped procedures
                importedCases[primaryIdx].mappedProcedures.append(contentsOf: secondary.mappedProcedures)

                // Merge access sites
                importedCases[primaryIdx].accessSites.append(contentsOf: secondary.accessSites)
                importedCases[primaryIdx].mappedAccessSites.append(contentsOf: secondary.mappedAccessSites)

                // Merge complications
                importedCases[primaryIdx].complications.append(contentsOf: secondary.complications)
                importedCases[primaryIdx].mappedComplications.append(contentsOf: secondary.mappedComplications)

                // Use first non-nil attending/facility
                if importedCases[primaryIdx].mappedAttendingId == nil {
                    importedCases[primaryIdx].mappedAttendingId = secondary.mappedAttendingId
                    importedCases[primaryIdx].attendingName = secondary.attendingName
                }
                if importedCases[primaryIdx].mappedFacilityId == nil {
                    importedCases[primaryIdx].mappedFacilityId = secondary.mappedFacilityId
                    importedCases[primaryIdx].facilityName = secondary.facilityName
                }

                // Concatenate notes
                if let secondaryNotes = secondary.notes, !secondaryNotes.isEmpty {
                    if let existingNotes = importedCases[primaryIdx].notes, !existingNotes.isEmpty {
                        importedCases[primaryIdx].notes = existingNotes + "\n" + secondaryNotes
                    } else {
                        importedCases[primaryIdx].notes = secondaryNotes
                    }
                }

                indicesToRemove.append(secondaryIdx)
            }
        }

        // Remove merged cases in reverse order
        for idx in indicesToRemove.sorted().reversed() {
            importedCases.remove(at: idx)
        }
    }

    private var mergeCasesView: some View {
        VStack {
            Text("Merge Multi-Procedure Cases")
                .font(.headline)
                .padding(.top)

            Text("These cases appear to belong to the same patient visit. Toggle to merge procedures into a single case.")
                .font(.caption)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            List {
                ForEach($mergeGroups) { $group in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $group.shouldMerge) {
                            Text(group.groupLabel)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        if group.shouldMerge {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(group.caseIndices, id: \.self) { idx in
                                    if idx < importedCases.count {
                                        Text("• " + importedCases[idx].procedureNames.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundStyle(ProcedusTheme.textSecondary)
                                    }
                                }
                            }
                            .padding(.leading, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)

            Button {
                applyMerges()
                importStep = .confirm
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ProcedusTheme.primary)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
    }

    // MARK: - Step 9: Confirm
    
    private var confirmView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundStyle(ProcedusTheme.success)
            
            Text("Ready to Import")
                .font(.title2)
                .fontWeight(.semibold)
            
            let readyCount = importedCases.filter { $0.isFullyMapped }.count
            let customCount = importedCases.flatMap { $0.mappedProcedures }.filter { $0.status == .customNew }.count
            
            VStack(spacing: 8) {
                Text("\(readyCount) cases will be imported")
                if customCount > 0 {
                    Text("\(customCount) custom procedures will be created")
                        .foregroundStyle(ProcedusTheme.accent)
                }
                let skipped = importedCases.count - readyCount
                if skipped > 0 {
                    Text("\(skipped) cases will be skipped (incomplete mapping)")
                        .foregroundStyle(ProcedusTheme.warning)
                }
            }
            .font(.subheadline)
            .foregroundStyle(ProcedusTheme.textSecondary)
            
            Spacer()
            
            Button {
                performImport()
            } label: {
                if isProcessing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ProcedusTheme.primary)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                } else {
                    Text("Import Cases")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ProcedusTheme.primary)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
            }
            .disabled(isProcessing)
            .padding(.horizontal, 32)

            Button {
                if let prev = previousStep(from: .confirm) {
                    importStep = prev
                }
            } label: {
                Text("Go Back")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ProcedusTheme.textTertiary.opacity(0.12))
                    .foregroundStyle(ProcedusTheme.textSecondary)
                    .cornerRadius(12)
            }
            .disabled(isProcessing)
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Step 10: Complete
    
    private var completeView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "party.popper")
                .font(.system(size: 64))
                .foregroundStyle(ProcedusTheme.success)
            
            Text("Import Complete!")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let result = importResult {
                VStack(spacing: 8) {
                    Text("\(result.importedCount) cases imported successfully")
                        .foregroundStyle(ProcedusTheme.success)
                    if result.customProceduresCreated > 0 {
                        Text("\(result.customProceduresCreated) custom procedures created")
                            .foregroundStyle(ProcedusTheme.accent)
                    }
                    if result.attendingsCreated > 0 {
                        Text("\(result.attendingsCreated) attendings created")
                            .foregroundStyle(ProcedusTheme.accent)
                    }
                    if result.skippedCount > 0 {
                        Text("\(result.skippedCount) cases skipped")
                            .foregroundStyle(ProcedusTheme.textSecondary)
                    }
                }
                .font(.subheadline)
            }

            Text("All imported cases are now visible in your procedure log. Attestation is not required for imported procedures.")
                .font(.caption)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ProcedusTheme.primary)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Mapping Confirmation Sheet

    private var mappingConfirmationSheetView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(ProcedusTheme.primary)

            Text("Mapping Applied")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                Text(mappingConfirmation?.originalName ?? "")
                    .font(.subheadline)
                    .foregroundStyle(ProcedusTheme.textSecondary)

                Image(systemName: "arrow.down")
                    .foregroundStyle(ProcedusTheme.textTertiary)

                Text(mappingConfirmation?.mappedName ?? "")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(ProcedusTheme.success)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(ProcedusTheme.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 32)

            Text("This mapping will be applied to all unmapped entries with the same name.")
                .font(.caption)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    confirmMapping()
                } label: {
                    Text("Confirm")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ProcedusTheme.success)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }

                Button {
                    undoMapping()
                } label: {
                    Text("Undo")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ProcedusTheme.error.opacity(0.12))
                        .foregroundStyle(ProcedusTheme.error)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium])
    }

    // MARK: - Similar Procedures Sheet

    private var similarProceduresSheetView: some View {
        NavigationStack {
            VStack {
                Text("We found other unmapped procedures with similar names. Apply the same mapping?")
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 8)

                if let pending = pendingProcedureMapping {
                    HStack {
                        Text("Mapping to:")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.textTertiary)
                        Text(pending.matchedTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(ProcedusTheme.success)
                    }
                    .padding(.horizontal)
                }

                List {
                    ForEach($similarProcedureMatches) { $match in
                        Toggle(isOn: $match.isSelected) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(match.originalName)
                                    .font(.subheadline)
                                Text("\(Int(match.confidence * 100))% similar")
                                    .font(.caption2)
                                    .foregroundStyle(ProcedusTheme.textTertiary)
                            }
                        }
                    }
                }
                .listStyle(.plain)

                VStack(spacing: 10) {
                    Button {
                        applySimilarProcedureMappings(selectedOnly: false)
                    } label: {
                        Text("Apply to All")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ProcedusTheme.primary)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }

                    Button {
                        applySimilarProcedureMappings(selectedOnly: true)
                    } label: {
                        Text("Apply Selected")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ProcedusTheme.primary.opacity(0.12))
                            .foregroundStyle(ProcedusTheme.primary)
                            .cornerRadius(12)
                    }

                    Button {
                        showSimilarProceduresSheet = false
                        pendingProcedureMapping = nil
                    } label: {
                        Text("Skip")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ProcedusTheme.textTertiary.opacity(0.12))
                            .foregroundStyle(ProcedusTheme.textSecondary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("Similar Procedures Found")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Actions

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFileURL = url
            parseSelectedFile()
        case .failure(let error):
            errorMessage = "Failed to select file: \(error.localizedDescription)"
        }
    }
    
    private func parseSelectedFile() {
        guard let url = selectedFileURL else { return }
        isProcessing = true

        // Need to start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Cannot access the selected file"
            isProcessing = false
            return
        }

        // Determine file type before reading
        let isXLSX = ProcedureLogImporter.shared.isXLSXFile(at: url)

        // Read file data while we have security-scoped access.
        // Security-scoped access is tied to the original URL from the file picker.
        // We read the data into memory so we can safely process it later.
        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
        } catch {
            url.stopAccessingSecurityScopedResource()
            errorMessage = "Failed to read file: \(error.localizedDescription)"
            isProcessing = false
            return
        }

        // Done with file I/O - release security-scoped access
        url.stopAccessingSecurityScopedResource()

        // Store for later use (sheet picker flow)
        loadedFileData = fileData
        loadedFileIsXLSX = isXLSX

        // Check for summary export (CSV/text only)
        if !isXLSX {
            if let content = String(data: fileData, encoding: .utf8),
               ProcedureLogImporter.shared.isSummaryExport(content) {
                loadedFileData = nil
                errorMessage = "This file contains procedure counts/summary data, not individual case entries. Please export the full Procedure Log instead."
                isProcessing = false
                return
            }
        }

        // For XLSX files, detect sheet names on a background thread.
        // XLSXFile(data:) involves ZIP decompression and parseWorkbooks() does XML parsing,
        // both of which can block the main thread on physical devices for large files.
        if isXLSX {
            let data = fileData
            Task {
                let sheets: [String]? = await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        let result = ProcedureLogImporter.shared.getSheetNamesFromData(data)
                        continuation.resume(returning: result)
                    }
                }

                if let sheets = sheets, sheets.count > 1 {
                    // Build batch sheet-to-procedure mappings with auto-detection.
                    // Run mapProcedure for each sheet name to fuzzy-match against the catalog.
                    let packs = enabledPacks
                    let customProcs = customProcedures.map {
                        ImportCustomProcedure(tagId: $0.tagId, title: $0.title, category: $0.category)
                    }
                    sheetProcedureMappings = sheets.map { name in
                        let mapped = ProcedureLogImporter.shared.mapProcedure(
                            name: name, enabledPacks: packs, customProcedures: customProcs
                        )
                        return SheetProcedureMapping(
                            sheetName: name, isSelected: true, mappedProcedure: mapped
                        )
                    }
                    isProcessing = false
                    showingBatchSheetMapper = true
                } else {
                    // Single sheet or no sheet names - parse directly on background
                    parseLoadedFileData()
                }
            }
            return
        }

        // CSV - parse on background thread
        parseLoadedFileData()
    }

    /// Called from onDismiss of sheet picker when user tapped Import
    private func parseFileWithSelectedSheet() {
        parseLoadedFileData()
    }

    /// Parse the loaded file data on a background GCD thread.
    /// XLSX parsing (CoreXLSX) involves heavy XML parsing that blocks the main thread
    /// on physical devices, making the UI unresponsive. Uses the same GCD pattern as
    /// processImport() to avoid blocking the main thread.
    private func parseLoadedFileData() {
        guard let fileData = loadedFileData else {
            errorMessage = "No file data loaded"
            isProcessing = false
            return
        }

        // Release the large file data from @State immediately.
        // The local 'fileData' variable keeps the underlying Data alive for parsing.
        loadedFileData = nil
        isProcessing = true

        // Capture values for the background thread
        let isXLSX = loadedFileIsXLSX
        let sheetName = selectedSheet

        // Parse on a GCD background thread — XLSX parsing via CoreXLSX involves heavy
        // XML deserialization that can take seconds on a physical device, freezing the UI.
        // Uses the same Task + GCD + withCheckedContinuation pattern as processImport().
        Task {
            let parseResult: (headers: [String], rows: [[String]])? = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let result = ProcedureLogImporter.shared.parseFileFromData(
                        fileData,
                        isXLSX: isXLSX,
                        sheetName: sheetName
                    )
                    continuation.resume(returning: result)
                }
            }

            guard let parseResult = parseResult else {
                errorMessage = "Failed to parse file. Make sure the file is a valid Excel (.xlsx) or CSV file."
                isProcessing = false
                return
            }

            let (parsedHeaders, parsedRows) = parseResult

            guard !parsedHeaders.isEmpty else {
                errorMessage = "The file appears to be empty or has no headers"
                isProcessing = false
                return
            }

            // Check for summary export based on headers (for xlsx files)
            let headersLower = parsedHeaders.map { $0.lowercased() }
            if headersLower.contains("category") && headersLower.contains("procedure") && headersLower.contains("count") && parsedHeaders.count <= 4 {
                errorMessage = "This file contains procedure counts/summary data, not individual case entries. Please export the full Procedure Log instead."
                isProcessing = false
                return
            }

            headers = parsedHeaders
            dataRows = parsedRows

            // Check for duplicate import
            if let fileName = selectedFileURL?.lastPathComponent,
               checkDuplicateImport(fileName: fileName, rowCount: dataRows.count) {
                showDuplicateFileAlert = true
                isProcessing = false
                return
            }

            continueAfterDuplicateCheck()
        }
    }

    /// Parse each selected sheet independently, preserving per-sheet column layouts.
    private func parseBatchSheets() {
        guard let fileData = loadedFileData else {
            errorMessage = "No file data loaded"
            isProcessing = false
            return
        }

        let selected = sheetProcedureMappings.filter { $0.isSelected }
        guard !selected.isEmpty else {
            errorMessage = "No sheets selected for import"
            isProcessing = false
            return
        }

        // Build lookup from sheet name → procedure info
        let procedureLookup: [String: (name: String, tagId: String?)] = Dictionary(
            selected.map { entry in
                (entry.sheetName, (
                    name: entry.mappedProcedure.matchedTitle ?? entry.sheetName,
                    tagId: entry.mappedProcedure.matchedTagId
                ))
            },
            uniquingKeysWith: { first, _ in first }
        )

        let sheetNames = selected.map { $0.sheetName }
        loadedFileData = nil
        isProcessing = true

        Task {
            let parsedSheets: [(sheetName: String, headers: [String], rows: [[String]])] =
                await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        let result = ProcedureLogImporter.shared.parseIndividualSheets(
                            from: fileData, sheetNames: sheetNames
                        )
                        continuation.resume(returning: result)
                    }
                }

            guard !parsedSheets.isEmpty else {
                errorMessage = "Failed to parse the selected sheets."
                isProcessing = false
                return
            }

            // Build per-sheet import data with auto-detected column mappings
            sheetImportDataList = parsedSheets.map { sheet in
                let procInfo = procedureLookup[sheet.sheetName]
                    ?? (name: sheet.sheetName, tagId: nil)

                var mapping = ProcedureLogImporter.shared.autoDetectColumns(
                    headers: sheet.headers, dataRows: sheet.rows, sheetName: sheet.sheetName
                )
                // Each sheet uses its name as the procedure (set in batch mapper)
                mapping.useSheetNameAsProcedure = true
                mapping.sheetProcedureName = procInfo.name
                mapping.sheetProcedureTagId = procInfo.tagId

                return SheetImportData(
                    sheetName: sheet.sheetName,
                    procedureName: procInfo.name,
                    procedureTagId: procInfo.tagId,
                    headers: sheet.headers,
                    rows: sheet.rows,
                    columnMapping: mapping
                )
            }

            // Check for duplicate import
            let totalRows = sheetImportDataList.reduce(0) { $0 + $1.rows.count }
            if let fileName = selectedFileURL?.lastPathComponent,
               checkDuplicateImport(fileName: fileName, rowCount: totalRows) {
                showDuplicateFileAlert = true
                isProcessing = false
                return
            }

            currentSheetIndex = 0

            // Set the first sheet's data as the current view data
            if let first = sheetImportDataList.first {
                headers = first.headers
                dataRows = first.rows
                columnMapping = first.columnMapping
            }

            importStep = .mapColumns
            isProcessing = false
        }
    }

    private func continueAfterDuplicateCheck() {
        // For batch imports, per-sheet mappings are already set in parseBatchSheets()
        if !sheetImportDataList.isEmpty {
            currentSheetIndex = 0
            loadSheetAtCurrentIndex()
            importStep = .mapColumns
            isProcessing = false
            return
        }

        // Auto-detect columns (blank columns default to "not mapped").
        // Pass the selected sheet name so the importer can offer it as the procedure source.
        columnMapping = ProcedureLogImporter.shared.autoDetectColumns(
            headers: headers, dataRows: dataRows, sheetName: selectedSheet
        )

        importStep = .mapColumns
        isProcessing = false
    }

    // MARK: - Import History Tracking

    private func loadImportHistory() -> [ImportHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: "importFileHistory"),
              let entries = try? JSONDecoder().decode([ImportHistoryEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private func saveImportHistory(_ entries: [ImportHistoryEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: "importFileHistory")
        }
    }

    private func recordImport(fileName: String, rowCount: Int) {
        var history = loadImportHistory()
        history.append(ImportHistoryEntry(fileName: fileName, rowCount: rowCount, importDate: Date()))
        saveImportHistory(history)
    }

    private func checkDuplicateImport(fileName: String, rowCount: Int) -> Bool {
        let history = loadImportHistory()
        return history.contains { $0.fileName == fileName && $0.rowCount == rowCount }
    }

    // MARK: - Mapping Handlers & Fuzzy Matching

    private func handleProcedureMappingComplete(originalName: String, matchedTagId: String, matchedTitle: String, matchConfidence: Double) {
        autoApplyExactProcedureMatches(originalName: originalName, tagId: matchedTagId, title: matchedTitle, confidence: matchConfidence)

        pendingProcedureMapping = PendingProcedureMapping(
            sourceOriginalName: originalName,
            matchedTagId: matchedTagId,
            matchedTitle: matchedTitle,
            matchConfidence: matchConfidence
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            mappingConfirmation = MappingConfirmationData(
                type: .procedure,
                originalName: originalName,
                mappedName: matchedTitle,
                attendingId: nil,
                attendingStatus: nil,
                matchedTagId: matchedTagId,
                matchConfidence: matchConfidence
            )
        }
    }

    private func autoApplyExactProcedureMatches(originalName: String, tagId: String, title: String, confidence: Double) {
        let normalizedSource = originalName.trimmingCharacters(in: .whitespaces).lowercased()
        for i in 0..<importedCases.count {
            for j in 0..<importedCases[i].mappedProcedures.count {
                let proc = importedCases[i].mappedProcedures[j]
                if proc.status == .unmapped {
                    let normalizedTarget = proc.originalName.trimmingCharacters(in: .whitespaces).lowercased()
                    if normalizedTarget == normalizedSource {
                        importedCases[i].mappedProcedures[j].matchedTagId = tagId
                        importedCases[i].mappedProcedures[j].matchedTitle = title
                        importedCases[i].mappedProcedures[j].matchConfidence = confidence
                        importedCases[i].mappedProcedures[j].status = .mapped
                    }
                }
            }
        }
    }

    private func findSimilarUnmappedProcedures(mappedOriginalName: String) -> [SimilarProcedureMatch] {
        var seen = Set<String>()
        var results: [SimilarProcedureMatch] = []
        let normalizedSource = mappedOriginalName.trimmingCharacters(in: .whitespaces).lowercased()

        for i in 0..<importedCases.count {
            for j in 0..<importedCases[i].mappedProcedures.count {
                let proc = importedCases[i].mappedProcedures[j]
                guard proc.status == .unmapped else { continue }

                let normalizedTarget = proc.originalName.trimmingCharacters(in: .whitespaces).lowercased()
                guard normalizedTarget != normalizedSource else { continue }
                guard !seen.contains(normalizedTarget) else { continue }

                let confidence = ProcedureLogImporter.calculateConfidence(
                    search: normalizedTarget,
                    target: normalizedSource
                )

                if confidence >= 0.5 {
                    seen.insert(normalizedTarget)
                    results.append(SimilarProcedureMatch(
                        caseIndex: i,
                        procedureIndex: j,
                        originalName: proc.originalName,
                        confidence: confidence
                    ))
                }
            }
        }
        return results.sorted { $0.confidence > $1.confidence }
    }

    private func applySimilarProcedureMappings(selectedOnly: Bool) {
        guard let pending = pendingProcedureMapping else { return }

        for match in similarProcedureMatches {
            if selectedOnly && !match.isSelected { continue }
            let normalizedName = match.originalName.trimmingCharacters(in: .whitespaces).lowercased()
            for i in 0..<importedCases.count {
                for j in 0..<importedCases[i].mappedProcedures.count {
                    let proc = importedCases[i].mappedProcedures[j]
                    if proc.status == .unmapped && proc.originalName.trimmingCharacters(in: .whitespaces).lowercased() == normalizedName {
                        importedCases[i].mappedProcedures[j].matchedTagId = pending.matchedTagId
                        importedCases[i].mappedProcedures[j].matchedTitle = pending.matchedTitle
                        importedCases[i].mappedProcedures[j].matchConfidence = pending.matchConfidence
                        importedCases[i].mappedProcedures[j].status = .mapped
                    }
                }
            }
        }
        showSimilarProceduresSheet = false
        pendingProcedureMapping = nil
    }

    private func confirmMapping() {
        guard let confirmation = mappingConfirmation else { return }
        mappingConfirmation = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if confirmation.type == .procedure, let pending = pendingProcedureMapping {
                let similar = findSimilarUnmappedProcedures(mappedOriginalName: pending.sourceOriginalName)
                if !similar.isEmpty {
                    similarProcedureMatches = similar
                    showSimilarProceduresSheet = true
                } else {
                    pendingProcedureMapping = nil
                }
            }
        }
    }

    private func undoMapping() {
        guard let confirmation = mappingConfirmation else { return }

        if confirmation.type == .procedure, let pending = pendingProcedureMapping {
            let normalizedSource = pending.sourceOriginalName.trimmingCharacters(in: .whitespaces).lowercased()
            for i in 0..<importedCases.count {
                for j in 0..<importedCases[i].mappedProcedures.count {
                    let proc = importedCases[i].mappedProcedures[j]
                    if proc.originalName.trimmingCharacters(in: .whitespaces).lowercased() == normalizedSource && proc.matchedTagId == pending.matchedTagId {
                        importedCases[i].mappedProcedures[j].matchedTagId = nil
                        importedCases[i].mappedProcedures[j].matchedTitle = nil
                        importedCases[i].mappedProcedures[j].matchConfidence = 0
                        importedCases[i].mappedProcedures[j].status = .unmapped
                    }
                }
            }
            pendingProcedureMapping = nil
        }

        mappingConfirmation = nil
    }

    private func processImport() {
        isProcessing = true

        // Extract SwiftData models into Sendable value types on main thread
        let attendingsCopy = attendings.map {
            ImportAttending(id: $0.id, fullName: $0.fullName, firstName: $0.firstName, lastName: $0.lastName, isArchived: $0.isArchived)
        }
        let facilitiesCopy = facilities.map {
            ImportFacility(id: $0.id, name: $0.name, shortName: $0.shortName, isArchived: $0.isArchived)
        }
        let customProcsCopy = customProcedures.map {
            ImportCustomProcedure(tagId: $0.tagId, title: $0.title, category: $0.category)
        }
        let enabledPacksCopy = enabledPacks
        let rowsCopy = dataRows
        let mappingCopy = columnMapping

        // Run import on a GCD thread — NOT Task.detached (cooperative thread pool).
        // The cooperative pool has limited threads and deadlocks when
        // DateFormatter/Locale/ICU initialization blocks waiting on internal
        // dispatch queues backed by the same pool.
        Task {
            let cases: [ImportedCase] = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let result = ProcedureLogImporter.shared.importCases(
                        rows: rowsCopy,
                        mapping: mappingCopy,
                        attendings: attendingsCopy,
                        facilities: facilitiesCopy,
                        enabledPacks: enabledPacksCopy,
                        customProcedures: customProcsCopy
                    )
                    continuation.resume(returning: result)
                }
            }

            importedCases = cases
            importStep = .reviewCases
            isProcessing = false
        }
    }

    /// Process all sheets in the batch import, each with its own column mapping.
    private func processBatchImport() {
        isProcessing = true

        let attendingsCopy = attendings.map {
            ImportAttending(id: $0.id, fullName: $0.fullName, firstName: $0.firstName, lastName: $0.lastName, isArchived: $0.isArchived)
        }
        let facilitiesCopy = facilities.map {
            ImportFacility(id: $0.id, name: $0.name, shortName: $0.shortName, isArchived: $0.isArchived)
        }
        let customProcsCopy = customProcedures.map {
            ImportCustomProcedure(tagId: $0.tagId, title: $0.title, category: $0.category)
        }
        let enabledPacksCopy = enabledPacks
        let sheetDataCopy = sheetImportDataList

        Task {
            let allCases: [ImportedCase] = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    var combined: [ImportedCase] = []
                    for sheetData in sheetDataCopy {
                        let cases = ProcedureLogImporter.shared.importCases(
                            rows: sheetData.rows,
                            mapping: sheetData.columnMapping,
                            attendings: attendingsCopy,
                            facilities: facilitiesCopy,
                            enabledPacks: enabledPacksCopy,
                            customProcedures: customProcsCopy
                        )
                        combined.append(contentsOf: cases)
                    }
                    continuation.resume(returning: combined)
                }
            }

            importedCases = allCases
            // Combine all rows for import history tracking
            dataRows = sheetImportDataList.flatMap { $0.rows }
            importStep = .reviewCases
            isProcessing = false
        }
    }

    /// Get the current user ID - handles both individual and institutional modes
    private var currentUserId: UUID? {
        if appState.isIndividualMode {
            // In individual mode, use the persistent individual user UUID
            if let uuidString = UserDefaults.standard.string(forKey: "individualUserUUID"),
               let uuid = UUID(uuidString: uuidString) {
                return uuid
            }
            // Create one if it doesn't exist
            let newUUID = UUID()
            UserDefaults.standard.set(newUUID.uuidString, forKey: "individualUserUUID")
            return newUUID
        } else {
            // In institutional mode, use current user
            return appState.currentUser?.id
        }
    }

    private func performImport() {
        guard let userId = currentUserId else {
            errorMessage = "No user ID available"
            return
        }

        isProcessing = true

        // Create custom procedures first
        var customProceduresCreated = 0
        let programId = appState.isIndividualMode ? nil : appState.currentUser?.programId

        for i in 0..<importedCases.count {
            for j in 0..<importedCases[i].mappedProcedures.count {
                let mapped = importedCases[i].mappedProcedures[j]
                if mapped.status == .customNew, let category = mapped.customProcedureCategory {
                    // Create custom procedure (use matchedTitle if user renamed it)
                    let customProc = CustomProcedure(
                        title: mapped.matchedTitle ?? mapped.originalName,
                        category: category,
                        programId: programId,
                        creatorId: userId
                    )
                    modelContext.insert(customProc)

                    // Update mapping
                    importedCases[i].mappedProcedures[j].matchedTagId = customProc.tagId
                    importedCases[i].mappedProcedures[j].status = .mapped
                    customProceduresCreated += 1
                }
            }
        }

        // Apply attending mappings from the Map Attendings step
        let attendingsCreated = unmappedAttendingEntries.filter { $0.status == .newlyCreated }.count

        // Ensure all attending mappings are applied to imported cases
        let normalizedMap: [String: MappedAttendingEntry] = Dictionary(
            unmappedAttendingEntries.map { (normalizeAttendingName($0.originalName), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for i in 0..<importedCases.count {
            if importedCases[i].mappedAttendingId == nil,
               let name = importedCases[i].attendingName {
                let normalized = normalizeAttendingName(name)
                if let entry = normalizedMap[normalized], let attendingId = entry.mappedAttendingId {
                    importedCases[i].mappedAttendingId = attendingId
                }
            }
        }

        // Create cases
        let importedCount = ProcedureLogImporter.shared.createCases(
            from: importedCases,
            fellowId: userId,
            programId: programId,
            modelContext: modelContext
        )

        // Log audit entry (only for institutional mode)
        if !appState.isIndividualMode, let user = appState.currentUser {
            AuditService.shared.logDataImported(
                by: user,
                caseCount: importedCount,
                source: selectedFileURL?.lastPathComponent ?? "Unknown file"
            )
        }

        // Trigger badge check for imported cases
        if importedCount > 0 {
            let allCases = (try? modelContext.fetch(FetchDescriptor<CaseEntry>())) ?? []
            let fellowCases = allCases.filter { $0.ownerId == userId || $0.fellowId == userId }
            let existingBadges = (try? modelContext.fetch(FetchDescriptor<BadgeEarned>())) ?? []
            let fellowBadges = existingBadges.filter { $0.fellowId == userId }

            if let lastCase = fellowCases.last {
                let _ = BadgeService.shared.checkAndAwardBadges(
                    for: userId,
                    attestedCase: lastCase,
                    allCases: fellowCases,
                    existingBadges: fellowBadges,
                    modelContext: modelContext
                )
            }
        }

        let skippedCount = importedCases.count - importedCases.filter { $0.isFullyMapped }.count

        importResult = ImportResult(
            totalRows: dataRows.count,
            importedCount: importedCount,
            skippedCount: skippedCount,
            customProceduresCreated: customProceduresCreated,
            attendingsCreated: attendingsCreated
        )

        // Record this import in history to detect re-imports
        if let fileName = selectedFileURL?.lastPathComponent {
            recordImport(fileName: fileName, rowCount: dataRows.count)
        }

        importStep = .complete
        isProcessing = false
    }
}

// MARK: - Extension for ImportStep

extension ImportProcedureLogView.ImportStep: Comparable {
    var rawValue: Int {
        switch self {
        case .selectFile: return 0
        case .mapColumns: return 1
        case .reviewCases: return 2
        case .mapAttendings: return 3
        case .mapRoles: return 4
        case .mapFacilities: return 5
        case .mapProcedures: return 6
        case .mergeCases: return 7
        case .confirm: return 8
        case .complete: return 9
        }
    }

    static func < (lhs: ImportProcedureLogView.ImportStep, rhs: ImportProcedureLogView.ImportStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Imported Case Row

// MARK: - Batch Sheet Row

struct BatchSheetRow: View {
    @Binding var mapping: SheetProcedureMapping
    let enabledPacks: [SpecialtyPack]
    let customProcedures: [CustomProcedure]

    @State private var showingProcedureSearch = false
    @State private var showingCreateCustom = false
    @State private var searchText = ""
    @State private var expandedPackIds: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $mapping.isSelected) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mapping.sheetName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if mapping.mappedProcedure.status == .mapped,
                       let title = mapping.mappedProcedure.matchedTitle {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                            Text(title)
                                .font(.caption)
                                .foregroundStyle(ProcedusTheme.success)
                            if mapping.mappedProcedure.matchConfidence < 1.0 {
                                Text("(\(Int(mapping.mappedProcedure.matchConfidence * 100))%)")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    } else {
                        Text("No procedure matched — tap to select")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.warning)
                    }
                }
            }
            .tint(ProcedusTheme.primary)

            if mapping.isSelected {
                HStack(spacing: 8) {
                    Button {
                        showingProcedureSearch = true
                    } label: {
                        Label(
                            mapping.mappedProcedure.status == .mapped ? "Change" : "Search",
                            systemImage: "magnifyingglass"
                        )
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(ProcedusTheme.primary.opacity(0.12))
                        .foregroundStyle(ProcedusTheme.primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingCreateCustom = true
                    } label: {
                        Label("Create", systemImage: "plus.circle")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(ProcedusTheme.accent.opacity(0.12))
                            .foregroundStyle(ProcedusTheme.accent)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingProcedureSearch) {
            batchProcedureSearchSheet
        }
        .sheet(isPresented: $showingCreateCustom) {
            AddCustomProcedureSheet(
                defaultTitle: mapping.sheetName,
                onCreated: { newProcedure in
                    mapping.mappedProcedure.matchedTagId = newProcedure.tagId
                    mapping.mappedProcedure.matchedTitle = newProcedure.title
                    mapping.mappedProcedure.matchConfidence = 1.0
                    mapping.mappedProcedure.status = .mapped
                }
            )
        }
    }

    // MARK: - Procedure Search Sheet

    private var batchProcedureSearchSheet: some View {
        NavigationStack {
            List {
                ForEach(enabledPacks, id: \.id) { pack in
                    let filteredCats = filteredCategories(in: pack)
                    if !filteredCats.isEmpty {
                        Section {
                            ForEach(filteredCats, id: \.category.id) { item in
                                DisclosureGroup(
                                    isExpanded: Binding(
                                        get: { expandedPackIds.contains("\(pack.id)-\(item.category.id)") },
                                        set: { val in
                                            if val { expandedPackIds.insert("\(pack.id)-\(item.category.id)") }
                                            else { expandedPackIds.remove("\(pack.id)-\(item.category.id)") }
                                        }
                                    )
                                ) {
                                    ForEach(item.procedures, id: \.id) { procedure in
                                        Button {
                                            selectProcedure(id: procedure.id, title: procedure.title)
                                        } label: {
                                            Text(procedure.title)
                                                .font(.subheadline)
                                                .foregroundColor(Color(UIColor.label))
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    // Custom procedures in this category
                                    ForEach(customProcedures.filter { $0.category == item.category.category }) { custom in
                                        Button {
                                            selectProcedure(id: custom.tagId, title: custom.title)
                                        } label: {
                                            HStack {
                                                Text(custom.title)
                                                    .font(.subheadline)
                                                    .foregroundColor(Color(UIColor.label))
                                                Text("(Custom)")
                                                    .font(.caption)
                                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } label: {
                                    Text(item.category.category.rawValue)
                                        .font(.subheadline)
                                }
                            }
                        } header: {
                            Text(pack.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search procedures")
            .navigationTitle("Select Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingProcedureSearch = false }
                }
            }
        }
    }

    private func selectProcedure(id: String, title: String) {
        mapping.mappedProcedure.matchedTagId = id
        mapping.mappedProcedure.matchedTitle = title
        mapping.mappedProcedure.matchConfidence = 1.0
        mapping.mappedProcedure.status = .mapped
        showingProcedureSearch = false
    }

    private func filteredCategories(in pack: SpecialtyPack) -> [(category: PackCategory, procedures: [ProcedureTag])] {
        if searchText.isEmpty {
            return pack.categories.map { ($0, $0.procedures) }
        }
        let lowered = searchText.lowercased()
        return pack.categories.compactMap { category in
            let filtered = category.procedures.filter { $0.title.lowercased().contains(lowered) }
            let customMatches = customProcedures.filter {
                $0.category == category.category && $0.title.lowercased().contains(lowered)
            }
            return (filtered.isEmpty && customMatches.isEmpty) ? nil : (category, filtered)
        }
    }
}

// MARK: - Imported Case Row

struct ImportedCaseRow: View {
    let importedCase: ImportedCase

    /// Noninvasive cases (all mapped procedures are ci-) don't require an attending
    private var isNoninvasive: Bool {
        !importedCase.mappedProcedures.isEmpty &&
        importedCase.mappedProcedures.allSatisfy { $0.matchedTagId?.hasPrefix("ci-") == true }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(importedCase.weekBucket.toWeekTimeframeLabel())
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if importedCase.isFullyMapped {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ProcedusTheme.success)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(ProcedusTheme.warning)
                }
            }

            // Attending + procedure bubbles
            HStack(spacing: 6) {
                if let att = importedCase.attendingName {
                    if isNoninvasive {
                        Label(att, systemImage: importedCase.mappedAttendingId != nil ? "checkmark" : "minus")
                            .font(.caption2)
                            .foregroundStyle(importedCase.mappedAttendingId != nil ? ProcedusTheme.success : ProcedusTheme.textTertiary)
                    } else {
                        Label(att, systemImage: importedCase.mappedAttendingId != nil ? "checkmark" : "questionmark")
                            .font(.caption2)
                            .foregroundStyle(importedCase.mappedAttendingId != nil ? ProcedusTheme.success : ProcedusTheme.warning)
                    }
                }

                // Procedure bubbles
                ForEach(importedCase.mappedProcedures) { proc in
                    Text(proc.matchedTitle ?? proc.originalName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (proc.status == .mapped ? ProcedusTheme.primary : ProcedusTheme.warning)
                                .opacity(0.15)
                        )
                        .foregroundStyle(proc.status == .mapped ? ProcedusTheme.primary : ProcedusTheme.warning)
                        .clipShape(Capsule())
                }
            }

            if let fac = importedCase.facilityName {
                Label(fac, systemImage: importedCase.mappedFacilityId != nil ? "checkmark" : "questionmark")
                    .font(.caption2)
                    .foregroundStyle(importedCase.mappedFacilityId != nil ? ProcedusTheme.success : ProcedusTheme.warning)
            }

            if importedCase.unmappedProcedureCount > 0 {
                Text("\(importedCase.unmappedProcedureCount) procedure(s) need mapping")
                    .font(.caption2)
                    .foregroundStyle(ProcedusTheme.warning)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Procedure Mapping Row

struct ProcedureMappingRow: View {
    @Binding var mappedProcedure: MappedProcedure
    let enabledPacks: [SpecialtyPack]
    let customProcedures: [CustomProcedure]
    var onProcedureMapped: ((String, String, String, Double) -> Void)?

    // Single sheet enum to avoid multiple .sheet modifiers
    enum ActiveSheet: String, Identifiable {
        case search
        case createCustom
        var id: String { rawValue }
    }

    @State private var activeSheet: ActiveSheet?
    @State private var searchText = ""
    @State private var expandedPackIds: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Original name with status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mappedProcedure.originalName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if mappedProcedure.status == .mapped, let title = mappedProcedure.matchedTitle {
                        Text("→ \(title)")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.success)
                    }
                }
                Spacer()
                statusBadge
            }

            // Confidence indicator for mapped items
            if mappedProcedure.status == .mapped && mappedProcedure.matchConfidence < 1.0 {
                HStack(spacing: 4) {
                    confidenceIndicator(mappedProcedure.matchConfidence)
                    Text("Confidence: \(Int(mappedProcedure.matchConfidence * 100))%")
                        .font(.caption2)
                        .foregroundStyle(confidenceColor(mappedProcedure.matchConfidence))
                    if mappedProcedure.matchConfidence < 0.8 {
                        Text("- Please verify")
                            .font(.caption2)
                            .foregroundStyle(ProcedusTheme.warning)
                    }
                }
            }

            // Suggestions
            if mappedProcedure.status == .unmapped && !mappedProcedure.suggestedMatches.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggested matches:")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)

                    ForEach(mappedProcedure.suggestedMatches) { suggestion in
                        Button {
                            selectSuggestion(suggestion)
                        } label: {
                            HStack {
                                CategoryBubble(category: suggestion.category, size: 20)
                                Text(suggestion.title)
                                    .font(.caption)
                                Spacer()
                                confidenceIndicator(suggestion.confidence)
                                Text("\(Int(suggestion.confidence * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(confidenceColor(suggestion.confidence))
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(ProcedusTheme.primary)
                                    .font(.system(size: 18))
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(ProcedusTheme.cardBackground)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Actions
            HStack(spacing: 10) {
                Button {
                    activeSheet = .search
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(ProcedusTheme.primary.opacity(0.12))
                        .foregroundStyle(ProcedusTheme.primary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    activeSheet = .createCustom
                } label: {
                    Label("Create", systemImage: "plus.circle")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(ProcedusTheme.accent.opacity(0.12))
                        .foregroundStyle(ProcedusTheme.accent)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    mappedProcedure.status = .skipped
                } label: {
                    Label("Skip", systemImage: "forward")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(ProcedusTheme.textTertiary.opacity(0.12))
                        .foregroundStyle(ProcedusTheme.textSecondary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .search:
                searchProceduresSheet
            case .createCustom:
                AddCustomProcedureSheet(
                    defaultTitle: mappedProcedure.originalName,
                    onCreated: { newProcedure in
                        mappedProcedure.matchedTagId = newProcedure.tagId
                        mappedProcedure.matchedTitle = newProcedure.title
                        mappedProcedure.matchConfidence = 1.0
                        mappedProcedure.status = .mapped
                        onProcedureMapped?(mappedProcedure.originalName, newProcedure.tagId, newProcedure.title, 1.0)
                    }
                )
            }
        }
    }

    private var statusBadge: some View {
        Group {
            switch mappedProcedure.status {
            case .mapped:
                Label("Mapped", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(ProcedusTheme.success)
            case .unmapped:
                Label("Unmapped", systemImage: "questionmark.circle.fill")
                    .foregroundStyle(ProcedusTheme.warning)
            case .customNew:
                Label("New Custom", systemImage: "plus.circle.fill")
                    .foregroundStyle(ProcedusTheme.accent)
            case .skipped:
                Label("Skipped", systemImage: "forward.fill")
                    .foregroundStyle(ProcedusTheme.textTertiary)
            }
        }
        .font(.caption2)
    }

    private func confidenceIndicator(_ confidence: Double) -> some View {
        Circle()
            .fill(confidenceColor(confidence))
            .frame(width: 8, height: 8)
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.9 { return ProcedusTheme.success }
        if confidence >= 0.7 { return .orange }
        if confidence >= 0.5 { return .yellow }
        return ProcedusTheme.error
    }

    private func selectSuggestion(_ suggestion: ProcedureSuggestion) {
        mappedProcedure.matchedTagId = suggestion.tagId
        mappedProcedure.matchedTitle = suggestion.title
        mappedProcedure.matchConfidence = suggestion.confidence
        mappedProcedure.status = .mapped
        onProcedureMapped?(mappedProcedure.originalName, suggestion.tagId, suggestion.title, suggestion.confidence)
    }

    // MARK: - Search Procedures Sheet (mirrors add/edit case procedure selection)

    private var searchProceduresSheet: some View {
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
                                    // Pack procedures
                                    ForEach(item.procedures, id: \.id) { procedure in
                                        Button {
                                            mappedProcedure.matchedTagId = procedure.id
                                            mappedProcedure.matchedTitle = procedure.title
                                            mappedProcedure.matchConfidence = 1.0
                                            mappedProcedure.status = .mapped
                                            activeSheet = nil
                                            onProcedureMapped?(mappedProcedure.originalName, procedure.id, procedure.title, 1.0)
                                        } label: {
                                            HStack {
                                                Text(procedure.title)
                                                    .font(.subheadline)
                                                    .foregroundColor(Color(UIColor.label))
                                                Spacer()
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    // Fellow custom procedures in this category
                                    let customForCategory = customProcedures.filter { $0.category == item.category.category }
                                    ForEach(customForCategory) { custom in
                                        Button {
                                            mappedProcedure.matchedTagId = custom.tagId
                                            mappedProcedure.matchedTitle = custom.title
                                            mappedProcedure.matchConfidence = 1.0
                                            mappedProcedure.status = .mapped
                                            activeSheet = nil
                                            onProcedureMapped?(mappedProcedure.originalName, custom.tagId, custom.title, 1.0)
                                        } label: {
                                            HStack {
                                                Text(custom.title)
                                                    .font(.subheadline)
                                                    .foregroundColor(Color(UIColor.label))
                                                Text("(My Custom)")
                                                    .font(.caption)
                                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                                                Spacer()
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        CategoryBubble(category: item.category.category, size: 20)
                                        Text(item.category.category.rawValue)
                                            .font(.subheadline)
                                            .foregroundColor(Color(UIColor.label))
                                    }
                                }
                            }
                        } header: {
                            Text(pack.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }

                    // Show custom procedures not covered by any pack category
                    let packCategoryRawValues = Set(enabledPacks.flatMap { $0.categories.map { $0.category.rawValue } })
                    let uncategorizedCustom = customProcedures.filter { !packCategoryRawValues.contains($0.categoryRaw) }

                    if !uncategorizedCustom.isEmpty {
                        Section {
                            ForEach(uncategorizedCustom) { custom in
                                Button {
                                    mappedProcedure.matchedTagId = custom.tagId
                                    mappedProcedure.matchedTitle = custom.title
                                    mappedProcedure.matchConfidence = 1.0
                                    mappedProcedure.status = .mapped
                                    activeSheet = nil
                                    onProcedureMapped?(mappedProcedure.originalName, custom.tagId, custom.title, 1.0)
                                } label: {
                                    HStack {
                                        CategoryBubble(category: custom.category, size: 20)
                                        Text(custom.title)
                                            .font(.subheadline)
                                            .foregroundColor(Color(UIColor.label))
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text("Custom Procedures")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search procedures")
            .navigationTitle("Select Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { activeSheet = nil }
                }
            }
        }
    }

    /// Filter procedures by search text within a pack
    private func filteredProcedures(in pack: SpecialtyPack) -> [(category: PackCategory, procedures: [ProcedureTag])] {
        if searchText.isEmpty {
            return pack.categories.map { ($0, $0.procedures) }
        }
        let lowercased = searchText.lowercased()
        return pack.categories.compactMap { category in
            let filtered = category.procedures.filter {
                $0.title.lowercased().contains(lowercased)
            }
            let customMatches = customProcedures.filter {
                $0.category == category.category && $0.title.lowercased().contains(lowercased)
            }
            return (filtered.isEmpty && customMatches.isEmpty) ? nil : (category, filtered)
        }
    }
}

// MARK: - Attending Mapping Models

enum AttendingMappingStatus {
    case unmapped
    case mapped
    case newlyCreated
    case skipped
}

struct MappedAttendingEntry: Identifiable {
    let id = UUID()
    let originalName: String
    var mappedAttendingId: UUID?
    var mappedAttendingName: String?
    var status: AttendingMappingStatus
}

// MARK: - Fuzzy Matching Models

struct SimilarProcedureMatch: Identifiable {
    let id = UUID()
    let caseIndex: Int
    let procedureIndex: Int
    let originalName: String
    let confidence: Double
    var isSelected: Bool = true
}

struct PendingProcedureMapping {
    let sourceOriginalName: String
    let matchedTagId: String
    let matchedTitle: String
    let matchConfidence: Double
}

// MARK: - Mapping Confirmation

struct MappingConfirmationData: Identifiable {
    let id = UUID()
    let type: MappingConfirmationType
    let originalName: String
    let mappedName: String
    let attendingId: UUID?
    let attendingStatus: AttendingMappingStatus?
    let matchedTagId: String?
    let matchConfidence: Double?
}

enum MappingConfirmationType {
    case attending
    case procedure
}

// MARK: - Import History

struct ImportHistoryEntry: Codable {
    let fileName: String
    let rowCount: Int
    let importDate: Date
}

// MARK: - Attending Checklist Entry

struct AttendingChecklistEntry: Identifiable {
    let id = UUID()
    let originalName: String
    var addAsNew: Bool = true
    var existingAttendingId: UUID?
    var existingAttendingName: String?
    var caseCount: Int
    var defaultFirstName: String
    var defaultLastName: String
}
