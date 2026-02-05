// ProcedureLogImporter.swift
// Procedus - Unified
// Import existing procedure logs from Excel/CSV with intelligent mapping
// NOTE: Uses MappingStatus from Enums.swift

import Foundation
import SwiftData
import CoreXLSX

// MARK: - Import Models

struct ImportedCase: Identifiable {
    let id = UUID()
    var date: Date?
    var weekBucket: String
    var attendingName: String?
    var facilityName: String?
    var procedureNames: [String]
    var accessSites: [String]
    var complications: [String]
    var outcome: String?
    var notes: String?
    var operatorRole: String?
    var patientIdentifier: String?
    var patientAge: String?

    // Mapping results
    var mappedAttendingId: UUID?
    var mappedFacilityId: UUID?
    var mappedProcedures: [MappedProcedure] = []
    var mappedAccessSites: [String] = []
    var mappedComplications: [String] = []
    var mappedOutcome: CaseOutcome = .success
    var mappedOperatorPosition: OperatorPosition?
    
    var isFullyMapped: Bool {
        !mappedProcedures.isEmpty &&
        mappedProcedures.allSatisfy { $0.status != MappingStatus.unmapped }
    }
    
    var unmappedProcedureCount: Int {
        mappedProcedures.filter { $0.status == MappingStatus.unmapped }.count
    }
}

struct MappedProcedure: Identifiable {
    let id = UUID()
    let originalName: String
    var status: MappingStatus
    var matchedTagId: String?
    var matchedTitle: String?
    var matchConfidence: Double
    var suggestedMatches: [ProcedureSuggestion]
    var customProcedureCategory: ProcedureCategory?
    
    init(
        originalName: String,
        status: MappingStatus,
        matchedTagId: String? = nil,
        matchedTitle: String? = nil,
        matchConfidence: Double = 0,
        suggestedMatches: [ProcedureSuggestion] = [],
        customProcedureCategory: ProcedureCategory? = nil
    ) {
        self.originalName = originalName
        self.status = status
        self.matchedTagId = matchedTagId
        self.matchedTitle = matchedTitle
        self.matchConfidence = matchConfidence
        self.suggestedMatches = suggestedMatches
        self.customProcedureCategory = customProcedureCategory
    }
}

struct ProcedureSuggestion: Identifiable {
    let id = UUID()
    let tagId: String
    let title: String
    let category: ProcedureCategory
    let confidence: Double
}

/// Lightweight value types for import (avoids SwiftData actor issues in background tasks)
struct ImportCustomProcedure: Sendable {
    let tagId: String
    let title: String
    let category: ProcedureCategory
}

struct ImportAttending: Sendable {
    let id: UUID
    let fullName: String
    let firstName: String
    let lastName: String
    let isArchived: Bool
}

struct ImportFacility: Sendable {
    let id: UUID
    let name: String
    let shortName: String?
    let isArchived: Bool
}

// NOTE: MappingStatus is defined in Enums.swift - DO NOT redeclare here

// MARK: - Column Mapping

struct ColumnMapping {
    var dateColumn: Int?
    var attendingColumn: Int?
    var facilityColumn: Int?
    var proceduresColumn: Int?
    var accessSitesColumn: Int?
    var complicationsColumn: Int?
    var outcomeColumn: Int?
    var notesColumn: Int?
    var roleColumn: Int?
    var patientColumn: Int?
    var ageColumn: Int?

    var procedureDelimiter: String = ";"

    /// When true, all rows in this import use the sheet name as their procedure
    /// (e.g., the Excel file has one sheet per procedure type).
    var useSheetNameAsProcedure: Bool = false

    /// The sheet name to use as the procedure name (set when a named sheet is imported).
    var sheetProcedureName: String?

    /// The catalog tag ID for the sheet procedure (set in batch import to bypass fuzzy matching).
    var sheetProcedureTagId: String?
}

// MARK: - Batch Sheet Import

/// Represents a single sheet in the batch multi-sheet import flow.
struct SheetProcedureMapping: Identifiable {
    let id = UUID()
    let sheetName: String
    var isSelected: Bool = true
    var mappedProcedure: MappedProcedure
}

/// Holds parsed data and column mapping for a single sheet in per-sheet batch import.
struct SheetImportData: Identifiable {
    let id = UUID()
    let sheetName: String
    let procedureName: String
    let procedureTagId: String?
    var headers: [String]
    var rows: [[String]]
    var columnMapping: ColumnMapping
}

// MARK: - Role Mapping Models

struct MappedRoleEntry: Identifiable {
    let id = UUID()
    let originalValue: String
    var mappedPosition: OperatorPosition?
    var caseCount: Int
}

// MARK: - Facility Mapping Models

enum FacilityMappingStatus {
    case unmapped, mapped, newlyCreated, skipped
}

struct MappedFacilityEntry: Identifiable {
    let id = UUID()
    let originalName: String
    var mappedFacilityId: UUID?
    var mappedFacilityName: String?
    var status: FacilityMappingStatus
    var caseCount: Int
}

enum FacilityMappingMode: String, CaseIterable, Identifiable {
    case bulk = "All Cases"
    case perAttending = "Per Attending"
    case perProcedure = "Per Procedure"
    case perCase = "Per Case"
    var id: String { rawValue }
}

// MARK: - Merge Group Models

struct MergeGroup: Identifiable {
    let id = UUID()
    let groupLabel: String
    var caseIndices: [Int]
    var shouldMerge: Bool = true
}

// MARK: - Procedure Log Importer

class ProcedureLogImporter {
    static let shared = ProcedureLogImporter()
    private init() {}

    // MARK: - Week Bucket Helper
    // Duplicated from CaseEntry.makeWeekBucket to avoid calling @MainActor-isolated
    // @Model methods from background threads during import.
    private static func makeWeekBucket(for date: Date) -> String {
        let calendar = Calendar(identifier: .iso8601)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%d-W%02d", year, week)
    }

    // Common procedure aliases for fuzzy matching
    private let procedureAliases: [String: String] = [
        "LHC": "Left Heart Catheterization",
        "RHC": "Right Heart Catheterization",
        "PCI": "Coronary Stent",
        "PTCA": "Percutaneous Transluminal Coronary Angioplasty",
        "CABG": "Coronary Artery Bypass Graft",
        "TAVR": "Transcatheter Aortic Valve Replacement",
        "TAVI": "Transcatheter Aortic Valve Implantation",
        "MitraClip": "MitraClip Procedure",
        "WATCHMAN": "WATCHMAN Left Atrial Appendage Closure",
        "ICD": "ICD Implantation",
        "PPM": "Permanent Pacemaker Implantation",
        "CRT": "Cardiac Resynchronization Therapy",
        "CRT-D": "CRT with Defibrillator",
        "CRT-P": "CRT Pacemaker",
        "EP Study": "Electrophysiology Study",
        "EPS": "Electrophysiology Study",
        "AFib Ablation": "Atrial Fibrillation Ablation",
        "AF Ablation": "Atrial Fibrillation Ablation",
        "VT Ablation": "Ventricular Tachycardia Ablation",
        "SVT Ablation": "Supraventricular Tachycardia Ablation",
        "TEE": "Transesophageal Echocardiogram",
        "TTE": "Transthoracic Echocardiogram",
        "Stress Echo": "Stress Echocardiogram",
        "PFO Closure": "Patent Foramen Ovale Closure",
        "ASD Closure": "Atrial Septal Defect Closure",
        "FFR": "Fractional Flow Reserve",
        "IVUS": "Intravascular Ultrasound",
        "OCT": "Optical Coherence Tomography",
        "Rotablation": "Rotational Atherectomy",
        "OA": "Orbital Atherectomy",
        "IVC FILTER": "IVC Filter Placement",
        "IVC": "IVC Filter Placement",
        "EKOS": "PE CDT/Thrombectomy",
        "IVL": "Intravascular Lithotripsy",
        "Shockwave": "Intravascular Lithotripsy",
        "IABP": "Intra-Aortic Balloon Pump",
        "Impella": "Impella Mechanical Support",
        "ECMO": "Extracorporeal Membrane Oxygenation",
        "Swan": "Swan-Ganz Catheter",
        "PA Cath": "Pulmonary Artery Catheterization",
    ]
    
    // MARK: - File Parsing

    /// Detect whether the file is a summary/counts export (not individual cases)
    func isSummaryExport(_ content: String) -> Bool {
        let lower = content.lowercased()
        return lower.contains("procedure counts") && lower.contains("category,procedure,count")
    }

    /// Check if the file at URL is an xlsx file (binary check)
    func isXLSXFile(at url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ext == "xlsx" { return true }

        // Also check file signature (PK ZIP header for xlsx)
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4) else { return false }
        // ZIP file signature: 0x50 0x4B 0x03 0x04
        return data.count >= 4 && data[0] == 0x50 && data[1] == 0x4B && data[2] == 0x03 && data[3] == 0x04
    }

    func parseFile(at url: URL, sheetName: String? = nil) -> (headers: [String], rows: [[String]])? {
        // Check if this is an xlsx file
        if isXLSXFile(at: url) {
            return parseXLSXFile(at: url, sheetName: sheetName)
        }

        // Otherwise treat as CSV/text file
        return parseCSVFile(at: url)
    }

    /// Parse file from Data - used when security-scoped resource access requires reading data on main thread
    /// - Parameters:
    ///   - data: The file data
    ///   - isXLSX: Whether the file is an XLSX file (vs CSV/text)
    ///   - sheetName: Optional sheet name for XLSX files
    func parseFileFromData(_ data: Data, isXLSX: Bool, sheetName: String? = nil) -> (headers: [String], rows: [[String]])? {
        if isXLSX {
            return parseXLSXFromData(data, sheetName: sheetName)
        }

        // CSV/text file
        guard let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        return parseCSVContent(content)
    }

    // MARK: - XLSX Parsing

    /// Get the list of sheet names from an XLSX file
    func getSheetNames(at url: URL) -> [String]? {
        guard let xlsxFile = XLSXFile(filepath: url.path) else {
            return nil
        }
        return getSheetNamesFromXLSX(xlsxFile)
    }

    /// Get the list of sheet names from XLSX file data (for use with security-scoped resources)
    func getSheetNamesFromData(_ data: Data) -> [String]? {
        guard let xlsxFile = try? XLSXFile(data: data) else {
            return nil
        }
        return getSheetNamesFromXLSX(xlsxFile)
    }

    /// Internal helper to extract sheet names from an XLSXFile
    private func getSheetNamesFromXLSX(_ xlsxFile: XLSXFile) -> [String]? {
        do {
            let workbooks = try xlsxFile.parseWorkbooks()
            guard let workbook = workbooks.first else {
                return nil
            }

            // Get sheet names from workbook
            let sheetNames = workbook.sheets.items.compactMap { $0.name }
            return sheetNames.isEmpty ? nil : sheetNames
        } catch {
            print("Error getting sheet names: \(error)")
            return nil
        }
    }

    func parseXLSXFile(at url: URL, sheetName: String? = nil) -> (headers: [String], rows: [[String]])? {
        guard let xlsxFile = XLSXFile(filepath: url.path) else {
            return nil
        }
        return parseXLSXFromXLSXFile(xlsxFile, sheetName: sheetName)
    }

    /// Parse XLSX from Data (for use with security-scoped resources)
    func parseXLSXFromData(_ data: Data, sheetName: String? = nil) -> (headers: [String], rows: [[String]])? {
        guard let xlsxFile = try? XLSXFile(data: data) else {
            return nil
        }
        return parseXLSXFromXLSXFile(xlsxFile, sheetName: sheetName)
    }

    /// Parse multiple sheets from XLSX data and combine into a unified dataset.
    /// A synthetic "Procedure" column is prepended so each row carries the procedure
    /// name from its originating sheet. All sheets are assumed to share the same column layout.
    func parseMultipleSheetsFromData(
        _ data: Data,
        sheetMappings: [(sheetName: String, procedureName: String)]
    ) -> (headers: [String], rows: [[String]])? {
        guard let xlsxFile = try? XLSXFile(data: data) else { return nil }

        var combinedHeaders: [String]?
        var combinedRows: [[String]] = []

        for mapping in sheetMappings {
            guard let result = parseXLSXFromXLSXFile(xlsxFile, sheetName: mapping.sheetName) else {
                print("[XLSX Batch] Skipping sheet '\(mapping.sheetName)' — failed to parse")
                continue
            }

            guard !result.rows.isEmpty else {
                print("[XLSX Batch] Skipping sheet '\(mapping.sheetName)' — no data rows")
                continue
            }

            // Use the first successfully parsed sheet's headers as canonical
            if combinedHeaders == nil {
                combinedHeaders = ["Procedure"] + result.headers
            }

            let expectedColumnCount = (combinedHeaders?.count ?? 1) - 1
            for row in result.rows {
                var normalized = row
                // Pad short rows
                while normalized.count < expectedColumnCount {
                    normalized.append("")
                }
                // Truncate long rows
                if normalized.count > expectedColumnCount {
                    normalized = Array(normalized.prefix(expectedColumnCount))
                }
                combinedRows.append([mapping.procedureName] + normalized)
            }
        }

        guard let headers = combinedHeaders, !combinedRows.isEmpty else { return nil }
        return (headers, combinedRows)
    }

    /// Parse each sheet independently, returning per-sheet headers and rows.
    /// Unlike `parseMultipleSheetsFromData`, each sheet retains its own column layout.
    func parseIndividualSheets(
        from data: Data,
        sheetNames: [String]
    ) -> [(sheetName: String, headers: [String], rows: [[String]])] {
        guard let xlsxFile = try? XLSXFile(data: data) else { return [] }

        var results: [(sheetName: String, headers: [String], rows: [[String]])] = []

        for name in sheetNames {
            guard let result = parseXLSXFromXLSXFile(xlsxFile, sheetName: name) else {
                print("[XLSX Per-Sheet] Skipping sheet '\(name)' — failed to parse")
                continue
            }

            guard !result.rows.isEmpty else {
                print("[XLSX Per-Sheet] Skipping sheet '\(name)' — no data rows")
                continue
            }

            results.append((sheetName: name, headers: result.headers, rows: result.rows))
        }

        return results
    }

    /// Internal helper to parse XLSX from an XLSXFile object
    private func parseXLSXFromXLSXFile(_ xlsxFile: XLSXFile, sheetName: String? = nil) -> (headers: [String], rows: [[String]])? {

        do {
            print("[XLSX Import] Starting XLSX parse, sheetName=\(sheetName ?? "nil")")

            // Get worksheet paths and workbook info for sheet name lookup
            let worksheetPaths = try xlsxFile.parseWorksheetPaths()
            print("[XLSX Import] Found \(worksheetPaths.count) worksheet paths")

            let workbooks = try xlsxFile.parseWorkbooks()
            print("[XLSX Import] Parsed \(workbooks.count) workbooks")

            var targetPath: String?

            if let sheetName = sheetName,
               let workbook = workbooks.first,
               let pathsAndNames = try? xlsxFile.parseWorksheetPathsAndNames(workbook: workbook) {
                print("[XLSX Import] Searching \(pathsAndNames.count) sheets for '\(sheetName)'")
                // Find the path for the requested sheet name
                for (name, path) in pathsAndNames {
                    if name == sheetName {
                        targetPath = path
                        print("[XLSX Import] Found sheet at path: \(path)")
                        break
                    }
                }
            }

            // Fall back to first sheet if no match or no sheet specified
            guard let worksheetPath = targetPath ?? worksheetPaths.first else {
                print("[XLSX Import] ERROR: No worksheet path found")
                return nil
            }

            print("[XLSX Import] Parsing worksheet at: \(worksheetPath)")
            let worksheet = try xlsxFile.parseWorksheet(at: worksheetPath)
            print("[XLSX Import] Worksheet parsed successfully")

            // Get shared strings for cell value lookup
            print("[XLSX Import] Parsing shared strings...")
            let sharedStrings = try? xlsxFile.parseSharedStrings()
            print("[XLSX Import] Shared strings parsed: \(sharedStrings?.items.count ?? 0) items")

            // Parse all rows from the worksheet
            guard let worksheetData = worksheet.data else {
                return ([], [])
            }

            var allRows: [[String]] = []
            var maxColumnCount = 0

            for row in worksheetData.rows {
                var rowValues: [String] = []
                var columnIndex = 0

                for cell in row.cells {
                    // Get the column index from the cell reference (e.g., "A1" -> 0, "B1" -> 1)
                    let cellColumn = min(columnIndexFromReference(cell.reference.column.value), 1000)

                    // Fill in any skipped columns with empty strings (capped to prevent runaway loops)
                    while columnIndex < cellColumn {
                        rowValues.append("")
                        columnIndex += 1
                    }

                    // Get the cell value
                    let value = cellValue(cell, sharedStrings: sharedStrings)
                    rowValues.append(value)
                    columnIndex += 1
                }

                maxColumnCount = max(maxColumnCount, rowValues.count)
                allRows.append(rowValues)
            }

            // Normalize row lengths
            allRows = allRows.map { row in
                var normalized = row
                while normalized.count < maxColumnCount {
                    normalized.append("")
                }
                return normalized
            }

            guard !allRows.isEmpty else {
                return ([], [])
            }

            // Find the actual header row (skip metadata lines)
            let headerIndex = findHeaderRow(in: allRows)
            let headers = allRows[headerIndex]
            var dataRows = Array(allRows.dropFirst(headerIndex + 1))

            // Convert Excel date serial numbers to readable date strings
            convertDateSerialNumbers(headers: headers, rows: &dataRows)

            return (headers, dataRows)

        } catch {
            print("Error parsing XLSX file: \(error)")
            return nil
        }
    }

    /// Convert Excel column letter to zero-based index (A=0, B=1, ..., Z=25, AA=26, etc.)
    private func columnIndexFromReference(_ column: String) -> Int {
        var index = 0
        for char in column.uppercased() {
            guard let asciiValue = char.asciiValue else { continue }
            index = index * 26 + Int(asciiValue - 64) // 'A' = 65, so 'A' - 64 = 1
        }
        return index - 1 // Convert to zero-based
    }

    /// Extract the string value from an xlsx cell
    private func cellValue(_ cell: Cell, sharedStrings: SharedStrings?) -> String {
        // Check if cell has inline string
        if let inlineString = cell.inlineString?.text {
            return inlineString
        }

        // Check if cell has a value
        guard let cellValue = cell.value else {
            return ""
        }

        // If cell type is shared string, look up the value
        if cell.type == .sharedString, let sharedStrings = sharedStrings {
            if let index = Int(cellValue), index < sharedStrings.items.count {
                return sharedStrings.items[index].text ?? ""
            }
        }

        // Return the raw value for numbers, dates, etc.
        return cellValue
    }

    /// Post-process parsed rows to convert Excel date serial numbers to readable
    /// date strings so that the data preview and import pipeline see "07/07/2022"
    /// instead of "44749".
    private func convertDateSerialNumbers(headers: [String], rows: inout [[String]]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        for colIndex in 0..<headers.count {
            // Check header hint
            let header = headers[colIndex].lowercased().trimmingCharacters(in: .whitespaces)
            let isDateHeader = header.contains("date") || header.contains("timeframe")
                || header == "week" || header == "period"

            // Sample first 10 rows to see if values look like serial numbers
            var serialCount = 0
            var sampleCount = 0
            for row in rows.prefix(10) {
                guard colIndex < row.count else { continue }
                let value = row[colIndex].trimmingCharacters(in: .whitespaces)
                guard !value.isEmpty else { continue }
                sampleCount += 1
                if let num = Double(value), num >= 10000, num <= 100000 {
                    serialCount += 1
                }
            }

            let isSerialColumn = sampleCount >= 2
                && Double(serialCount) / Double(sampleCount) >= 0.5

            guard isDateHeader || isSerialColumn else { continue }

            // Convert serial numbers in this column to formatted dates
            for rowIndex in 0..<rows.count {
                guard colIndex < rows[rowIndex].count else { continue }
                let value = rows[rowIndex][colIndex].trimmingCharacters(in: .whitespaces)
                if let serial = Double(value), serial >= 10000, serial <= 100000,
                   let date = Self.dateFromExcelSerial(serial) {
                    rows[rowIndex][colIndex] = dateFormatter.string(from: date)
                }
            }
        }
    }

    // MARK: - CSV Parsing

    func parseCSVFile(at url: URL) -> (headers: [String], rows: [[String]])? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return parseCSVContent(content)
    }

    /// Parse CSV content from a string (for use with security-scoped resources where data is pre-read)
    func parseCSVContent(_ content: String) -> (headers: [String], rows: [[String]])? {
        // Detect delimiter (tab vs comma)
        let delimiter = detectDelimiter(content)

        // Parse all rows using the detected delimiter
        let allRows = parseDelimited(content, delimiter: delimiter)

        guard !allRows.isEmpty else {
            return ([], [])
        }

        // Find the actual header row (skip metadata lines)
        let headerIndex = findHeaderRow(in: allRows)
        let headers = allRows[headerIndex]
        let dataRows = Array(allRows.dropFirst(headerIndex + 1))

        return (headers, dataRows)
    }

    /// Detect whether the file uses tabs or commas as delimiter
    private func detectDelimiter(_ content: String) -> Character {
        let sampleLines = content.components(separatedBy: .newlines).prefix(10)
        var tabCount = 0
        var commaCount = 0
        for line in sampleLines {
            tabCount += line.filter { $0 == "\t" }.count
            commaCount += line.filter { $0 == "," }.count
        }
        return tabCount > commaCount ? "\t" : ","
    }

    /// Find the row index that contains the actual column headers (skipping metadata)
    private func findHeaderRow(in rows: [[String]]) -> Int {
        let headerKeywords = [
            "date", "procedure", "attending", "supervisor",
            "facility", "hospital", "outcome", "timeframe",
            "specialty", "diagnosis", "location", "access",
            "complication", "notes", "participation", "role"
        ]

        for (index, row) in rows.enumerated() {
            guard row.count >= 3 else { continue }
            let matchCount = row.filter { field in
                let lower = field.lowercased()
                return headerKeywords.contains { lower.contains($0) }
            }.count
            if matchCount >= 2 { return index }
        }
        return 0 // fallback: first row
    }

    private func parseDelimited(_ content: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        for char in content {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == delimiter && !inQuotes {
                currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else if (char == "\n" || char == "\r") && !inQuotes {
                if !currentField.isEmpty || !currentRow.isEmpty {
                    currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                    if !currentRow.allSatisfy({ $0.isEmpty }) {
                        rows.append(currentRow)
                    }
                    currentRow = []
                    currentField = ""
                }
            } else {
                currentField.append(char)
            }
        }

        // Handle last field/row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
            if !currentRow.allSatisfy({ $0.isEmpty }) {
                rows.append(currentRow)
            }
        }

        return rows
    }
    
    // MARK: - Column Detection
    
    func autoDetectColumns(headers: [String], dataRows: [[String]], sheetName: String? = nil) -> ColumnMapping {
        var mapping = ColumnMapping()

        // If a named sheet was imported, offer it as the procedure source.
        if let sheetName = sheetName, !sheetName.isEmpty {
            mapping.sheetProcedureName = sheetName
        }

        for (index, header) in headers.enumerated() {
            let lower = header.lowercased().trimmingCharacters(in: .whitespaces)

            // Skip columns whose header matched but have no actual data
            guard columnHasData(index, in: dataRows) else { continue }

            // Date/Timeframe
            if mapping.dateColumn == nil &&
               (lower.contains("date") || lower.contains("timeframe") || lower == "week" || lower == "period") {
                mapping.dateColumn = index
            }
            // Attending/Supervisor
            else if mapping.attendingColumn == nil &&
                    (lower.contains("attending") || lower.contains("supervisor") || lower.contains("faculty") || lower.contains("preceptor")) {
                mapping.attendingColumn = index
            }
            // Facility/Hospital
            else if mapping.facilityColumn == nil &&
                    (lower.contains("facility") || lower.contains("hospital") || lower.contains("institution") || lower.contains("center") || lower.contains("site")) {
                // Avoid matching "access site"
                if !lower.contains("access") {
                    mapping.facilityColumn = index
                }
            }
            // Procedures
            else if mapping.proceduresColumn == nil &&
                    (lower.contains("procedure") || lower.contains("operation")) {
                mapping.proceduresColumn = index
            }
            // Access Sites
            else if mapping.accessSitesColumn == nil &&
                    (lower.contains("access") || lower.contains("approach")) {
                mapping.accessSitesColumn = index
            }
            // Complications
            else if mapping.complicationsColumn == nil &&
                    (lower.contains("complication") || lower.contains("adverse")) {
                mapping.complicationsColumn = index
            }
            // Outcome
            else if mapping.outcomeColumn == nil &&
                    (lower.contains("outcome") || lower.contains("result") || lower.contains("status")) {
                mapping.outcomeColumn = index
            }
            // Operator Role/Participation
            else if mapping.roleColumn == nil &&
                    (lower.contains("participation") || lower.contains("role") || lower.contains("operator")) {
                mapping.roleColumn = index
            }
            // Notes
            else if mapping.notesColumn == nil &&
                    (lower.contains("note") || lower.contains("comment")) {
                mapping.notesColumn = index
            }
            // Patient Name/ID/MRN
            else if mapping.patientColumn == nil &&
                    (lower.contains("patient") || lower.contains("mrn") || lower == "identifier") {
                // Avoid matching "procedure name" and "patient age"
                if !lower.contains("procedure") && !lower.contains("age") {
                    mapping.patientColumn = index
                }
            }
            // Patient Age
            else if mapping.ageColumn == nil &&
                    (lower == "age" || lower.contains("patient age") || lower.contains("pt age") || lower == "pt. age") {
                mapping.ageColumn = index
            }
            // Location (fallback to facility if no facility matched yet)
            else if mapping.facilityColumn == nil && lower.contains("location") {
                mapping.facilityColumn = index
            }
        }

        // Content-based date detection fallback — if no header matched a date
        // keyword, scan actual cell values to find the column whose data parses
        // as dates (text formats or Excel serial numbers).
        if mapping.dateColumn == nil {
            let alreadyMapped: Set<Int> = Set(
                [mapping.attendingColumn, mapping.facilityColumn,
                 mapping.proceduresColumn, mapping.accessSitesColumn,
                 mapping.complicationsColumn, mapping.outcomeColumn,
                 mapping.roleColumn, mapping.notesColumn,
                 mapping.patientColumn, mapping.ageColumn].compactMap { $0 }
            )
            if let detected = detectDateColumnByContent(
                headers: headers, dataRows: dataRows, excluding: alreadyMapped
            ) {
                mapping.dateColumn = detected
            }
        }

        // If a sheet name is available and no procedure column was detected,
        // default to using the sheet name as the procedure for every row.
        if mapping.sheetProcedureName != nil && mapping.proceduresColumn == nil {
            mapping.useSheetNameAsProcedure = true
        }

        return mapping
    }

    /// Check if a column has any non-empty data in the first 10 rows
    private func columnHasData(_ columnIndex: Int, in rows: [[String]]) -> Bool {
        let sampleRows = rows.prefix(10)
        let nonEmptyCount = sampleRows.filter { row in
            columnIndex < row.count && !row[columnIndex].trimmingCharacters(in: .whitespaces).isEmpty
        }.count
        return nonEmptyCount > 0
    }

    /// Scan cell values across all columns to find one whose data parses as
    /// dates. Returns the column index with the highest parse rate, or nil if
    /// no column reaches the 50 % threshold.
    private func detectDateColumnByContent(
        headers: [String],
        dataRows: [[String]],
        excluding: Set<Int>
    ) -> Int? {
        let formatters = Self.buildDateFormatters()
        let sampleRows = Array(dataRows.prefix(20))
        guard !sampleRows.isEmpty else { return nil }

        var bestColumn: Int? = nil
        var bestScore: Double = 0

        for colIndex in 0..<headers.count {
            // Skip columns already mapped to other fields
            guard !excluding.contains(colIndex) else { continue }

            var parseCount = 0
            var totalNonEmpty = 0

            for row in sampleRows {
                guard colIndex < row.count else { continue }
                let value = row[colIndex].trimmingCharacters(in: .whitespaces)
                guard !value.isEmpty else { continue }
                totalNonEmpty += 1

                if parseDate(value, using: formatters) != nil {
                    parseCount += 1
                }
            }

            // Need at least 2 non-empty cells and ≥50 % parse rate
            guard totalNonEmpty >= 2 else { continue }
            let score = Double(parseCount) / Double(totalNonEmpty)

            if score > bestScore && score >= 0.5 {
                bestScore = score
                bestColumn = colIndex
            }
        }

        return bestColumn
    }

    // MARK: - Import Cases
    
    func importCases(
        rows: [[String]],
        mapping: ColumnMapping,
        attendings: [ImportAttending],
        facilities: [ImportFacility],
        enabledPacks: [SpecialtyPack],
        customProcedures: [ImportCustomProcedure],
        progressCallback: (@Sendable (Int) -> Void)? = nil
    ) -> [ImportedCase] {
        var cases: [ImportedCase] = []

        // Build DateFormatters locally — avoids dispatch_once deadlocks that
        // occur when DateFormatter/Locale is initialized inside a static let.
        let formatters = Self.buildDateFormatters()

        for (rowIndex, row) in rows.enumerated() {
            // Parse date/week
            var weekBucket = Self.makeWeekBucket(for: Date())
            var date: Date?

            if let dateCol = mapping.dateColumn, dateCol < row.count {
                let dateStr = row[dateCol]
                if let parsed = parseDate(dateStr, using: formatters) {
                    date = parsed
                    weekBucket = Self.makeWeekBucket(for: parsed)
                } else if dateStr.contains("-W") {
                    weekBucket = dateStr
                }
            }

            // Parse other fields
            let attendingName = mapping.attendingColumn.flatMap { $0 < row.count ? row[$0] : nil }
            let facilityName = mapping.facilityColumn.flatMap { $0 < row.count ? row[$0] : nil }
            let proceduresStr = mapping.proceduresColumn.flatMap { $0 < row.count ? row[$0] : nil } ?? ""
            let accessStr = mapping.accessSitesColumn.flatMap { $0 < row.count ? row[$0] : nil } ?? ""
            let compsStr = mapping.complicationsColumn.flatMap { $0 < row.count ? row[$0] : nil } ?? ""
            let outcomeStr = mapping.outcomeColumn.flatMap { $0 < row.count ? row[$0] : nil }
            let baseNotes = mapping.notesColumn.flatMap { $0 < row.count ? row[$0] : nil }
            let role = mapping.roleColumn.flatMap { $0 < row.count ? row[$0] : nil }
            let patientId = mapping.patientColumn.flatMap { $0 < row.count ? row[$0] : nil }
            let patientAge = mapping.ageColumn.flatMap { $0 < row.count ? row[$0] : nil }

            // Build notes from base notes only (role is handled separately)
            let notes: String? = (baseNotes?.isEmpty == false) ? baseNotes : nil

            // Determine procedure names: either from the sheet name or the procedures column
            let procedures: [String]
            if mapping.useSheetNameAsProcedure, let sheetName = mapping.sheetProcedureName {
                procedures = [sheetName]
            } else {
                procedures = proceduresStr
                    .split(separator: Character(mapping.procedureDelimiter))
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }

            guard !procedures.isEmpty else { continue }

            // Split access sites
            let accessSites = accessStr
                .split(separator: Character(mapping.procedureDelimiter))
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            // Split complications
            let complications = compsStr
                .split(separator: Character(mapping.procedureDelimiter))
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            var importedCase = ImportedCase(
                date: date,
                weekBucket: weekBucket,
                attendingName: attendingName,
                facilityName: facilityName,
                procedureNames: procedures,
                accessSites: accessSites,
                complications: complications,
                outcome: outcomeStr,
                notes: notes,
                operatorRole: (role?.isEmpty == false) ? role : nil,
                patientIdentifier: (patientId?.isEmpty == false) ? patientId : nil,
                patientAge: (patientAge?.isEmpty == false) ? patientAge : nil
            )

            // Map attending
            if let name = attendingName {
                importedCase.mappedAttendingId = matchAttending(name: name, attendings: attendings)
            }

            // Map facility
            if let name = facilityName {
                importedCase.mappedFacilityId = matchFacility(name: name, facilities: facilities)
            }

            // Map procedures — bypass fuzzy matching when the batch mapper already resolved the tag ID
            if mapping.useSheetNameAsProcedure,
               let tagId = mapping.sheetProcedureTagId,
               let title = mapping.sheetProcedureName {
                importedCase.mappedProcedures = [MappedProcedure(
                    originalName: title,
                    status: .mapped,
                    matchedTagId: tagId,
                    matchedTitle: title,
                    matchConfidence: 1.0
                )]
            } else {
                importedCase.mappedProcedures = procedures.map { mapProcedure(name: $0, enabledPacks: enabledPacks, customProcedures: customProcedures) }
            }

            // Map access sites
            importedCase.mappedAccessSites = accessSites.compactMap { matchAccessSite(name: $0) }

            // Map complications
            importedCase.mappedComplications = complications.compactMap { matchComplication(name: $0) }
            
            // Map outcome
            if let outcome = outcomeStr {
                importedCase.mappedOutcome = mapOutcome(outcome)
            }
            
            cases.append(importedCase)

            // Report progress
            if rowIndex % 5 == 0 || rowIndex == rows.count - 1 {
                progressCallback?(rowIndex + 1)
            }
        }

        return cases
    }
    
    // MARK: - Date Parsing
    
    private static let dateFormats = [
        "yyyy-MM-dd",
        "MM/dd/yyyy",
        "M/d/yyyy",
        "MM-dd-yyyy",
        "dd/MM/yyyy",
        "MMM d, yyyy",
        "MMM dd, yyyy",
        "MMMM d, yyyy",
        "MMMM dd, yyyy",
        "M/d/yy",
        "MM/dd/yy",
    ]

    /// Build DateFormatter instances locally to avoid dispatch_once deadlocks
    /// that occur when DateFormatter/Locale(identifier:) is initialized inside
    /// a static let closure (Swift's lazy static init uses dispatch_once, which
    /// conflicts with ICU/Locale internal dispatch).
    private static func buildDateFormatters() -> [DateFormatter] {
        dateFormats.map { fmt in
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }
    }

    private func parseDate(_ str: String, using formatters: [DateFormatter]) -> Date? {
        let trimmed = str.trimmingCharacters(in: .whitespaces)

        for formatter in formatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        // Try Excel date serial number (Excel stores dates as days since Dec 30, 1899)
        if let serial = Double(trimmed), serial >= 10000, serial <= 100000 {
            return Self.dateFromExcelSerial(serial)
        }

        // Try week range format: "Jan 19–25, 2026" or "Jan 19-25, 2026"
        return parseDateRange(trimmed, using: formatters)
    }

    /// Convert an Excel date serial number to a Date.
    /// Excel 1900 date system: serial 1 = January 1, 1900.
    /// Due to the Lotus 123 bug, serial 60 = phantom Feb 29, 1900.
    /// For serial > 60 (all modern dates): date = December 30, 1899 + serial days.
    private static func dateFromExcelSerial(_ serial: Double) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let days = Int(serial)
        let epochComponents: DateComponents
        if days > 60 {
            epochComponents = DateComponents(year: 1899, month: 12, day: 30)
        } else {
            epochComponents = DateComponents(year: 1899, month: 12, day: 31)
        }

        guard let epoch = calendar.date(from: epochComponents) else { return nil }
        return calendar.date(byAdding: .day, value: days, to: epoch)
    }

    /// Parse week range format like "Jan 19–25, 2026" by extracting the start date
    private func parseDateRange(_ str: String, using formatters: [DateFormatter]) -> Date? {
        // Replace en-dash/em-dash with hyphen
        let cleaned = str.replacingOccurrences(of: "\u{2013}", with: "-")
                         .replacingOccurrences(of: "\u{2014}", with: "-")

        // Pattern: "Mon DD-DD, YYYY" → extract "Mon DD, YYYY"
        guard let dashRange = cleaned.range(of: "-"),
              let commaRange = cleaned.range(of: ",") else {
            return nil
        }

        let monthDay = cleaned[cleaned.startIndex..<dashRange.lowerBound] // "Jan 19"
        let year = cleaned[commaRange.lowerBound...]                      // ", 2026"
        let startDateStr = String(monthDay) + String(year)               // "Jan 19, 2026"

        for formatter in formatters {
            if let date = formatter.date(from: startDateStr) {
                return date
            }
        }
        return nil
    }
    
    // MARK: - Matching Functions
    
    private func matchAttending(name: String, attendings: [ImportAttending]) -> UUID? {
        let searchName = name.lowercased()

        for attending in attendings where !attending.isArchived {
            let fullName = attending.fullName.lowercased()
            let lastName = attending.lastName.lowercased()

            if fullName == searchName || lastName == searchName {
                return attending.id
            }

            if fullName.contains(searchName) || searchName.contains(lastName) {
                return attending.id
            }
        }

        return nil
    }
    
    private func matchFacility(name: String, facilities: [ImportFacility]) -> UUID? {
        let searchName = name.lowercased()

        for facility in facilities where !facility.isArchived {
            let facilityName = facility.name.lowercased()
            let shortName = facility.shortName?.lowercased() ?? ""

            if facilityName == searchName || shortName == searchName {
                return facility.id
            }

            if facilityName.contains(searchName) || searchName.contains(facilityName) {
                return facility.id
            }
        }

        return nil
    }
    
    func mapProcedure(name: String, enabledPacks: [SpecialtyPack], customProcedures: [ImportCustomProcedure]) -> MappedProcedure {
        let searchName = name.uppercased().trimmingCharacters(in: .whitespaces)

        // Check aliases first
        if let expanded = procedureAliases[searchName] {
            let expandedLower = expanded.lowercased()
            let originalLower = name.lowercased()

            // Search packs for real tagId matching original or expanded name
            var bestAliasMatch: (tagId: String, title: String, confidence: Double)? = nil
            for pack in enabledPacks {
                for category in pack.categories {
                    for procedure in category.procedures {
                        let procLower = procedure.title.lowercased()
                        let conf = max(
                            Self.calculateConfidence(search: originalLower, target: procLower),
                            Self.calculateConfidence(search: expandedLower, target: procLower)
                        )
                        if conf > (bestAliasMatch?.confidence ?? 0) {
                            bestAliasMatch = (procedure.id, procedure.title, conf)
                        }
                    }
                }
            }

            if let match = bestAliasMatch, match.confidence > 0.5 {
                return MappedProcedure(
                    originalName: name,
                    status: .mapped,
                    matchedTagId: match.tagId,
                    matchedTitle: match.title,
                    matchConfidence: match.confidence,
                    suggestedMatches: []
                )
            }
            // No pack match for alias — fall through to regular search
        }

        // Check legacy Procedus mappings
        let legacyResult = LegacyProcedusMigrationService.mapProcedureWithDetails(name)
        if legacyResult.isSuccessfullyMapped, let mappedId = legacyResult.mappedId {
            return MappedProcedure(
                originalName: name,
                status: MappingStatus.mapped,
                matchedTagId: mappedId,
                matchedTitle: legacyResult.mappedTitle ?? name,
                matchConfidence: legacyResult.confidence,
                suggestedMatches: []
            )
        }

        // Search enabled specialty pack procedures only
        var suggestions: [ProcedureSuggestion] = []
        let searchLower = name.lowercased()

        for pack in enabledPacks {
            for category in pack.categories {
                for procedure in category.procedures {
                    let procLower = procedure.title.lowercased()
                    let confidence = Self.calculateConfidence(search: searchLower, target: procLower)

                    if confidence > 0.3 {
                        suggestions.append(ProcedureSuggestion(
                            tagId: procedure.id,
                            title: procedure.title,
                            category: category.category,
                            confidence: confidence
                        ))
                    }
                }
            }
        }

        // Also search custom procedures
        for custom in customProcedures {
            let procLower = custom.title.lowercased()
            let confidence = Self.calculateConfidence(search: searchLower, target: procLower)

            if confidence > 0.3 {
                suggestions.append(ProcedureSuggestion(
                    tagId: custom.tagId,
                    title: custom.title,
                    category: custom.category,
                    confidence: confidence
                ))
            }
        }

        // Sort by confidence
        suggestions.sort { $0.confidence > $1.confidence }
        suggestions = Array(suggestions.prefix(5))

        // Determine status
        if let best = suggestions.first, best.confidence > 0.8 {
            return MappedProcedure(
                originalName: name,
                status: MappingStatus.mapped,
                matchedTagId: best.tagId,
                matchedTitle: best.title,
                matchConfidence: best.confidence,
                suggestedMatches: suggestions
            )
        } else if !suggestions.isEmpty {
            return MappedProcedure(
                originalName: name,
                status: MappingStatus.unmapped,
                matchConfidence: suggestions.first?.confidence ?? 0,
                suggestedMatches: suggestions
            )
        } else {
            return MappedProcedure(
                originalName: name,
                status: MappingStatus.unmapped,
                matchConfidence: 0,
                suggestedMatches: [],
                customProcedureCategory: ProcedureCategory.other
            )
        }
    }
    
    static func calculateConfidence(search: String, target: String) -> Double {
        if search == target { return 1.0 }
        if target.contains(search) {
            let ratio = Double(search.count) / Double(target.count)
            if ratio > 0.5 { return 0.9 }
            return 0.4 + (ratio * 0.5)
        }
        if search.contains(target) { return 0.85 }
        
        let searchWords = Set(search.split(separator: " ").map(String.init))
        let targetWords = Set(target.split(separator: " ").map(String.init))
        let intersection = searchWords.intersection(targetWords)
        let union = searchWords.union(targetWords)
        
        if !union.isEmpty {
            let jaccard = Double(intersection.count) / Double(union.count)
            if jaccard > 0.3 {
                return 0.5 + (jaccard * 0.4)
            }
        }
        
        // Common prefix
        let commonPrefix = search.commonPrefix(with: target)
        if commonPrefix.count > 3 {
            return 0.5 + (Double(commonPrefix.count) / Double(max(search.count, target.count)) * 0.3)
        }
        
        return 0
    }
    
    private func matchAccessSite(name: String) -> String? {
        let searchName = name.lowercased()
        
        for site in AccessSite.allCases {
            if site.rawValue.lowercased() == searchName ||
               site.rawValue.lowercased().contains(searchName) {
                return site.rawValue
            }
        }
        
        return nil
    }
    
    private func matchComplication(name: String) -> String? {
        let searchName = name.lowercased()
        
        for comp in Complication.allCases {
            if comp.rawValue.lowercased() == searchName ||
               comp.rawValue.lowercased().contains(searchName) {
                return comp.rawValue
            }
        }
        
        return nil
    }
    
    private func mapOutcome(_ str: String) -> CaseOutcome {
        let lower = str.lowercased()
        
        if lower.contains("success") || lower.contains("complete") {
            return .success
        } else if lower.contains("complication") || lower.contains("adverse") {
            return .complication
        } else if lower.contains("partial") {
            return .partialSuccess
        } else if lower.contains("abort") || lower.contains("cancel") {
            return .aborted
        } else if lower.contains("death") || lower.contains("expired") || lower.contains("died") {
            return .death
        }
        
        return .success
    }
    
    // MARK: - Create Cases
    
    func createCases(
        from importedCases: [ImportedCase],
        fellowId: UUID,
        programId: UUID?,
        modelContext: ModelContext
    ) -> Int {
        var createdCount = 0
        
        for imported in importedCases {
            guard imported.isFullyMapped else {
                continue
            }

            // Use individual mode initializer
            let caseEntry = CaseEntry(
                fellowId: fellowId,
                ownerId: fellowId,
                attendingId: imported.mappedAttendingId,
                weekBucket: imported.weekBucket,
                facilityId: imported.mappedFacilityId
            )
            
            // Set procedures
            caseEntry.procedureTagIds = imported.mappedProcedures.compactMap { $0.matchedTagId }

            // Infer case type from procedure tags using catalog lookup
            var hasCI = false, hasEP = false, hasIC = false
            for tagId in caseEntry.procedureTagIds {
                if tagId.hasPrefix("ci-") { hasCI = true; continue }
                if tagId.hasPrefix("ep-") { hasEP = true; continue }
                if tagId.hasPrefix("ic-") || tagId.hasPrefix("dx-") { hasIC = true; continue }
                if tagId.hasPrefix("custom-") { continue }
                if let packId = SpecialtyPackCatalog.findPackId(for: tagId) {
                    switch packId {
                    case "cardiac-imaging": hasCI = true
                    case "electrophysiology": hasEP = true
                    case "interventional-cardiology": hasIC = true
                    default: break
                    }
                }
            }
            if hasCI && !hasEP && !hasIC && !caseEntry.procedureTagIds.isEmpty {
                caseEntry.caseTypeRaw = CaseType.noninvasive.rawValue
            } else if hasEP {
                caseEntry.caseTypeRaw = CaseType.ep.rawValue
            } else {
                caseEntry.caseTypeRaw = CaseType.invasive.rawValue
            }

            // Set access sites
            caseEntry.accessSiteIds = imported.mappedAccessSites
            
            // Set complications
            caseEntry.complicationIds = imported.mappedComplications
            
            // Set outcome
            caseEntry.outcome = imported.mappedOutcome

            // Set operator position
            if let position = imported.mappedOperatorPosition {
                caseEntry.operatorPositionRaw = position.rawValue
            }

            // Set notes
            if let notes = imported.notes, !notes.isEmpty {
                caseEntry.notes = notes
            }

            // Mark as imported — no attestation required for imported cases
            caseEntry.isImported = true
            caseEntry.attestationStatus = .notRequired

            // Set program if provided
            if let programId = programId {
                caseEntry.programId = programId
            }
            
            modelContext.insert(caseEntry)
            createdCount += 1
        }
        
        try? modelContext.save()
        return createdCount
    }
}
