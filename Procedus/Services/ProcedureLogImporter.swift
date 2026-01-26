// ProcedureLogImporter.swift
// Procedus - Unified
// Import existing procedure logs from Excel/CSV with intelligent mapping
// NOTE: Uses MappingStatus from Enums.swift

import Foundation
import SwiftData

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
    
    // Mapping results
    var mappedAttendingId: UUID?
    var mappedFacilityId: UUID?
    var mappedProcedures: [MappedProcedure] = []
    var mappedAccessSites: [String] = []
    var mappedComplications: [String] = []
    var mappedOutcome: CaseOutcome = .success
    
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
    var categoryColumn: Int?
    var diagnosisColumn: Int?
    var roleColumn: Int?

    var procedureDelimiter: String = ";"
}

// MARK: - Procedure Log Importer

class ProcedureLogImporter {
    static let shared = ProcedureLogImporter()
    private init() {}
    
    // Common procedure aliases for fuzzy matching
    private let procedureAliases: [String: String] = [
        "LHC": "Left Heart Catheterization",
        "RHC": "Right Heart Catheterization",
        "PCI": "Percutaneous Coronary Intervention",
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

    func parseFile(at url: URL) -> (headers: [String], rows: [[String]])? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

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
    
    func autoDetectColumns(headers: [String]) -> ColumnMapping {
        var mapping = ColumnMapping()

        for (index, header) in headers.enumerated() {
            let lower = header.lowercased().trimmingCharacters(in: .whitespaces)

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
            // Category/Specialty
            else if mapping.categoryColumn == nil &&
                    (lower.contains("specialty") || lower.contains("category") || lower.contains("service")) {
                mapping.categoryColumn = index
            }
            // Diagnosis
            else if mapping.diagnosisColumn == nil &&
                    (lower.contains("diagnosis") || lower.contains("indication") || lower == "dx") {
                mapping.diagnosisColumn = index
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
            // Location (fallback to facility if no facility matched yet)
            else if mapping.facilityColumn == nil && lower.contains("location") {
                mapping.facilityColumn = index
            }
        }

        return mapping
    }
    
    // MARK: - Import Cases
    
    func importCases(
        rows: [[String]],
        mapping: ColumnMapping,
        attendings: [Attending],
        facilities: [TrainingFacility]
    ) -> [ImportedCase] {
        var cases: [ImportedCase] = []
        
        for row in rows {
            // Parse date/week
            var weekBucket = CaseEntry.makeWeekBucket(for: Date())
            var date: Date?
            
            if let dateCol = mapping.dateColumn, dateCol < row.count {
                let dateStr = row[dateCol]
                if let parsed = parseDate(dateStr) {
                    date = parsed
                    weekBucket = CaseEntry.makeWeekBucket(for: parsed)
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
            let category = mapping.categoryColumn.flatMap { $0 < row.count ? row[$0] : nil }
            let diagnosis = mapping.diagnosisColumn.flatMap { $0 < row.count ? row[$0] : nil }
            let role = mapping.roleColumn.flatMap { $0 < row.count ? row[$0] : nil }

            // Build notes from base notes + diagnosis + role
            var noteParts: [String] = []
            if let baseNotes, !baseNotes.isEmpty { noteParts.append(baseNotes) }
            if let diagnosis, !diagnosis.isEmpty { noteParts.append("Diagnosis: \(diagnosis)") }
            if let role, !role.isEmpty { noteParts.append("Role: \(role)") }
            if let category, !category.isEmpty { noteParts.append("Specialty: \(category)") }
            let notes: String? = noteParts.isEmpty ? nil : noteParts.joined(separator: "\n")
            
            // Split procedures
            let procedures = proceduresStr
                .split(separator: Character(mapping.procedureDelimiter))
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
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
                notes: notes
            )
            
            // Map attending
            if let name = attendingName {
                importedCase.mappedAttendingId = matchAttending(name: name, attendings: attendings)
            }
            
            // Map facility
            if let name = facilityName {
                importedCase.mappedFacilityId = matchFacility(name: name, facilities: facilities)
            }
            
            // Map procedures
            importedCase.mappedProcedures = procedures.map { mapProcedure(name: $0) }
            
            // Map access sites
            importedCase.mappedAccessSites = accessSites.compactMap { matchAccessSite(name: $0) }
            
            // Map complications
            importedCase.mappedComplications = complications.compactMap { matchComplication(name: $0) }
            
            // Map outcome
            if let outcome = outcomeStr {
                importedCase.mappedOutcome = mapOutcome(outcome)
            }
            
            cases.append(importedCase)
        }
        
        return cases
    }
    
    // MARK: - Date Parsing
    
    private static let dateFormatters: [DateFormatter] = {
        let formats = [
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
        return formats.map { fmt in
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }
    }()

    private func parseDate(_ str: String) -> Date? {
        let trimmed = str.trimmingCharacters(in: .whitespaces)

        for formatter in Self.dateFormatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        // Try week range format: "Jan 19–25, 2026" or "Jan 19-25, 2026"
        return parseDateRange(trimmed)
    }

    /// Parse week range format like "Jan 19–25, 2026" by extracting the start date
    private func parseDateRange(_ str: String) -> Date? {
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

        for formatter in Self.dateFormatters {
            if let date = formatter.date(from: startDateStr) {
                return date
            }
        }
        return nil
    }
    
    // MARK: - Matching Functions
    
    private func matchAttending(name: String, attendings: [Attending]) -> UUID? {
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
    
    private func matchFacility(name: String, facilities: [TrainingFacility]) -> UUID? {
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
    
    func mapProcedure(name: String) -> MappedProcedure {
        let searchName = name.uppercased().trimmingCharacters(in: .whitespaces)

        // Check aliases first
        if let expanded = procedureAliases[searchName] {
            return MappedProcedure(
                originalName: name,
                status: MappingStatus.mapped,
                matchedTagId: "alias:\(searchName)",
                matchedTitle: expanded,
                matchConfidence: 1.0,
                suggestedMatches: []
            )
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

        // Search specialty pack procedures
        var suggestions: [ProcedureSuggestion] = []
        let searchLower = name.lowercased()

        for pack in SpecialtyPackCatalog.allPacks {
            for category in pack.categories {
                for procedure in category.procedures {
                    let procLower = procedure.title.lowercased()
                    let confidence = calculateConfidence(search: searchLower, target: procLower)

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
    
    private func calculateConfidence(search: String, target: String) -> Double {
        if search == target { return 1.0 }
        if target.contains(search) { return 0.9 }
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
                ownerId: fellowId,
                attendingId: imported.mappedAttendingId,
                weekBucket: imported.weekBucket,
                facilityId: imported.mappedFacilityId
            )
            
            // Set procedures
            caseEntry.procedureTagIds = imported.mappedProcedures.compactMap { $0.matchedTagId }
            
            // Set access sites
            caseEntry.accessSiteIds = imported.mappedAccessSites
            
            // Set complications
            caseEntry.complicationIds = imported.mappedComplications
            
            // Set outcome
            caseEntry.outcome = imported.mappedOutcome

            // Set notes
            if let notes = imported.notes, !notes.isEmpty {
                caseEntry.notes = notes
            }

            // Set program if provided
            if let programId = programId {
                caseEntry.programId = programId
                caseEntry.attestationStatus = AttestationStatus.pending
            }
            
            modelContext.insert(caseEntry)
            createdCount += 1
        }
        
        try? modelContext.save()
        return createdCount
    }
}
