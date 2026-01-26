// Enums.swift
// Procedus - Unified
// SINGLE SOURCE OF TRUTH for all enums
// NOTE: Remove any duplicate enum definitions from Models.swift after adding this file

import Foundation
import SwiftUI

// MARK: - Account Mode

enum AccountMode: String, Codable, CaseIterable {
    case individual = "individual"
    case institutional = "institutional"
    
    var displayName: String {
        switch self {
        case .individual: return "Individual"
        case .institutional: return "Institutional"
        }
    }
}

// MARK: - User Role

enum UserRole: String, Codable, CaseIterable {
    case fellow = "Fellow"
    case attending = "Attending"
    case admin = "Admin"
    
    var displayName: String { rawValue }
    
    var color: Color {
        switch self {
        case .fellow: return .blue
        case .attending: return .green
        case .admin: return .orange
        }
    }
    
    var iconName: String {
        switch self {
        case .fellow: return "graduationcap.fill"
        case .attending: return "stethoscope"
        case .admin: return "gear"
        }
    }
}

// MARK: - Attestation Status

enum AttestationStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case requested = "requested"
    case attested = "attested"
    case rejected = "rejected"
    case proxyAttested = "proxyAttested"  // Admin attested on behalf of Attending
    case notRequired = "notRequired"       // Individual mode cases
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .requested: return "Requested"
        case .attested: return "Attested"
        case .rejected: return "Rejected"
        case .proxyAttested: return "Proxy Attested"
        case .notRequired: return "N/A"
        }
    }
    
    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .requested: return "paperplane"
        case .attested: return "checkmark.seal.fill"
        case .rejected: return "xmark.seal.fill"
        case .proxyAttested: return "checkmark.seal"
        case .notRequired: return "minus.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .requested: return .blue
        case .attested: return .green
        case .rejected: return .red
        case .proxyAttested: return Color(red: 0.4, green: 0.6, blue: 0.3) // Muted green
        case .notRequired: return .gray
        }
    }
    
    /// Whether this status counts in analytics (excludes rejected)
    var countsInAnalytics: Bool {
        switch self {
        case .rejected: return false
        default: return true
        }
    }
}

// MARK: - Rejection Reason (Checkbox options for rejection)

enum RejectionReason: String, Codable, CaseIterable, Identifiable {
    case incorrectAttending = "Incorrect attending assigned"
    case incorrectFacility = "Incorrect facility"
    case missingInformation = "Missing required information"
    case duplicateEntry = "Duplicate case entry"
    case incorrectProcedures = "Incorrect procedures selected"
    case incorrectDate = "Incorrect date/timeframe"
    case other = "Other (specify below)"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
}

// MARK: - Case Outcome

enum CaseOutcome: String, CaseIterable, Codable, Identifiable {
    case success = "Success"
    case complication = "Complication"
    case partialSuccess = "Partial Success"
    case aborted = "Aborted"
    case death = "Death"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .complication: return .orange
        case .partialSuccess: return .yellow
        case .aborted: return .gray
        case .death: return .red
        }
    }
    
    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .complication: return "exclamationmark.triangle.fill"
        case .partialSuccess: return "checkmark.circle"
        case .aborted: return "xmark.circle"
        case .death: return "xmark.circle.fill"
        }
    }
}

// MARK: - Procedure Category

enum ProcedureCategory: String, Codable, CaseIterable, Identifiable {
    // Cardiology
    case cardiacDiagnostic = "Cardiac Diagnostic"
    case coronaryIntervention = "Coronary Intervention"
    case peripheralArterial = "Peripheral Arterial"
    case venousPE = "Venous/PE"
    case structuralValve = "Structural/Valve"
    case aortic = "Aortic"
    case mcs = "MCS"
    case ep = "EP"
    case epDiagnostic = "EP Diagnostic"
    case ablation = "Ablation"
    case implants = "Implants"
    case closureDevices = "Closure Devices"
    
    // Imaging
    case echo = "Echo"
    case nuclear = "Nuclear"
    case cardiacCT = "Cardiac CT"
    case cardiacMRI = "Cardiac MRI"
    case vascularUltrasound = "Vascular Ultrasound"
    
    // General categories for multiple specialties
    case diagnostic = "Diagnostic"
    case therapeutic = "Therapeutic"
    case emergent = "Emergent"
    case elective = "Elective"
    case endoscopic = "Endoscopic"
    case laparoscopic = "Laparoscopic"
    case open = "Open"
    case robotic = "Robotic"
    case imagingGuided = "Imaging-Guided"
    case bedside = "Bedside"
    case airway = "Airway"
    case vascularAccess = "Vascular Access"
    case regional = "Regional"
    case neuraxial = "Neuraxial"
    case sedation = "Sedation"
    case resuscitation = "Resuscitation"
    case trauma = "Trauma"
    case obstetric = "Obstetric"
    case gynecologic = "Gynecologic"
    case upperGI = "Upper GI"
    case lowerGI = "Lower GI"
    case hepatobiliary = "Hepatobiliary"
    case bronchoscopy = "Bronchoscopy"
    case thoracic = "Thoracic"
    case jointArthroscopy = "Joint/Arthroscopy"
    case fractureCare = "Fracture Care"
    case spinal = "Spinal"
    case softTissue = "Soft Tissue"
    case cranial = "Cranial"
    case neuroVascular = "Neurovascular"
    case neuroSpine = "Neurospine"
    case plasticBreast = "Breast"
    case plasticBody = "Body Contouring"
    case plasticFace = "Face"
    case plasticHand = "Hand"
    case plasticReconstructive = "Reconstructive"
    case urinaryLower = "Lower Urinary"
    case urinaryUpper = "Upper Urinary"
    case urinaryMale = "Male GU"
    case entHead = "Head & Neck"
    case entOtology = "Otology"
    case entRhinology = "Rhinology"
    case ophthCataract = "Cataract"
    case ophthRetina = "Retina"
    case ophthGlaucoma = "Glaucoma"
    case ophthOculoplastics = "Oculoplastics"
    case ophthCornea = "Cornea"
    case ophthStrabismus = "Strabismus"
    case pediatric = "Pediatric"
    case biopsy = "Biopsy"
    case excision = "Excision"
    case mohs = "Mohs Surgery"
    case injection = "Injection"
    case block = "Block"
    case neuromodulation = "Neuromodulation"
    case irVascular = "Vascular IR"
    case irNonVascular = "Non-Vascular IR"
    case irOncology = "Oncologic IR"
    case dialysis = "Dialysis"
    case arthroplasty = "Arthroplasty"
    case reconstructive = "Reconstructive Surgery"
    case aesthetic = "Aesthetic"
    case endourology = "Endourology"
    case andrology = "Andrology"
    case otology = "Otology Surgery"
    case rhinology = "Rhinology Surgery"
    case laryngology = "Laryngology"
    case headNeck = "Head and Neck"
    case anterior = "Anterior Segment"
    case glaucoma = "Glaucoma Surgery"
    case posterior = "Posterior Segment"
    case oculoplastic = "Oculoplastic Surgery"
    case other = "Other"
    
    var id: String { rawValue }
    
    /// Bubble letter for category visualization
    /// Letters should be the first letter of the category name where possible
    /// Where conflicts exist, use distinct colors to differentiate
    var bubbleLetter: String? {
        switch self {
        // Interventional Cardiology categories
        case .cardiacDiagnostic: return "D"   // Diagnostic
        case .coronaryIntervention: return "I" // Intervention
        case .peripheralArterial: return "P"   // Peripheral
        case .venousPE: return "V"             // Venous
        case .structuralValve: return "S"      // Structural
        case .aortic: return "A"               // Aortic
        case .mcs: return "M"                  // MCS
        case .bedside: return "B"              // Bedside
        case .closureDevices: return nil       // No bubble for closure devices

        // Electrophysiology categories
        case .ep, .epDiagnostic: return "E"   // EP
        case .ablation: return "A"             // Ablation (blue to distinguish from Aortic)
        case .implants: return "I"             // Implants

        // Cardiac Imaging categories (unique letters to avoid conflicts)
        case .echo: return "E"                 // Echo (cyan to distinguish from EP green)
        case .nuclear: return "N"              // Nuclear
        case .cardiacCT: return "C"            // CT
        case .cardiacMRI: return "M"           // MRI
        case .vascularUltrasound: return "V"   // Vascular

        // General categories
        case .other: return "O"
        default: return String(rawValue.prefix(1))
        }
    }
    
    /// Color for category bubble
    /// Each letter+color combination should be unique within a user's enabled packs
    var bubbleColor: Color {
        switch self {
        // Interventional Cardiology categories
        case .cardiacDiagnostic: return Color(red: 0.30, green: 0.60, blue: 0.85)  // Light blue
        case .coronaryIntervention: return Color(red: 0.85, green: 0.35, blue: 0.35)  // Red
        case .peripheralArterial: return Color(red: 0.55, green: 0.40, blue: 0.75)  // Purple
        case .venousPE: return Color(red: 0.35, green: 0.45, blue: 0.75)  // Dark blue
        case .structuralValve: return Color(red: 0.95, green: 0.60, blue: 0.25)  // Orange
        case .aortic: return Color(red: 0.85, green: 0.45, blue: 0.55)  // Pink/Rose
        case .mcs: return Color(red: 0.25, green: 0.65, blue: 0.65)  // Teal
        case .bedside: return Color(red: 0.55, green: 0.55, blue: 0.55)  // Gray
        case .closureDevices: return .clear

        // Electrophysiology categories
        case .ep, .epDiagnostic: return Color(red: 0.35, green: 0.65, blue: 0.45)  // Green
        case .ablation: return Color(red: 0.30, green: 0.50, blue: 0.85)  // Blue (distinct from Aortic pink)
        case .implants: return Color(red: 0.50, green: 0.50, blue: 0.80)  // Purple-blue

        // Cardiac Imaging categories (distinct from cardiology)
        case .echo: return Color(red: 0.00, green: 0.75, blue: 0.75)  // Cyan (distinct from EP green)
        case .nuclear: return Color(red: 0.75, green: 0.55, blue: 0.00)  // Gold/Amber
        case .cardiacCT: return Color(red: 0.60, green: 0.30, blue: 0.60)  // Magenta
        case .cardiacMRI: return Color(red: 0.20, green: 0.50, blue: 0.70)  // Steel blue
        case .vascularUltrasound: return Color(red: 0.45, green: 0.70, blue: 0.50)  // Sage green

        // General categories
        case .other: return Color(red: 0.50, green: 0.55, blue: 0.60)
        default: return Color(red: 0.45, green: 0.55, blue: 0.65)
        }
    }
    
    /// Alias for bubbleColor
    var color: Color { bubbleColor }
}

// MARK: - Complication

enum Complication: String, CaseIterable, Codable, Identifiable {
    case bleeding = "Bleeding"
    case vascular = "Vascular Injury"
    case stroke = "Stroke/TIA"
    case renalInjury = "Renal/AKI"
    case tamponade = "Tamponade"
    case perforation = "Perforation"
    case mi = "MI"
    case death = "Death"
    case infection = "Infection"
    case pneumothorax = "Pneumothorax"
    case hematoma = "Hematoma"
    case arrhythmia = "Arrhythmia"
    case hypotension = "Hypotension"
    case allergicReaction = "Allergic Reaction"
    case arterialPuncture = "Arterial Puncture"
    case csfLeak = "CSF Leak"
    case localAnestheticToxicity = "Local Anesthetic Toxicity"
    case postDuralHeadache = "Post-Dural Puncture Headache"
    case aspiration = "Aspiration"
    case anastomoticLeak = "Anastomotic Leak"
    case woundDehiscence = "Wound Dehiscence"
    case dvtPe = "DVT/PE"
    case ileus = "Ileus"
    case nerveInjury = "Nerve Injury"
    case compartmentSyndrome = "Compartment Syndrome"
    case cardiacArrest = "Cardiac Arrest"
    case airwayCompromise = "Airway Compromise"
    case urinaryRetention = "Urinary Retention"
    case respiratoryFailure = "Respiratory Failure"
    case seroma = "Seroma"
    case other = "Other"
    
    var id: String { rawValue }
}

// MARK: - Access Site

enum AccessSite: String, CaseIterable, Codable, Identifiable {
    case femoral = "Femoral"
    case radial = "Radial"
    case brachial = "Brachial"
    case pedal = "Pedal"
    case jugular = "Jugular"
    case subclavian = "Subclavian"
    case axillary = "Axillary"
    case antegrade = "Antegrade"
    case pericardial = "Pericardial"
    case transseptal = "Transseptal"
    case transapical = "Transapical"
    case transcaval = "Transcaval"
    case percutaneous = "Percutaneous"
    case transvaginal = "Transvaginal"
    case transrectal = "Transrectal"
    case transoral = "Transoral"
    case oral = "Oral"
    case nasal = "Nasal"
    case transanal = "Transanal"
    case laparoscopicPort = "Laparoscopic Port"
    case openIncision = "Open Incision"
    case roboticPort = "Robotic Port"
    
    var id: String { rawValue }
}

// MARK: - Thrombectomy Device (for PE/DVT procedures)

enum ThrombectomyDevice: String, CaseIterable, Codable, Identifiable {
    case penumbra = "Penumbra"
    case ekos = "EKOS"
    case angiovac = "AngioVac"
    case inari = "Inari"

    var id: String { rawValue }

    /// Procedure IDs that should show device selection
    static let eligibleProcedureIds: Set<String> = [
        "ic-venous-pe-cdt",  // PE CDT/Thrombectomy
        "ic-venous-dvt"      // DVT Intervention
    ]

    /// Check if a procedure should show device selection
    static func isEligible(procedureId: String) -> Bool {
        eligibleProcedureIds.contains(procedureId)
    }
}

// MARK: - PGY Level

enum PGYLevel: Int, Codable, CaseIterable, Identifiable {
    case pgy1 = 1
    case pgy2 = 2
    case pgy3 = 3
    case pgy4 = 4
    case pgy5 = 5
    case pgy6 = 6
    case pgy7 = 7
    case pgy8 = 8
    
    var id: Int { rawValue }
    
    var displayName: String {
        "PGY-\(rawValue)"
    }
}

// MARK: - Evaluation Mode (Admin configurable)

enum EvaluationMode: String, Codable, CaseIterable {
    case disabled = "disabled"
    case optional = "optional"
    case mandatory = "mandatory"
    
    var displayName: String {
        switch self {
        case .disabled: return "Disabled"
        case .optional: return "Optional"
        case .mandatory: return "Mandatory"
        }
    }
}

// MARK: - Evaluation Field Type

enum EvaluationFieldType: String, Codable, CaseIterable {
    case checkbox = "checkbox"
    case rating = "rating"
    case multiSelect = "multiSelect"
    case text = "text"
    
    var displayName: String {
        switch self {
        case .checkbox: return "Checkbox"
        case .rating: return "Rating (1-5)"
        case .multiSelect: return "Multiple Choice"
        case .text: return "Free Text"
        }
    }
}

// MARK: - Analytics Range

enum ProcedusAnalyticsRange: String, CaseIterable, Identifiable {
    case week = "This Week"
    case last30Days = "Last 30 Days"
    case monthToDate = "Month to Date"
    case yearToDate = "Year to Date"
    case academicYearToDate = "Academic Year"
    case pgy = "PGY (By Year)"
    case allTime = "All Time"
    case custom = "Custom"

    var id: String { rawValue }
}

enum AnalyticsChartType: String, CaseIterable, Identifiable {
    case bar = "Bar"
    case line = "Line"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .bar: return "chart.bar.fill"
        case .line: return "chart.line.uptrend.xyaxis"
        }
    }
}

enum ChartGrouping: String, CaseIterable, Identifiable {
    case weeks = "Weeks"
    case months = "Months"
    case quarters = "Quarters"
    case years = "Years"
    case pgyYears = "PGY Years"

    var id: String { rawValue }

    var xAxisLabel: String {
        switch self {
        case .weeks: return "Week"
        case .months: return "Month"
        case .quarters: return "Quarter"
        case .years: return "Year"
        case .pgyYears: return "PGY Level"
        }
    }

    var systemImage: String {
        switch self {
        case .weeks: return "calendar.day.timeline.left"
        case .months: return "calendar"
        case .quarters: return "calendar.badge.clock"
        case .years: return "calendar.circle"
        case .pgyYears: return "person.badge.clock"
        }
    }
}

// MARK: - Notification Type

enum NotificationType: String, Codable, CaseIterable {
    case attestationRequested = "attestation_requested"
    case attestationComplete = "attestation_complete"
    case caseRejected = "case_rejected"
    case programChange = "program_change"
    case programUpdate = "program_update"
    case procedureAdded = "procedure_added"
    case categoryAdded = "category_added"
    case userInvite = "user_invite"
    case reminder = "reminder"
    case info = "info"
    case badgeEarned = "badge_earned"
    case dutyHoursWarning = "duty_hours_warning"
    case dutyHoursViolation = "duty_hours_violation"
    case directMessage = "direct_message"
    case teachingFileUploaded = "teaching_file_uploaded"
    case teachingFileComment = "teachingFileComment"

    var icon: String {
        switch self {
        case .attestationRequested: return "paperplane.fill"
        case .attestationComplete: return "checkmark.seal.fill"
        case .caseRejected: return "xmark.seal.fill"
        case .programChange: return "gear"
        case .programUpdate: return "megaphone.fill"
        case .procedureAdded: return "plus.circle"
        case .categoryAdded: return "folder.badge.plus"
        case .userInvite: return "person.badge.plus"
        case .reminder: return "bell.fill"
        case .info: return "info.circle.fill"
        case .badgeEarned: return "trophy.fill"
        case .dutyHoursWarning: return "exclamationmark.triangle.fill"
        case .dutyHoursViolation: return "xmark.shield.fill"
        case .directMessage: return "message.fill"
        case .teachingFileUploaded: return "photo.badge.plus"
        case .teachingFileComment: return "text.bubble.fill"
        }
    }

    var color: Color {
        switch self {
        case .attestationRequested: return .blue
        case .attestationComplete: return .green
        case .caseRejected: return .red
        case .programChange: return .orange
        case .programUpdate: return .purple
        case .procedureAdded: return .purple
        case .categoryAdded: return .purple
        case .userInvite: return .blue
        case .reminder: return .orange
        case .info: return .gray
        case .badgeEarned: return .yellow
        case .dutyHoursWarning: return .orange
        case .dutyHoursViolation: return .red
        case .directMessage: return .blue
        case .teachingFileUploaded: return .teal
        case .teachingFileComment: return .teal
        }
    }
}

// MARK: - Audit Action Types

enum AuditActionType: String, Codable, CaseIterable {
    case created = "created"
    case updated = "updated"
    case deleted = "deleted"
    case archived = "archived"
    case reactivated = "reactivated"
    case attested = "attested"
    case rejected = "rejected"
    case proxyAttested = "proxy_attested"
    case imported = "imported"
    case exported = "exported"
    case loggedIn = "logged_in"
    case loggedOut = "logged_out"
    case mediaAdded = "media_added"
    case mediaTextDetected = "media_text_detected"
    case mediaPHIConfirmed = "media_phi_confirmed"
    case mediaRedacted = "media_redacted"
    case mediaDeleted = "media_deleted"
    case mediaUploadedToCloud = "media_uploaded_to_cloud"
    case unknown = "unknown"

    var pastTense: String {
        switch self {
        case .created: return "created"
        case .updated: return "updated"
        case .deleted: return "deleted"
        case .archived: return "archived"
        case .reactivated: return "reactivated"
        case .attested: return "attested"
        case .rejected: return "rejected"
        case .proxyAttested: return "proxy attested"
        case .imported: return "imported"
        case .exported: return "exported"
        case .loggedIn: return "logged in"
        case .loggedOut: return "logged out"
        case .mediaAdded: return "added media to"
        case .mediaTextDetected: return "detected text in media for"
        case .mediaPHIConfirmed: return "confirmed no PHI in media for"
        case .mediaRedacted: return "redacted PHI in media for"
        case .mediaDeleted: return "deleted media from"
        case .mediaUploadedToCloud: return "uploaded media to cloud for"
        case .unknown: return "performed action on"
        }
    }

    var icon: String {
        switch self {
        case .created: return "plus.circle"
        case .updated: return "pencil.circle"
        case .deleted: return "trash.circle"
        case .archived: return "archivebox"
        case .reactivated: return "arrow.uturn.backward.circle"
        case .attested: return "checkmark.seal"
        case .rejected: return "xmark.seal"
        case .proxyAttested: return "checkmark.seal.fill"
        case .imported: return "square.and.arrow.down"
        case .exported: return "square.and.arrow.up"
        case .loggedIn: return "person.badge.plus"
        case .loggedOut: return "person.badge.minus"
        case .mediaAdded: return "photo.badge.plus"
        case .mediaTextDetected: return "doc.text.magnifyingglass"
        case .mediaPHIConfirmed: return "checkmark.shield"
        case .mediaRedacted: return "rectangle.inset.filled"
        case .mediaDeleted: return "photo.badge.minus"
        case .mediaUploadedToCloud: return "icloud.and.arrow.up"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Audit Entity Types

enum AuditEntityType: String, Codable, CaseIterable {
    case caseEntry = "case"
    case user = "user"
    case program = "program"
    case procedure = "procedure"
    case category = "category"
    case facility = "facility"
    case attending = "attending"
    case evaluationField = "evaluation_field"
    case notification = "notification"
    case caseMedia = "case_media"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .caseEntry: return "case"
        case .user: return "user"
        case .program: return "program"
        case .procedure: return "custom procedure"
        case .category: return "category"
        case .facility: return "facility"
        case .attending: return "attending"
        case .evaluationField: return "evaluation field"
        case .notification: return "notification"
        case .caseMedia: return "case media"
        case .unknown: return "item"
        }
    }
}

// MARK: - Import Mapping Status

enum MappingStatus: String, Codable {
    case mapped = "Mapped"
    case unmapped = "Unmapped"
    case customNew = "New Custom"
    case skipped = "Skipped"
}

// MARK: - Fellowship Specialty

enum FellowshipSpecialty: String, Codable, CaseIterable, Identifiable {
    // Cardiology (combined - represents all 3 cardiology packs)
    case cardiology = "Cardiology"

    // Other fellowships (1:1 with specialty packs)
    case gastroenterology = "Gastroenterology"
    case pulmonaryCriticalCare = "Pulmonary & Critical Care"
    case nephrology = "Nephrology"
    case painMedicine = "Pain Medicine"
    case interventionalRadiology = "Interventional Radiology"

    // Residencies
    case generalSurgery = "General Surgery"
    case orthopedicSurgery = "Orthopedic Surgery"
    case emergencyMedicine = "Emergency Medicine"
    case anesthesiology = "Anesthesiology"
    case obgyn = "OB/GYN"
    case neurosurgery = "Neurosurgery"
    case cardiothoracicSurgery = "Cardiothoracic Surgery"
    case vascularSurgery = "Vascular Surgery"
    case plasticSurgery = "Plastic Surgery"
    case urology = "Urology"
    case entOtolaryngology = "ENT"
    case ophthalmology = "Ophthalmology"
    case internalMedicine = "Internal Medicine"
    case familyMedicine = "Family Medicine"
    case pediatrics = "Pediatrics"
    case dermatology = "Dermatology"

    var id: String { rawValue }

    var displayName: String { rawValue }

    /// Maps specialty to its default specialty pack IDs
    var defaultPackIds: [String] {
        switch self {
        case .cardiology:
            return ["interventional-cardiology", "electrophysiology", "cardiac-imaging"]
        case .gastroenterology:
            return ["gastroenterology"]
        case .pulmonaryCriticalCare:
            return ["pulmonary-critical-care"]
        case .nephrology:
            return ["nephrology"]
        case .painMedicine:
            return ["pain-medicine"]
        case .interventionalRadiology:
            return ["interventional-radiology"]
        case .generalSurgery:
            return ["general-surgery"]
        case .orthopedicSurgery:
            return ["orthopedic-surgery"]
        case .emergencyMedicine:
            return ["emergency-medicine"]
        case .anesthesiology:
            return ["anesthesiology"]
        case .obgyn:
            return ["obgyn"]
        case .neurosurgery:
            return ["neurosurgery"]
        case .cardiothoracicSurgery:
            return ["cardiothoracic-surgery"]
        case .vascularSurgery:
            return ["vascular-surgery"]
        case .plasticSurgery:
            return ["plastic-surgery"]
        case .urology:
            return ["urology"]
        case .entOtolaryngology:
            return ["ent-otolaryngology"]
        case .ophthalmology:
            return ["ophthalmology"]
        case .internalMedicine:
            return ["internal-medicine"]
        case .familyMedicine:
            return ["family-medicine"]
        case .pediatrics:
            return ["pediatrics"]
        case .dermatology:
            return ["dermatology"]
        }
    }

    /// Whether this specialty is cardiology-based (shows invasive/noninvasive toggle)
    var isCardiology: Bool {
        self == .cardiology
    }

    /// Icon for UI display
    var iconName: String {
        switch self {
        case .cardiology: return "heart.fill"
        case .gastroenterology: return "fork.knife"
        case .pulmonaryCriticalCare: return "lungs.fill"
        case .nephrology: return "drop.fill"
        case .painMedicine: return "cross.vial.fill"
        case .interventionalRadiology: return "rays"
        case .generalSurgery: return "scissors"
        case .orthopedicSurgery: return "figure.walk"
        case .emergencyMedicine: return "cross.case.fill"
        case .anesthesiology: return "sleep"
        case .obgyn: return "figure.stand.dress"
        case .neurosurgery: return "brain.head.profile"
        case .cardiothoracicSurgery: return "heart.circle.fill"
        case .vascularSurgery: return "waveform.path"
        case .plasticSurgery: return "hand.raised.fill"
        case .urology: return "drop.triangle.fill"
        case .entOtolaryngology: return "ear.fill"
        case .ophthalmology: return "eye.fill"
        case .internalMedicine: return "stethoscope"
        case .familyMedicine: return "house.fill"
        case .pediatrics: return "figure.2.and.child.holdinghands"
        case .dermatology: return "hand.point.up.braille.fill"
        }
    }
}

// MARK: - Case Type (Invasive vs Noninvasive)

enum CaseType: String, Codable, CaseIterable, Identifiable {
    case invasive = "Invasive"
    case ep = "EP"
    case noninvasive = "Noninvasive"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .invasive: return "arrow.right.circle.fill"
        case .ep: return "bolt.heart.fill"
        case .noninvasive: return "waveform.path.ecg"
        }
    }

    var color: Color {
        switch self {
        case .invasive: return .red
        case .ep: return .green
        case .noninvasive: return .blue
        }
    }
}

// MARK: - Operator Position (Cardiology-specific)

enum OperatorPosition: String, Codable, CaseIterable, Identifiable {
    case primary = "Primary"
    case secondary = "Secondary"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .primary: return "1.circle.fill"
        case .secondary: return "2.circle.fill"
        }
    }
}

// MARK: - Notification Frequency

enum NotificationFrequency: String, Codable, CaseIterable, Identifiable {
    case immediate = "immediate"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .immediate: return "Immediate"
        case .daily: return "Daily Digest"
        case .weekly: return "Weekly Digest"
        case .monthly: return "Monthly Digest"
        }
    }

    var description: String {
        switch self {
        case .immediate: return "Get notified right away"
        case .daily: return "One summary each day"
        case .weekly: return "One summary each week"
        case .monthly: return "One summary each month"
        }
    }

    var icon: String {
        switch self {
        case .immediate: return "bolt.fill"
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        }
    }
}

// MARK: - Badge Type

enum BadgeType: String, Codable, CaseIterable, Identifiable {
    case firstProcedure = "first_procedure"       // First time doing a procedure
    case firstAsPrimary = "first_as_primary"      // First time as primary operator
    case milestone = "milestone"                   // Every N procedures (50, 100, etc.)
    case categoryMilestone = "category_milestone"  // Total in a category
    case totalCases = "total_cases"               // Total case count milestones
    case diversity = "diversity"                   // Procedure type diversity
    case cocatsTraining = "cocats_training"       // COCATS training level requirements

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .firstProcedure: return "First Procedure"
        case .firstAsPrimary: return "First as Primary"
        case .milestone: return "Milestone"
        case .categoryMilestone: return "Category Milestone"
        case .totalCases: return "Total Cases"
        case .diversity: return "Balance"
        case .cocatsTraining: return "COCATS Training"
        }
    }

    var iconName: String {
        switch self {
        case .firstProcedure: return "1.circle.fill"
        case .firstAsPrimary: return "star.circle.fill"
        case .milestone: return "flag.checkered"
        case .categoryMilestone: return "chart.bar.fill"
        case .totalCases: return "number.circle.fill"
        case .diversity: return "scale.3d"  // Balance scale icon
        case .cocatsTraining: return "graduationcap.fill"
        }
    }

    var color: Color {
        switch self {
        case .firstProcedure: return .blue
        case .firstAsPrimary: return .purple
        case .milestone: return .orange
        case .categoryMilestone: return .green
        case .totalCases: return .cyan
        case .diversity: return .pink
        case .cocatsTraining: return .red
        }
    }
}

// MARK: - Badge Tier

enum BadgeTier: Int, Codable, CaseIterable, Identifiable {
    case bronze = 1
    case silver = 2
    case gold = 3
    case platinum = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        }
    }

    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)  // Warm bronze/copper
        case .silver: return Color(red: 0.45, green: 0.55, blue: 0.7)  // Distinct blue-silver
        case .gold: return Color(red: 1.0, green: 0.75, blue: 0.0)  // Rich gold
        case .platinum: return Color(red: 0.4, green: 0.6, blue: 0.8)  // Vibrant platinum-blue
        }
    }

    var iconName: String {
        switch self {
        case .bronze: return "circle.fill"
        case .silver: return "star.fill"
        case .gold: return "crown.fill"
        case .platinum: return "trophy.fill"
        }
    }

    /// Description explaining what this tier represents
    var tierDescription: String {
        switch self {
        case .bronze:
            return "Getting Started - Early milestones and first experiences"
        case .silver:
            return "Building Competence - Developing skills and consistency"
        case .gold:
            return "Demonstrating Mastery - Advanced achievements and expertise"
        case .platinum:
            return "Elite Performance - Exceptional accomplishments and leadership"
        }
    }

    /// Point range typically associated with this tier
    var pointRange: String {
        switch self {
        case .bronze: return "10-25 points"
        case .silver: return "25-50 points"
        case .gold: return "50-100 points"
        case .platinum: return "100+ points"
        }
    }
}

// MARK: - Media Type

enum MediaType: String, Codable, CaseIterable, Identifiable {
    case image
    case video

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .image: return "Image"
        case .video: return "Video"
        }
    }

    var systemImage: String {
        switch self {
        case .image: return "photo"
        case .video: return "video"
        }
    }

    var allowedExtensions: [String] {
        switch self {
        case .image: return ["jpg", "jpeg", "png", "heic", "heif"]
        case .video: return ["mp4", "mov", "m4v"]
        }
    }
}

// MARK: - Media Upload Status

enum MediaUploadStatus: String, Codable, CaseIterable {
    case pending
    case uploading
    case uploaded
    case failed

    var displayName: String {
        switch self {
        case .pending: return "Pending Upload"
        case .uploading: return "Uploading…"
        case .uploaded: return "Uploaded to Cloud"
        case .failed: return "Upload Failed"
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .uploading: return "arrow.up.circle"
        case .uploaded: return "checkmark.cloud.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .gray
        case .uploading: return .blue
        case .uploaded: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Duty Hours Shift Type

enum DutyHoursShiftType: String, Codable, CaseIterable, Identifiable {
    case regular = "Regular"
    case call = "Call"
    case nightFloat = "Night Float"
    case moonlighting = "Moonlighting"
    case atHomeCall = "At-Home Call"
    case dayOff = "Day Off"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .regular: return "clock.fill"
        case .call: return "phone.fill"
        case .nightFloat: return "moon.fill"
        case .moonlighting: return "moon.stars.fill"
        case .atHomeCall: return "house.fill"
        case .dayOff: return "sun.max.fill"
        }
    }

    var color: Color {
        switch self {
        case .regular: return .blue
        case .call: return .orange
        case .nightFloat: return .purple
        case .moonlighting: return .indigo
        case .atHomeCall: return .green
        case .dayOff: return .mint
        }
    }

    /// Whether this shift type counts toward ACGME duty hour limits
    var countsTowardHourLimits: Bool {
        switch self {
        case .dayOff: return false
        default: return true
        }
    }

    /// Whether this is considered a call shift for call frequency calculations
    var isCallShift: Bool {
        switch self {
        case .call, .nightFloat: return true
        default: return false
        }
    }
}

// MARK: - Duty Hours Logging Mode

enum DutyHoursLoggingMode: String, Codable, CaseIterable, Identifiable {
    case simple = "Simple"
    case comprehensive = "Comprehensive"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var description: String {
        switch self {
        case .simple: return "Log weekly totals only"
        case .comprehensive: return "Track individual shifts with ACGME compliance"
        }
    }

    var iconName: String {
        switch self {
        case .simple: return "list.bullet"
        case .comprehensive: return "clock.badge.checkmark"
        }
    }
}

// MARK: - Duty Hours Violation Type

enum DutyHoursViolationType: String, Codable, CaseIterable, Identifiable {
    case weeklyHoursExceeded = "Weekly Hours Exceeded"
    case continuousDutyExceeded = "Continuous Duty Exceeded"
    case insufficientRestAfter24 = "Insufficient Rest After 24hr Shift"
    case insufficientInterShiftRest = "Insufficient Inter-Shift Rest"
    case insufficientDaysOff = "Insufficient Days Off"
    case callFrequencyExceeded = "Call Frequency Exceeded"
    case nightFloatExceeded = "Night Float Limit Exceeded"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var acgmeReference: String {
        switch self {
        case .weeklyHoursExceeded: return "ACGME VI.F.1 - 80 hours/week (4-week average)"
        case .continuousDutyExceeded: return "ACGME VI.F.3 - 24 hours continuous duty"
        case .insufficientRestAfter24: return "ACGME VI.F.4 - 14 hours rest after 24hr shift"
        case .insufficientInterShiftRest: return "ACGME VI.F.5 - 8-10 hours between shifts"
        case .insufficientDaysOff: return "ACGME VI.F.6 - 1 day off per 7 days (4-week average)"
        case .callFrequencyExceeded: return "ACGME VI.F.7 - No more than every 3rd night call"
        case .nightFloatExceeded: return "ACGME VI.F.8 - 6 consecutive nights maximum"
        }
    }

    var iconName: String {
        switch self {
        case .weeklyHoursExceeded: return "clock.badge.exclamationmark"
        case .continuousDutyExceeded: return "hourglass.badge.plus"
        case .insufficientRestAfter24: return "bed.double.fill"
        case .insufficientInterShiftRest: return "moon.zzz.fill"
        case .insufficientDaysOff: return "calendar.badge.exclamationmark"
        case .callFrequencyExceeded: return "phone.badge.plus"
        case .nightFloatExceeded: return "moon.stars.fill"
        }
    }

    var color: Color {
        switch self {
        case .weeklyHoursExceeded: return .red
        case .continuousDutyExceeded: return .red
        case .insufficientRestAfter24: return .orange
        case .insufficientInterShiftRest: return .orange
        case .insufficientDaysOff: return .yellow
        case .callFrequencyExceeded: return .orange
        case .nightFloatExceeded: return .purple
        }
    }
}

// MARK: - Violation Severity

enum ViolationSeverity: String, Codable, CaseIterable, Identifiable {
    case minor = "Minor"
    case major = "Major"
    case critical = "Critical"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var color: Color {
        switch self {
        case .minor: return .yellow
        case .major: return .orange
        case .critical: return .red
        }
    }

    var iconName: String {
        switch self {
        case .minor: return "exclamationmark.triangle"
        case .major: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    var description: String {
        switch self {
        case .minor: return "Approaching limit - requires monitoring"
        case .major: return "Limit exceeded - requires attention"
        case .critical: return "Significant violation - immediate action required"
        }
    }
}

// MARK: - Duty Hours Shift Location

enum DutyHoursShiftLocation: String, Codable, CaseIterable, Identifiable {
    case inHouse = "In-House"
    case atHome = "At Home"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .inHouse: return "building.2.fill"
        case .atHome: return "house.fill"
        }
    }
}
