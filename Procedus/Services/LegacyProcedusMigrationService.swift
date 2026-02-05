// LegacyProcedusMigrationService.swift
// Procedus - Unified
// Handles migration of data from original Procedus app to Procedus Unified

import Foundation
import SwiftData

/// Service for migrating data from the original Procedus app
/// Includes comprehensive procedure mapping for legacy procedure names/IDs
enum LegacyProcedusMigrationService {

    // MARK: - Legacy Procedure Mappings

    /// Maps legacy Procedus procedure names to new procedure tag IDs
    /// Key: Legacy procedure name (case-insensitive matching)
    /// Value: New procedure tag ID from SpecialtyPackCatalog
    static let legacyProcedureMappings: [String: String] = [
        // ========================
        // INTERVENTIONAL CARDIOLOGY
        // ========================

        // Diagnostic Procedures
        "left heart cath": "ic-dx-lhc",
        "left heart catheterization": "ic-dx-lhc",
        "lhc": "ic-dx-lhc",
        "right heart cath": "ic-dx-rhc",
        "right heart catheterization": "ic-dx-rhc",
        "rhc": "ic-dx-rhc",
        "coronary angiography": "ic-dx-coro",
        "coronary angiogram": "ic-dx-coro",
        "cath": "ic-dx-lhc",
        "cardiac cath": "ic-dx-lhc",
        "cardiac catheterization": "ic-dx-lhc",
        "lv angiography": "ic-dx-lv",
        "left ventriculography": "ic-dx-lv",
        "lv gram": "ic-dx-lv",
        "aortography": "ic-dx-ao",
        "aortogram": "ic-dx-ao",
        "endomyocardial biopsy": "ic-dx-biopsy",
        "emb": "ic-dx-biopsy",
        "heart biopsy": "ic-dx-biopsy",

        // Coronary Interventions
        "pci": "ic-pci-stent",
        "percutaneous coronary intervention": "ic-pci-stent",
        "coronary stent": "ic-pci-stent",
        "stent": "ic-pci-stent",
        "des": "ic-pci-stent",
        "drug eluting stent": "ic-pci-stent",
        "bms": "ic-pci-stent",
        "bare metal stent": "ic-pci-stent",
        "poba": "ic-pci-poba",
        "plain old balloon angioplasty": "ic-pci-poba",
        "balloon angioplasty": "ic-pci-poba",
        "ptca": "ic-pci-poba",
        "dcb": "ic-pci-dcb",
        "drug coated balloon": "ic-pci-dcb",
        "rotablator": "ic-pci-rotablator",
        "rotational atherectomy": "ic-pci-rotablator",
        "rota": "ic-pci-rotablator",
        "orbital atherectomy": "ic-pci-orbital",
        "diamondback": "ic-pci-orbital",
        "ivl": "ic-pci-ivl",
        "intravascular lithotripsy": "ic-pci-ivl",
        "shockwave": "ic-pci-ivl",
        "laser atherectomy": "ic-pci-laser",
        "excimer laser": "ic-pci-laser",

        // Imaging
        "ivus": "ic-img-ivus",
        "intravascular ultrasound": "ic-img-ivus",
        "oct": "ic-img-oct",
        "optical coherence tomography": "ic-img-oct",
        "ffr": "ic-img-ffr",
        "fractional flow reserve": "ic-img-ffr",
        "ifr": "ic-img-ifr",
        "instant wave-free ratio": "ic-img-ifr",

        // Structural Heart
        "tavr": "ic-struct-tavr",
        "tavi": "ic-struct-tavr",
        "transcatheter aortic valve replacement": "ic-struct-tavr",
        "transcatheter aortic valve implantation": "ic-struct-tavr",
        "mitraclip": "ic-struct-mitraclip",
        "mitra clip": "ic-struct-mitraclip",
        "tmvr": "ic-struct-tmvr",
        "transcatheter mitral valve repair": "ic-struct-tmvr",
        "watchman": "ic-struct-watchman",
        "laao": "ic-struct-watchman",
        "left atrial appendage occlusion": "ic-struct-watchman",
        "left atrial appendage closure": "ic-struct-watchman",
        "pfo closure": "ic-struct-pfo",
        "patent foramen ovale closure": "ic-struct-pfo",
        "asd closure": "ic-struct-asd",
        "atrial septal defect closure": "ic-struct-asd",
        "vsd closure": "ic-struct-vsd",
        "balloon aortic valvuloplasty": "ic-struct-bav",
        "bav": "ic-struct-bav",
        "balloon mitral valvuloplasty": "ic-struct-bmv",
        "bmv": "ic-struct-bmv",
        "alcohol septal ablation": "ic-struct-asa",
        "septal ablation": "ic-struct-asa",

        // Peripheral
        "peripheral angiography": "ic-periph-angio",
        "peripheral intervention": "ic-periph-pvi",
        "peripheral vascular intervention": "ic-periph-pvi",
        "lower extremity intervention": "ic-periph-pvi",
        "carotid stent": "ic-periph-carotid",
        "carotid artery stenting": "ic-periph-carotid",
        "cas": "ic-periph-carotid",
        "renal artery stent": "ic-periph-renal",
        "renal intervention": "ic-periph-renal",

        // Venous / PE
        "ivc filter": "ic-venous-ivc",
        "ivc filter placement": "ic-venous-ivc",
        "ivc filter retrieval": "ic-venous-ivc-rem",
        "ekos": "ic-venous-pe-cdt",
        "pe cdt": "ic-venous-pe-cdt",
        "pe thrombectomy": "ic-venous-pe-cdt",
        "dvt intervention": "ic-venous-dvt",
        "cardiomems": "ic-venous-cardiomems",

        // Hemodynamic Support
        "iabp": "ic-support-iabp",
        "intra-aortic balloon pump": "ic-support-iabp",
        "balloon pump": "ic-support-iabp",
        "impella": "ic-support-impella",
        "impella cp": "ic-support-impella",
        "impella 5.0": "ic-support-impella",
        "tandem heart": "ic-support-tandem",
        "ecmo": "ic-support-ecmo",
        "va ecmo": "ic-support-ecmo",
        "extracorporeal membrane oxygenation": "ic-support-ecmo",

        // ========================
        // ELECTROPHYSIOLOGY
        // ========================

        "ep study": "ep-dx-eps",
        "eps": "ep-dx-eps",
        "electrophysiology study": "ep-dx-eps",
        "ablation": "ep-abl-svt",
        "svt ablation": "ep-abl-svt",
        "supraventricular tachycardia ablation": "ep-abl-svt",
        "avnrt ablation": "ep-abl-avnrt",
        "avrt ablation": "ep-abl-avrt",
        "wpw ablation": "ep-abl-avrt",
        "af ablation": "ep-abl-af",
        "afib ablation": "ep-abl-af",
        "atrial fibrillation ablation": "ep-abl-af",
        "pulmonary vein isolation": "ep-abl-pvi",
        "pvi": "ep-abl-pvi",
        "atrial flutter ablation": "ep-abl-flutter",
        "flutter ablation": "ep-abl-flutter",
        "cti ablation": "ep-abl-flutter",
        "vt ablation": "ep-abl-vt",
        "ventricular tachycardia ablation": "ep-abl-vt",
        "pvc ablation": "ep-abl-pvc",

        // Devices
        "pacemaker": "ep-device-ppm",
        "ppm": "ep-device-ppm",
        "permanent pacemaker": "ep-device-ppm",
        "pacemaker implant": "ep-device-ppm",
        "icd": "ep-device-icd",
        "icd implant": "ep-device-icd",
        "defibrillator": "ep-device-icd",
        "aicd": "ep-device-icd",
        "crt": "ep-device-crt",
        "crt-d": "ep-device-crtd",
        "crt-p": "ep-device-crtp",
        "biventricular pacemaker": "ep-device-crt",
        "cardiac resynchronization therapy": "ep-device-crt",
        "leadless pacemaker": "ep-device-leadless",
        "micra": "ep-device-leadless",
        "loop recorder": "ep-device-ilr",
        "ilr": "ep-device-ilr",
        "implantable loop recorder": "ep-device-ilr",
        "reveal": "ep-device-ilr",
        "generator change": "ep-device-genchange",
        "battery change": "ep-device-genchange",
        "lead extraction": "ep-device-extraction",
        "lead revision": "ep-device-revision",

        // Cardioversion
        "cardioversion": "ep-cv-dccv",
        "dccv": "ep-cv-dccv",
        "dc cardioversion": "ep-cv-dccv",
        "electrical cardioversion": "ep-cv-dccv",
        "tee cardioversion": "ep-cv-teecv",

        // ========================
        // CARDIAC IMAGING
        // ========================

        "tte": "ci-echo-tte",
        "transthoracic echo": "ci-echo-tte",
        "transthoracic echocardiogram": "ci-echo-tte",
        "echocardiogram": "ci-echo-tte",
        "echo": "ci-echo-tte",
        "tee": "ci-echo-tee",
        "transesophageal echo": "ci-echo-tee",
        "transesophageal echocardiogram": "ci-echo-tee",
        "stress echo": "ci-stress-echo",
        "stress echocardiogram": "ci-stress-echo",
        "dobutamine stress echo": "ci-stress-dse",
        "dse": "ci-stress-dse",
        "exercise stress test": "ci-stress-exercise",
        "treadmill": "ci-stress-exercise",
        "nuclear stress": "ci-stress-nuclear",
        "myocardial perfusion imaging": "ci-stress-nuclear",
        "mpi": "ci-stress-nuclear",
        "pet": "ci-stress-pet",
        "cardiac pet": "ci-stress-pet",
        "cardiac mri": "ci-advanced-cmr",
        "cmr": "ci-advanced-cmr",
        "cardiac ct": "ci-advanced-cta",
        "ccta": "ci-advanced-cta",
        "coronary cta": "ci-advanced-cta",
        "calcium score": "ci-advanced-calcium",

        // ========================
        // GENERAL/OTHER
        // ========================

        "pericardiocentesis": "ic-other-pericardio",
        "paracentesis": "general-paracentesis",
        "thoracentesis": "general-thoracentesis",
        "central line": "general-centralline",
        "central venous catheter": "general-centralline",
        "arterial line": "general-arterialline",
        "swan ganz": "general-swan",
        "pa catheter": "general-swan",
        "pulmonary artery catheter": "general-swan",
    ]

    /// Maps legacy procedure IDs (if the original app used IDs) to new IDs
    static let legacyIdMappings: [String: String] = [:]
    // Add any known legacy procedure IDs here when discovered
    // Example: legacyIdMappings["old-proc-001"] = "ic-dx-lhc"

    // MARK: - Mapping Functions

    /// Attempts to map a legacy procedure name to a new procedure tag ID
    /// - Parameter legacyName: The procedure name from the original Procedus app
    /// - Returns: The mapped procedure tag ID, or nil if no mapping found
    static func mapProcedure(_ legacyName: String) -> String? {
        let normalized = legacyName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Direct mapping lookup
        if let mapped = legacyProcedureMappings[normalized] {
            return mapped
        }

        // Try legacy ID mapping
        if let mapped = legacyIdMappings[normalized] {
            return mapped
        }

        // Fuzzy matching - check if any mapping key is contained in the name
        for (key, value) in legacyProcedureMappings {
            if normalized.contains(key) || key.contains(normalized) {
                return value
            }
        }

        return nil
    }

    /// Attempts to map a legacy procedure and returns detailed result
    static func mapProcedureWithDetails(_ legacyName: String) -> ProcedureMappingResult {
        let normalized = legacyName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Direct mapping
        if let mapped = legacyProcedureMappings[normalized] {
            return ProcedureMappingResult(
                originalName: legacyName,
                mappedId: mapped,
                mappedTitle: SpecialtyPackCatalog.findProcedureTitle(for: mapped),
                confidence: 1.0,
                mappingType: .exact
            )
        }

        // Legacy ID mapping
        if let mapped = legacyIdMappings[normalized] {
            return ProcedureMappingResult(
                originalName: legacyName,
                mappedId: mapped,
                mappedTitle: SpecialtyPackCatalog.findProcedureTitle(for: mapped),
                confidence: 1.0,
                mappingType: .legacyId
            )
        }

        // Fuzzy matching
        var bestMatch: (key: String, value: String, score: Double)?
        for (key, value) in legacyProcedureMappings {
            let score = calculateSimilarity(normalized, key)
            if score > 0.6 && (bestMatch == nil || score > bestMatch!.score) {
                bestMatch = (key, value, score)
            }
        }

        if let match = bestMatch {
            return ProcedureMappingResult(
                originalName: legacyName,
                mappedId: match.value,
                mappedTitle: SpecialtyPackCatalog.findProcedureTitle(for: match.value),
                confidence: match.score,
                mappingType: .fuzzy
            )
        }

        // Try matching against current catalog procedures
        let catalogMatch = findInCatalog(legacyName)
        if let match = catalogMatch {
            return match
        }

        // No mapping found
        return ProcedureMappingResult(
            originalName: legacyName,
            mappedId: nil,
            mappedTitle: nil,
            confidence: 0,
            mappingType: .unmapped
        )
    }

    /// Search current catalog for matching procedure
    private static func findInCatalog(_ name: String) -> ProcedureMappingResult? {
        let normalized = name.lowercased()
        var bestMatch: (id: String, title: String, score: Double)?

        for pack in SpecialtyPackCatalog.allPacks {
            for category in pack.categories {
                for procedure in category.procedures {
                    let procLower = procedure.title.lowercased()
                    let score = calculateSimilarity(normalized, procLower)
                    if score > 0.5 && (bestMatch == nil || score > bestMatch!.score) {
                        bestMatch = (procedure.id, procedure.title, score)
                    }
                }
            }
        }

        if let match = bestMatch {
            return ProcedureMappingResult(
                originalName: name,
                mappedId: match.id,
                mappedTitle: match.title,
                confidence: match.score,
                mappingType: .catalogMatch
            )
        }

        return nil
    }

    /// Calculate string similarity (Jaccard-like coefficient)
    private static func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
        if s1 == s2 { return 1.0 }
        if s1.isEmpty || s2.isEmpty { return 0.0 }

        // Check containment
        if s1.contains(s2) { return 0.9 }
        if s2.contains(s1) { return 0.85 }

        // Word-based similarity
        let words1 = Set(s1.split(separator: " ").map(String.init))
        let words2 = Set(s2.split(separator: " ").map(String.init))

        let intersection = words1.intersection(words2)
        let union = words1.union(words2)

        guard !union.isEmpty else { return 0.0 }
        return Double(intersection.count) / Double(union.count)
    }

    // MARK: - Bulk Migration

    /// Migrate an array of legacy procedure names
    static func migrateProcedures(_ legacyNames: [String]) -> [ProcedureMappingResult] {
        return legacyNames.map { mapProcedureWithDetails($0) }
    }

    /// Get statistics about a migration batch
    static func getMigrationStats(_ results: [ProcedureMappingResult]) -> MigrationStats {
        let mapped = results.filter { $0.mappedId != nil }
        let unmapped = results.filter { $0.mappedId == nil }
        let highConfidence = mapped.filter { $0.confidence >= 0.8 }
        let lowConfidence = mapped.filter { $0.confidence < 0.8 }

        return MigrationStats(
            total: results.count,
            mappedCount: mapped.count,
            unmappedCount: unmapped.count,
            highConfidenceCount: highConfidence.count,
            lowConfidenceCount: lowConfidence.count,
            unmappedProcedures: unmapped.map { $0.originalName }
        )
    }
}

// MARK: - Supporting Types

struct ProcedureMappingResult: Identifiable {
    let id = UUID()
    let originalName: String
    let mappedId: String?
    let mappedTitle: String?
    let confidence: Double
    let mappingType: MappingType

    enum MappingType: String {
        case exact = "Exact Match"
        case legacyId = "Legacy ID"
        case fuzzy = "Fuzzy Match"
        case catalogMatch = "Catalog Match"
        case unmapped = "Not Mapped"
    }

    var isSuccessfullyMapped: Bool {
        mappedId != nil
    }

    var confidenceLevel: ConfidenceLevel {
        if confidence >= 0.9 { return .high }
        if confidence >= 0.7 { return .medium }
        if confidence >= 0.5 { return .low }
        return .none
    }

    enum ConfidenceLevel: String {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        case none = "None"

        var color: String {
            switch self {
            case .high: return "green"
            case .medium: return "orange"
            case .low: return "yellow"
            case .none: return "red"
            }
        }
    }
}

struct MigrationStats {
    let total: Int
    let mappedCount: Int
    let unmappedCount: Int
    let highConfidenceCount: Int
    let lowConfidenceCount: Int
    let unmappedProcedures: [String]

    var mappedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(mappedCount) / Double(total) * 100
    }

    var successRate: String {
        String(format: "%.1f%%", mappedPercentage)
    }
}
