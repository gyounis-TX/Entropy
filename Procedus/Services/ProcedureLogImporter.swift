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
        mappedAttendingId != nil &&
        mappedFacilityId != nil &&
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
    
    func parseFile(at url: URL) -> (headers: [String], rows: [[String]])? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "csv":
            return parseCSV(content)
        case "xlsx", "xls":
            // For Excel, treat as CSV for now
            return parseCSV(content)
        default:
            return parseCSV(content)
        }
    }
    
    private func parseCSV(_ content: String) -> (headers: [String], rows: [[String]]) {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        
        for char in content {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
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
        
        guard !rows.isEmpty else {
            return ([], [])
        }
        
        let headers = rows[0]
        let dataRows = Array(rows.dropFirst())
        
        return (headers, dataRows)
    }
    
    // MARK: - Column Detection
    
    func autoDetectColumns(headers: [String]) -> ColumnMapping {
        var mapping = ColumnMapping()
        
        for (index, header) in headers.enumerated() {
            let lower = header.lowercased()
            
            if lower.contains("date") || lower.contains("week") || lower.contains("time") {
                mapping.dateColumn = index
            } else if lower.contains("attending") || lower.contains("supervisor") || lower.contains("faculty") {
                mapping.attendingColumn = index
            } else if lower.contains("facility") || lower.contains("hospital") || lower.contains("location") || lower.contains("site") {
                mapping.facilityColumn = index
            } else if lower.contains("procedure") || lower.contains("case") || lower.contains("operation") {
                mapping.proceduresColumn = index
            } else if lower.contains("access") || lower.contains("approach") {
                mapping.accessSitesColumn = index
            } else if lower.contains("complication") || lower.contains("adverse") {
                mapping.complicationsColumn = index
            } else if lower.contains("outcome") || lower.contains("result") || lower.contains("status") {
                mapping.outcomeColumn = index
            } else if lower.contains("note") || lower.contains("comment") {
                mapping.notesColumn = index
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
            let notes = mapping.notesColumn.flatMap { $0 < row.count ? row[$0] : nil }
            
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
    
    private func parseDate(_ str: String) -> Date? {
        let formatters: [DateFormatter] = [
            { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }(),
            { let f = DateFormatter(); f.dateFormat = "MM/dd/yyyy"; return f }(),
            { let f = DateFormatter(); f.dateFormat = "M/d/yyyy"; return f }(),
            { let f = DateFormatter(); f.dateFormat = "MM-dd-yyyy"; return f }(),
            { let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"; return f }(),
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: str) {
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
            guard imported.isFullyMapped,
                  let attendingId = imported.mappedAttendingId,
                  let facilityId = imported.mappedFacilityId else {
                continue
            }
            
            // Use individual mode initializer
            let caseEntry = CaseEntry(
                ownerId: fellowId,
                attendingId: attendingId,
                weekBucket: imported.weekBucket,
                facilityId: facilityId
            )
            
            // Set procedures
            caseEntry.procedureTagIds = imported.mappedProcedures.compactMap { $0.matchedTagId }
            
            // Set access sites
            caseEntry.accessSiteIds = imported.mappedAccessSites
            
            // Set complications
            caseEntry.complicationIds = imported.mappedComplications
            
            // Set outcome
            caseEntry.outcome = imported.mappedOutcome
            
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
