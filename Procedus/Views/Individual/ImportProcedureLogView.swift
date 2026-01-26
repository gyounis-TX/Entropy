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
    
    enum ImportStep {
        case selectFile
        case mapColumns
        case reviewCases
        case mapProcedures
        case confirm
        case complete
    }
    
    struct ImportResult {
        let totalRows: Int
        let importedCount: Int
        let skippedCount: Int
        let customProceduresCreated: Int
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
                case .mapProcedures:
                    mapProceduresView
                case .confirm:
                    confirmView
                case .complete:
                    completeView
                }
            }
            .navigationTitle("Import Procedure Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
        }
    }
    
    // MARK: - Progress View
    
    private var importProgressView: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                let stepColors: [Color] = [
                    importStep.rawValue >= 0 ? ProcedusTheme.primary : ProcedusTheme.textTertiary,
                    importStep.rawValue >= 1 ? ProcedusTheme.primary : ProcedusTheme.textTertiary,
                    importStep.rawValue >= 2 ? ProcedusTheme.primary : ProcedusTheme.textTertiary,
                    importStep.rawValue >= 3 ? ProcedusTheme.primary : ProcedusTheme.textTertiary,
                    importStep.rawValue >= 4 ? ProcedusTheme.primary : ProcedusTheme.textTertiary,
                ]
                Capsule()
                    .fill(stepColors[index])
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
                }
                .padding()
                .background(ProcedusTheme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal, 32)

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

            // Data preview
            Section("Data Preview") {
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Headers row
                        HStack(spacing: 12) {
                            ForEach(0..<headers.count, id: \.self) { i in
                                Text(headers[i])
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .frame(minWidth: 80, alignment: .leading)
                            }
                        }
                        Divider()
                        // First 3 data rows
                        ForEach(0..<min(3, dataRows.count), id: \.self) { rowIdx in
                            HStack(spacing: 12) {
                                ForEach(0..<headers.count, id: \.self) { colIdx in
                                    Text(colIdx < dataRows[rowIdx].count ? dataRows[rowIdx][colIdx] : "")
                                        .font(.caption2)
                                        .frame(minWidth: 80, alignment: .leading)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Required") {
                columnPicker(title: "Procedures", selection: $columnMapping.proceduresColumn, required: true)
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
                columnPicker(title: "Category/Specialty", selection: $columnMapping.categoryColumn, required: false)
                columnPicker(title: "Diagnosis", selection: $columnMapping.diagnosisColumn, required: false)
                columnPicker(title: "Operator Role", selection: $columnMapping.roleColumn, required: false)
                columnPicker(title: "Notes", selection: $columnMapping.notesColumn, required: false)
            }

            Section("Procedure Delimiter") {
                Picker("Procedures separated by", selection: $columnMapping.procedureDelimiter) {
                    Text("Semicolon (;)").tag(";")
                    Text("Comma (,)").tag(",")
                    Text("Pipe (|)").tag("|")
                    Text("Newline").tag("\n")
                }
            }

            Section {
                Button {
                    processImport()
                } label: {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!isColumnMappingValid || isProcessing)
            }
        }
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
        columnMapping.proceduresColumn != nil
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
                let hasUnmapped = importedCases.contains { $0.unmappedProcedureCount > 0 }
                importStep = hasUnmapped ? .mapProcedures : .confirm
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
    
    // MARK: - Step 4: Map Procedures
    
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
                            ProcedureMappingRow(mappedProcedure: $mappedProcedure)
                        }
                    }
                }
            }
            .listStyle(.plain)
            
            Button {
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
    
    // MARK: - Step 5: Confirm
    
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
            
            Spacer()
        }
    }
    
    // MARK: - Step 6: Complete
    
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
                    if result.skippedCount > 0 {
                        Text("\(result.skippedCount) cases skipped")
                            .foregroundStyle(ProcedusTheme.textSecondary)
                    }
                }
                .font(.subheadline)
            }
            
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

        defer { url.stopAccessingSecurityScopedResource() }

        // Check for summary export before parsing
        if let content = try? String(contentsOf: url, encoding: .utf8),
           ProcedureLogImporter.shared.isSummaryExport(content) {
            errorMessage = "This file contains procedure counts/summary data, not individual case entries. Please export the full Procedure Log instead."
            isProcessing = false
            return
        }

        guard let parseResult = ProcedureLogImporter.shared.parseFile(at: url) else {
            errorMessage = "Failed to parse file"
            isProcessing = false
            return
        }
        let (parsedHeaders, parsedRows) = parseResult

        guard !parsedHeaders.isEmpty else {
            errorMessage = "The file appears to be empty or has no headers"
            isProcessing = false
            return
        }

        headers = parsedHeaders
        dataRows = parsedRows

        // Auto-detect columns
        columnMapping = ProcedureLogImporter.shared.autoDetectColumns(headers: headers)

        importStep = .mapColumns
        isProcessing = false
    }
    
    private func processImport() {
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let cases = ProcedureLogImporter.shared.importCases(
                rows: dataRows,
                mapping: columnMapping,
                attendings: Array(attendings),
                facilities: Array(facilities)
            )
            
            DispatchQueue.main.async {
                importedCases = cases
                importStep = .reviewCases
                isProcessing = false
            }
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
                    // Create custom procedure
                    let customProc = CustomProcedure(
                        title: mapped.originalName,
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

        let skippedCount = importedCases.count - importedCases.filter { $0.isFullyMapped }.count

        importResult = ImportResult(
            totalRows: dataRows.count,
            importedCount: importedCount,
            skippedCount: skippedCount,
            customProceduresCreated: customProceduresCreated
        )

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
        case .mapProcedures: return 3
        case .confirm: return 4
        case .complete: return 5
        }
    }
    
    static func < (lhs: ImportProcedureLogView.ImportStep, rhs: ImportProcedureLogView.ImportStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Imported Case Row

struct ImportedCaseRow: View {
    let importedCase: ImportedCase
    
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
            
            // Procedures
            Text(importedCase.procedureNames.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .lineLimit(2)
            
            HStack {
                if let att = importedCase.attendingName {
                    Label(att, systemImage: importedCase.mappedAttendingId != nil ? "checkmark" : "questionmark")
                        .font(.caption2)
                        .foregroundStyle(importedCase.mappedAttendingId != nil ? ProcedusTheme.success : ProcedusTheme.warning)
                }
                
                if let fac = importedCase.facilityName {
                    Label(fac, systemImage: importedCase.mappedFacilityId != nil ? "checkmark" : "questionmark")
                        .font(.caption2)
                        .foregroundStyle(importedCase.mappedFacilityId != nil ? ProcedusTheme.success : ProcedusTheme.warning)
                }
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
    @State private var showingCategoryPicker = false
    @State private var showingManualSearch = false
    @State private var selectedCategory: ProcedureCategory = .other
    @State private var searchText = ""

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
            HStack {
                Button {
                    showingManualSearch = true
                } label: {
                    Label("Search Procedures", systemImage: "magnifyingglass")
                        .font(.caption)
                }

                Button {
                    showingCategoryPicker = true
                } label: {
                    Label("Create Custom", systemImage: "plus.circle")
                        .font(.caption)
                }

                Spacer()

                Button {
                    mappedProcedure.status = .skipped
                } label: {
                    Label("Skip", systemImage: "forward")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingCategoryPicker) {
            categoryPickerSheet
        }
        .sheet(isPresented: $showingManualSearch) {
            manualSearchSheet
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
    }

    // MARK: - Manual Search Sheet

    private var manualSearchSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ProcedusTheme.textSecondary)
                    TextField("Search procedures...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(ProcedusTheme.textTertiary)
                        }
                    }
                }
                .padding()
                .background(ProcedusTheme.cardBackground)

                // Results
                List {
                    ForEach(filteredProcedures, id: \.id) { procedure in
                        Button {
                            selectProcedure(procedure)
                        } label: {
                            HStack {
                                CategoryBubble(category: procedure.category, size: 24)
                                VStack(alignment: .leading) {
                                    Text(procedure.title)
                                        .font(.subheadline)
                                    Text(procedure.packName)
                                        .font(.caption)
                                        .foregroundStyle(ProcedusTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(ProcedusTheme.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingManualSearch = false }
                }
            }
        }
    }

    private var filteredProcedures: [SearchableProcedure] {
        var results: [SearchableProcedure] = []
        let searchLower = searchText.lowercased()

        for pack in SpecialtyPackCatalog.allPacks {
            for category in pack.categories {
                for procedure in category.procedures {
                    if searchText.isEmpty || procedure.title.lowercased().contains(searchLower) {
                        results.append(SearchableProcedure(
                            id: procedure.id,
                            title: procedure.title,
                            category: category.category,
                            packName: pack.name
                        ))
                    }
                }
            }
        }

        return results.sorted { $0.title < $1.title }
    }

    private func selectProcedure(_ procedure: SearchableProcedure) {
        mappedProcedure.matchedTagId = procedure.id
        mappedProcedure.matchedTitle = procedure.title
        mappedProcedure.matchConfidence = 1.0
        mappedProcedure.status = .mapped
        showingManualSearch = false
    }

    private var categoryPickerSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Create \"\(mappedProcedure.originalName)\" as a custom procedure")
                        .font(.subheadline)
                }

                Section("Select Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ProcedureCategory.allCases) { category in
                            HStack {
                                CategoryBubble(category: category, size: 20)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Create Custom Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingCategoryPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        mappedProcedure.customProcedureCategory = selectedCategory
                        mappedProcedure.status = .customNew
                        showingCategoryPicker = false
                    }
                }
            }
        }
    }
}

// Helper struct for manual search
struct SearchableProcedure: Identifiable {
    let id: String
    let title: String
    let category: ProcedureCategory
    let packName: String
}
