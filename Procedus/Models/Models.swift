// Models.swift
// Procedus - Unified
// Complete data models for Individual and Institutional modes

import Foundation
import SwiftData
import SwiftUI

// MARK: - Program Model

@Model
final class Program {
    @Attribute(.unique) var id: UUID
    var programCode: String
    var name: String
    var institutionName: String
    var specialtyPackIds: [String]
    var customCategoryIds: [String]
    var fellowInviteCode: String
    var attendingInviteCode: String
    var adminInviteCode: String
    var allowComments: Bool
    var evaluationsEnabled: Bool
    var evaluationsRequired: Bool
    var evaluationItems: [String]
    var evaluationFreeTextEnabled: Bool
    var requireAttestationForMigratedCases: Bool
    var trainingProgramLength: Int
    var fellowshipSpecialtyRaw: String?
    var allowSimpleDutyHours: Bool  // When false, fellows must use comprehensive shift tracking
    var earliestPGYLevel: Int  // Earliest PGY year for fellows (default 4, range 1-10)
    var createdAt: Date
    var updatedAt: Date

    @Transient var fellowshipSpecialty: FellowshipSpecialty? {
        get { fellowshipSpecialtyRaw.flatMap { FellowshipSpecialty(rawValue: $0) } }
        set { fellowshipSpecialtyRaw = newValue?.rawValue }
    }

    init(
        programCode: String,
        name: String,
        institutionName: String,
        specialtyPackIds: [String],
        allowComments: Bool = true
    ) {
        self.id = UUID()
        self.programCode = programCode
        self.name = name
        self.institutionName = institutionName
        self.specialtyPackIds = specialtyPackIds
        self.customCategoryIds = []
        self.fellowInviteCode = Self.generateInviteCode()
        self.attendingInviteCode = Self.generateInviteCode()
        self.adminInviteCode = Self.generateInviteCode()
        self.allowComments = allowComments
        self.evaluationsEnabled = false
        self.evaluationsRequired = false
        self.evaluationItems = []
        self.evaluationFreeTextEnabled = true
        self.requireAttestationForMigratedCases = false
        self.trainingProgramLength = 3  // Default 3-year fellowship
        self.fellowshipSpecialtyRaw = nil
        self.allowSimpleDutyHours = true  // Allow simple mode by default
        self.earliestPGYLevel = 4  // Default PGY4 (most fellowships start after 3-year residency)
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    static func generateInviteCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }

    static func generateProgramCode() -> String {
        // Format: PRG-XXXXX (5 alphanumeric characters)
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let randomPart = String((0..<5).map { _ in characters.randomElement()! })
        return "PRG-\(randomPart)"
    }
}

// MARK: - User Model

@Model
final class User {
    @Attribute(.unique) var id: UUID
    var email: String
    var firstName: String
    var lastName: String
    var displayName: String
    var roleRaw: String
    var accountModeRaw: String
    var programId: UUID?
    var trainingYear: Int?
    var phoneNumber: String?
    var isActive: Bool
    var isArchived: Bool
    var hasGraduated: Bool
    var graduatedAt: Date?
    var notifyOnApproval: Bool
    var notifyOnRejection: Bool
    var notifyOnNewAttestation: Bool
    var notifyOnAnyRejection: Bool
    var createdAt: Date
    var updatedAt: Date
    
    @Transient var role: UserRole {
        get { UserRole(rawValue: roleRaw) ?? .fellow }
        set { roleRaw = newValue.rawValue }
    }
    
    @Transient var accountMode: AccountMode {
        get { AccountMode(rawValue: accountModeRaw) ?? .individual }
        set { accountModeRaw = newValue.rawValue }
    }
    
    @Transient var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    init(
        email: String,
        firstName: String,
        lastName: String,
        role: UserRole,
        accountMode: AccountMode = .institutional,
        programId: UUID? = nil,
        trainingYear: Int? = nil
    ) {
        self.id = UUID()
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        self.roleRaw = role.rawValue
        self.accountModeRaw = accountMode.rawValue
        self.programId = programId
        self.trainingYear = trainingYear
        self.isActive = true
        self.isArchived = false
        self.hasGraduated = false
        self.graduatedAt = nil
        self.notifyOnApproval = true
        self.notifyOnRejection = true
        self.notifyOnNewAttestation = true
        self.notifyOnAnyRejection = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    convenience init(email: String, displayName: String, role: UserRole, accountMode: AccountMode = .institutional, programId: UUID? = nil, trainingYear: Int? = nil) {
        let parts = displayName.split(separator: " ", maxSplits: 1)
        let first = parts.first.map(String.init) ?? displayName
        let last = parts.count > 1 ? String(parts[1]) : ""
        self.init(email: email, firstName: first, lastName: last, role: role, accountMode: accountMode, programId: programId, trainingYear: trainingYear)
    }
}

// MARK: - Attending

@Model
final class Attending {
    @Attribute(.unique) var id: UUID
    var firstName: String
    var lastName: String
    var name: String
    var programId: UUID?
    var ownerId: UUID?
    var userId: UUID?
    var phoneNumber: String?
    var isArchived: Bool
    var createdAt: Date
    
    @Transient var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    init(firstName: String, lastName: String, programId: UUID? = nil, ownerId: UUID? = nil, userId: UUID? = nil, phoneNumber: String? = nil) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        self.programId = programId
        self.ownerId = ownerId
        self.userId = userId
        self.phoneNumber = phoneNumber
        self.isArchived = false
        self.createdAt = Date()
    }
    
    convenience init(name: String, programId: UUID? = nil, ownerId: UUID? = nil, userId: UUID? = nil, phoneNumber: String? = nil) {
        let parts = name.split(separator: " ", maxSplits: 1)
        let first = parts.first.map(String.init) ?? name
        let last = parts.count > 1 ? String(parts[1]) : ""
        self.init(firstName: first, lastName: last, programId: programId, ownerId: ownerId, userId: userId, phoneNumber: phoneNumber)
    }
}

// MARK: - Training Facility

@Model
final class TrainingFacility {
    @Attribute(.unique) var id: UUID
    var name: String
    var shortName: String?
    var programId: UUID?
    var ownerId: UUID?
    var isArchived: Bool
    var createdAt: Date
    
    init(name: String, shortName: String? = nil, programId: UUID? = nil, ownerId: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.shortName = shortName
        self.programId = programId
        self.ownerId = ownerId
        self.isArchived = false
        self.createdAt = Date()
    }
}

// MARK: - Custom Category

@Model
final class CustomCategory {
    @Attribute(.unique) var id: UUID
    var programId: UUID?
    var ownerId: UUID?
    var name: String
    var letter: String
    var colorHex: String
    var createdByAdminId: UUID?
    var isArchived: Bool
    var createdAt: Date
    
    @Transient var color: Color {
        Color(hex: colorHex) ?? .gray
    }
    
    init(name: String, letter: String, colorHex: String, programId: UUID? = nil, ownerId: UUID? = nil, createdByAdminId: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.letter = letter
        self.colorHex = colorHex
        self.programId = programId
        self.ownerId = ownerId
        self.createdByAdminId = createdByAdminId
        self.isArchived = false
        self.createdAt = Date()
    }
    
    static let availableColors: [String] = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
        "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9",
        "#F8B500", "#00CED1", "#FF69B4", "#32CD32", "#FF7F50",
        "#9370DB", "#20B2AA", "#FFD700", "#8A2BE2", "#00FA9A"
    ]
    
    static let availableLetters: [String] = (65...90).map { String(UnicodeScalar($0)) }
}

// MARK: - Fellow Procedure Group (Custom category grouping existing procedures)

@Model
final class FellowProcedureGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var letter: String
    var colorHex: String
    var procedureTagIds: [String]  // IDs of existing procedures to group
    var creatorId: UUID  // Fellow who created this group
    var programId: UUID?
    var isArchived: Bool
    var createdAt: Date

    @Transient var color: Color {
        Color(hex: colorHex) ?? .gray
    }

    init(name: String, letter: String, colorHex: String, procedureTagIds: [String], creatorId: UUID, programId: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.letter = letter
        self.colorHex = colorHex
        self.procedureTagIds = procedureTagIds
        self.creatorId = creatorId
        self.programId = programId
        self.isArchived = false
        self.createdAt = Date()
    }
}

// MARK: - Custom Procedure

@Model
final class CustomProcedure {
    @Attribute(.unique) var id: UUID
    var title: String
    var categoryRaw: String
    var customCategoryId: UUID?
    var programId: UUID?
    var ownerId: UUID?
    var creatorId: UUID?
    var isArchived: Bool
    var createdAt: Date
    
    @Transient var category: ProcedureCategory {
        get { ProcedureCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
    
    @Transient var isGlobal: Bool {
        creatorId == nil
    }
    
    @Transient var tagId: String {
        "custom-\(id.uuidString)"
    }
    
    func isVisible(to userId: UUID?, role: UserRole) -> Bool {
        if role == .admin { return true }
        if isGlobal { return true }
        if let creatorId = creatorId, creatorId == userId { return true }
        return false
    }
    
    init(title: String, category: ProcedureCategory, programId: UUID? = nil, ownerId: UUID? = nil, creatorId: UUID? = nil, customCategoryId: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.categoryRaw = category.rawValue
        self.customCategoryId = customCategoryId
        self.programId = programId
        self.ownerId = ownerId
        self.creatorId = creatorId
        self.isArchived = false
        self.createdAt = Date()
    }
}

// MARK: - Custom Access Site

@Model
final class CustomAccessSite {
    @Attribute(.unique) var id: UUID
    var title: String
    var programId: UUID?
    var ownerId: UUID?
    var isArchived: Bool
    var createdAt: Date
    
    init(title: String, programId: UUID? = nil, ownerId: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.programId = programId
        self.ownerId = ownerId
        self.isArchived = false
        self.createdAt = Date()
    }
}

// MARK: - Custom Complication

@Model
final class CustomComplication {
    @Attribute(.unique) var id: UUID
    var title: String
    var programId: UUID?
    var ownerId: UUID?
    var isArchived: Bool
    var createdAt: Date
    
    init(title: String, programId: UUID? = nil, ownerId: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.programId = programId
        self.ownerId = ownerId
        self.isArchived = false
        self.createdAt = Date()
    }
}

// MARK: - Custom Procedure Detail

/// Allows fellows to define custom details (like devices, techniques) for specific procedures
/// Similar to the built-in ThrombectomyDevice but user-defined
@Model
final class CustomProcedureDetail {
    @Attribute(.unique) var id: UUID
    var name: String                    // e.g., "Device Used", "Technique"
    var procedureTagIds: [String]       // Which procedures this detail applies to
    var optionsJson: String             // JSON array of option strings
    var programId: UUID?                // For institutional mode
    var ownerId: UUID?                  // For individual mode (owner of the detail)
    var creatorId: UUID?                // Who created it (for fellow-created in institutional mode)
    var isArchived: Bool
    var createdAt: Date

    /// Decode options from JSON
    @Transient var options: [String] {
        get {
            guard let data = optionsJson.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                optionsJson = json
            }
        }
    }

    /// Check if this detail applies to a given procedure
    func appliesTo(procedureId: String) -> Bool {
        procedureTagIds.contains(procedureId)
    }

    init(name: String, procedureTagIds: [String], options: [String], programId: UUID? = nil, ownerId: UUID? = nil, creatorId: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.procedureTagIds = procedureTagIds
        self.programId = programId
        self.ownerId = ownerId
        self.creatorId = creatorId
        self.isArchived = false
        self.createdAt = Date()

        // Encode options to JSON
        if let data = try? JSONEncoder().encode(options),
           let json = String(data: data, encoding: .utf8) {
            self.optionsJson = json
        } else {
            self.optionsJson = "[]"
        }
    }
}

// MARK: - Case Entry

@Model
final class CaseEntry {
    @Attribute(.unique) var id: UUID
    var programId: UUID?
    var fellowId: UUID?
    var ownerId: UUID?
    var attendingId: UUID?
    var supervisorId: UUID?
    var facilityId: UUID?
    var hospitalId: UUID?
    var weekBucket: String
    var procedureTagIds: [String]
    var procedureSubOptions: [String: String]
    var procedureDevices: [String: [String]]  // For PE/DVT device tracking: procedureId -> [device names]
    var accessSiteIds: [String]
    var complicationIds: [String]
    var outcomeRaw: String
    var attestationStatusRaw: String
    var attestedAt: Date?
    var attestationComment: String?
    var evaluationChecks: [String]  // DEPRECATED: Use evaluationResponsesJson instead
    var evaluationResponsesJson: String?  // JSON: {"fieldId": "value"} - supports checkbox ("true"/"false") and rating ("1"-"5")
    var evaluationComment: String?
    var fellowComment: String?
    var isProxyAttestation: Bool
    var proxyAdminId: UUID?
    var rejectionReason: String?
    var rejectorId: UUID?
    var rejectedAt: Date?
    var notes: String?  // Free text notes (no PHI)
    var createdAt: Date
    var updatedAt: Date
    var attestorId: UUID?
    var proxyAttestorId: UUID?
    var isArchived: Bool
    var isMigrated: Bool
    var isBulkEntry: Bool  // True if entered via bulk entry mode
    var migratedAt: Date?
    var caseTypeRaw: String?
    var operatorPositionRaw: String?
    var customDetailSelections: [String: [String]]  // detailId.uuidString -> selected option strings

    @Transient var outcome: CaseOutcome {
        get { CaseOutcome(rawValue: outcomeRaw) ?? .success }
        set { outcomeRaw = newValue.rawValue }
    }

    @Transient var attestationStatus: AttestationStatus {
        get { AttestationStatus(rawValue: attestationStatusRaw) ?? .pending }
        set { attestationStatusRaw = newValue.rawValue }
    }

    @Transient var caseType: CaseType? {
        get { caseTypeRaw.flatMap { CaseType(rawValue: $0) } }
        set { caseTypeRaw = newValue?.rawValue }
    }

    @Transient var operatorPosition: OperatorPosition? {
        get { operatorPositionRaw.flatMap { OperatorPosition(rawValue: $0) } }
        set { operatorPositionRaw = newValue?.rawValue }
    }

    /// Evaluation responses keyed by field ID (UUID string)
    /// Values: "true"/"false" for checkboxes, "1"-"5" for ratings
    @Transient var evaluationResponses: [String: String] {
        get {
            guard let json = evaluationResponsesJson,
                  let data = json.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                evaluationResponsesJson = json
            } else {
                evaluationResponsesJson = nil
            }
        }
    }

    init(
        fellowId: UUID? = nil,
        ownerId: UUID? = nil,
        attendingId: UUID? = nil,
        weekBucket: String,
        programId: UUID? = nil,
        facilityId: UUID? = nil
    ) {
        self.id = UUID()
        self.programId = programId
        self.fellowId = fellowId
        self.ownerId = ownerId
        self.attendingId = attendingId
        self.supervisorId = attendingId
        self.facilityId = facilityId
        self.hospitalId = facilityId
        self.weekBucket = weekBucket
        self.procedureTagIds = []
        self.procedureSubOptions = [:]
        self.procedureDevices = [:]
        self.accessSiteIds = []
        self.complicationIds = []
        self.outcomeRaw = CaseOutcome.success.rawValue
        self.attestationStatusRaw = AttestationStatus.pending.rawValue
        self.attestedAt = nil
        self.attestationComment = nil
        self.evaluationChecks = []
        self.evaluationResponsesJson = nil
        self.evaluationComment = nil
        self.fellowComment = nil
        self.isProxyAttestation = false
        self.proxyAdminId = nil
        self.rejectionReason = nil
        self.rejectorId = nil
        self.rejectedAt = nil
        self.notes = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.attestorId = nil
        self.proxyAttestorId = nil
        self.isArchived = false
        self.isMigrated = false
        self.isBulkEntry = false
        self.migratedAt = nil
        self.caseTypeRaw = nil
        self.operatorPositionRaw = nil
        self.customDetailSelections = [:]
    }

    static func makeWeekBucket(for date: Date) -> String {
        let calendar = Calendar(identifier: .iso8601)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%d-W%02d", year, week)
    }
}

// MARK: - Attestation Record

@Model
final class Attestation {
    @Attribute(.unique) var id: UUID
    var caseId: UUID
    var attendingId: UUID
    var statusRaw: String
    var rubricSelections: [String]
    var comment: String?
    var attestedAt: Date
    
    @Transient var status: AttestationStatus {
        get { AttestationStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
    
    init(caseId: UUID, attendingId: UUID, status: AttestationStatus) {
        self.id = UUID()
        self.caseId = caseId
        self.attendingId = attendingId
        self.statusRaw = status.rawValue
        self.rubricSelections = []
        self.attestedAt = Date()
    }
}

// MARK: - Notification (FIXED with isCleared, readAt, clearedAt)

@Model
final class Notification {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var attendingId: UUID?
    var title: String
    var message: String
    var caseId: UUID?
    var notificationType: String
    var isRead: Bool
    var isCleared: Bool
    var autoCleared: Bool
    var autoClearReason: String?
    var readAt: Date?
    var clearedAt: Date?
    var createdAt: Date

    // Sender tracking for messages
    var senderId: UUID?
    var senderName: String?
    var senderRoleRaw: String?

    // Reply/conversation support
    var replyToId: UUID?       // ID of the notification being replied to
    var conversationId: UUID?  // Groups related messages together

    @Transient var senderRole: UserRole? {
        get {
            guard let raw = senderRoleRaw else { return nil }
            return UserRole(rawValue: raw)
        }
        set { senderRoleRaw = newValue?.rawValue }
    }

    init(userId: UUID, title: String, message: String, notificationType: String, caseId: UUID? = nil, attendingId: UUID? = nil) {
        self.id = UUID()
        self.userId = userId
        self.attendingId = attendingId
        self.title = title
        self.message = message
        self.notificationType = notificationType
        self.caseId = caseId
        self.isRead = false
        self.isCleared = false
        self.autoCleared = false
        self.autoClearReason = nil
        self.readAt = nil
        self.clearedAt = nil
        self.createdAt = Date()
        self.senderId = nil
        self.senderName = nil
        self.senderRoleRaw = nil
        self.replyToId = nil
        self.conversationId = nil
    }
}

// MARK: - Week Bucket Extensions

extension String {
    func toWeekTimeframeLabel() -> String {
        guard self.contains("-W") else { return self }
        
        let components = self.split(separator: "-W")
        guard components.count == 2,
              let year = Int(components[0]),
              let week = Int(components[1]) else { return self }
        
        let calendar = Calendar(identifier: .iso8601)
        var dateComponents = DateComponents()
        dateComponents.yearForWeekOfYear = year
        dateComponents.weekOfYear = week
        dateComponents.weekday = 2
        
        guard let startDate = calendar.date(from: dateComponents) else { return self }
        let endDate = calendar.date(byAdding: .day, value: 6, to: startDate) ?? startDate
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"
        
        let startMonth = monthFormatter.string(from: startDate)
        let endMonth = monthFormatter.string(from: endDate)
        let startDay = dayFormatter.string(from: startDate)
        let endDay = dayFormatter.string(from: endDate)
        let startYear = Calendar.current.component(.year, from: startDate)
        let endYear = Calendar.current.component(.year, from: endDate)
        
        if startYear != endYear {
            return "\(startMonth) \(startDay), \(startYear) – \(endMonth) \(endDay), \(endYear)"
        } else if startMonth != endMonth {
            return "\(startMonth) \(startDay) – \(endMonth) \(endDay), \(startYear)"
        } else {
            return "\(startMonth) \(startDay)–\(endDay), \(startYear)"
        }
    }
    
    static func weekBucket(from date: Date) -> String {
        CaseEntry.makeWeekBucket(for: date)
    }
}

// MARK: - Evaluation Field

@Model
final class EvaluationField {
    @Attribute(.unique) var id: UUID
    var title: String
    var descriptionText: String?  // Optional expandable description for the field
    var fieldTypeRaw: String  // "checkbox" or "rating"
    var isRequired: Bool
    var displayOrder: Int
    var programId: UUID?
    var isDefault: Bool
    var isArchived: Bool
    var createdAt: Date

    @Transient var fieldType: EvaluationFieldType {
        get { EvaluationFieldType(rawValue: fieldTypeRaw) ?? .checkbox }
        set { fieldTypeRaw = newValue.rawValue }
    }

    init(title: String, descriptionText: String? = nil, fieldType: EvaluationFieldType = .checkbox, isRequired: Bool = false, displayOrder: Int = 0, programId: UUID? = nil, isDefault: Bool = false) {
        self.id = UUID()
        self.title = title
        self.descriptionText = descriptionText
        self.fieldTypeRaw = fieldType.rawValue
        self.isRequired = isRequired
        self.displayOrder = displayOrder
        self.programId = programId
        self.isDefault = isDefault
        self.isArchived = false
        self.createdAt = Date()
    }
}

// MARK: - Program Evaluation Settings

@Model
final class ProgramEvaluationSettings {
    @Attribute(.unique) var id: UUID
    var programId: UUID
    var isEnabled: Bool
    var isRequired: Bool
    var freeTextEnabled: Bool
    var createdAt: Date
    
    init(programId: UUID, isEnabled: Bool = false, isRequired: Bool = false, freeTextEnabled: Bool = true) {
        self.id = UUID()
        self.programId = programId
        self.isEnabled = isEnabled
        self.isRequired = isRequired
        self.freeTextEnabled = freeTextEnabled
        self.createdAt = Date()
    }
}

// MARK: - Audit Entry (FIXED with all required properties)

@Model
final class AuditEntry {
    @Attribute(.unique) var id: UUID
    var oderId: UUID?
    var usedid: UUID?
    var userId: UUID?
    var userRole: String
    var userName: String
    var actionType: String
    var entityType: String
    var entityId: UUID?
    var entityName: String
    var details: String
    var programId: UUID?
    var createdAt: Date
    
    init(
        oderId: UUID? = nil,
        usedid: UUID? = nil,
        userId: UUID? = nil,
        userRole: String,
        userName: String,
        actionType: String,
        entityType: String,
        entityId: UUID? = nil,
        entityName: String,
        details: String = "",
        programId: UUID? = nil
    ) {
        self.id = UUID()
        self.oderId = oderId
        self.usedid = usedid
        self.userId = userId
        self.userRole = userRole
        self.userName = userName
        self.actionType = actionType
        self.entityType = entityType
        self.entityId = entityId
        self.entityName = entityName
        self.details = details
        self.programId = programId
        self.createdAt = Date()
    }
    
    // Convenience init for simpler calls
    convenience init(userId: UUID?, action: String, entityType: String, entityId: UUID? = nil, details: String = "") {
        self.init(
            userId: userId,
            userRole: "",
            userName: "",
            actionType: action,
            entityType: entityType,
            entityId: entityId,
            entityName: "",
            details: details
        )
    }
}

// MARK: - Badge (Achievement Definition)

@Model
final class Badge {
    @Attribute(.unique) var id: String  // e.g., "first-pci-primary", "milestone-50-ic-pci-stent"
    var title: String
    var descriptionText: String
    var iconName: String                // SF Symbol name
    var badgeTypeRaw: String            // BadgeType enum raw value
    var criteriaJson: String            // JSON-encoded BadgeCriteria
    var tier: Int                       // 1=bronze, 2=silver, 3=gold, 4=platinum
    var pointValue: Int                 // Points awarded for gamification
    var isActive: Bool                  // Can be disabled by admin
    var createdAt: Date

    @Transient var badgeType: BadgeType {
        get { BadgeType(rawValue: badgeTypeRaw) ?? .milestone }
        set { badgeTypeRaw = newValue.rawValue }
    }

    @Transient var badgeTier: BadgeTier {
        get { BadgeTier(rawValue: tier) ?? .bronze }
        set { tier = newValue.rawValue }
    }

    @Transient var criteria: BadgeCriteria? {
        get {
            BadgeCriteria.fromJson(criteriaJson)
        }
        set {
            if let newValue = newValue {
                criteriaJson = newValue.toJson()
            }
        }
    }

    init(
        id: String,
        title: String,
        description: String,
        iconName: String,
        badgeType: BadgeType,
        criteria: BadgeCriteria,
        tier: BadgeTier = .bronze,
        pointValue: Int = 10
    ) {
        self.id = id
        self.title = title
        self.descriptionText = description
        self.iconName = iconName
        self.badgeTypeRaw = badgeType.rawValue
        self.tier = tier.rawValue
        self.pointValue = pointValue
        self.isActive = true
        self.createdAt = Date()
        self.criteriaJson = criteria.toJson()
    }
}

// MARK: - BadgeEarned (Fellow's Earned Badges)

@Model
final class BadgeEarned {
    @Attribute(.unique) var id: UUID
    var badgeId: String               // References Badge.id
    var fellowId: UUID                // User ID or ownerId of the fellow
    var programId: UUID?              // For institutional mode
    var earnedAt: Date
    var triggeringCaseId: UUID?       // The case that triggered the badge
    var notifiedAt: Date?             // When fellow was notified
    var viewedAt: Date?               // When fellow viewed/acknowledged the badge
    var procedureCount: Int           // Count at time of earning (for milestones)

    init(
        badgeId: String,
        fellowId: UUID,
        programId: UUID? = nil,
        triggeringCaseId: UUID? = nil,
        procedureCount: Int = 0
    ) {
        self.id = UUID()
        self.badgeId = badgeId
        self.fellowId = fellowId
        self.programId = programId
        self.earnedAt = Date()
        self.triggeringCaseId = triggeringCaseId
        self.notifiedAt = nil
        self.viewedAt = nil
        self.procedureCount = procedureCount
    }

    /// Mark badge as notified
    func markNotified() {
        notifiedAt = Date()
    }

    /// Mark badge as viewed/acknowledged
    func markViewed() {
        viewedAt = Date()
    }
}

// MARK: - Case Media (Image/Video Attachments)

@Model
final class CaseMedia {
    @Attribute(.unique) var id: UUID
    var caseEntryId: UUID                    // FK to CaseEntry
    var ownerId: UUID                        // User who uploaded
    var ownerName: String                    // Display name for shared library

    // Media Info
    var mediaTypeRaw: String                 // "image" or "video"
    var fileName: String
    var localPath: String
    var cloudPath: String?
    var thumbnailPath: String?
    var fileSizeBytes: Int
    var contentHash: String                  // SHA256

    // Dimensions
    var width: Int?
    var height: Int?
    var durationSeconds: Double?             // Videos only

    // Search & Sharing
    var searchTerms: [String]                // User-defined labels
    var isSharedWithFellowship: Bool         // If true, visible in Teaching Files
    var caseDate: Date?
    var comment: String?                     // User comment on the media

    // PHI Detection
    var textDetectionRan: Bool
    var textWasDetected: Bool
    var detectedTextRegions: String?         // JSON: [{x, y, width, height, text}]
    var detectedTextConfidence: Double?
    var userConfirmedNoPHI: Bool
    var userConfirmedAt: Date?
    var redactionApplied: Bool
    var redactedRegions: String?             // JSON: [{x, y, width, height}]

    // Timestamps
    var capturedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var uploadedToCloudAt: Date?

    @Transient var mediaType: MediaType {
        get { MediaType(rawValue: mediaTypeRaw) ?? .image }
        set { mediaTypeRaw = newValue.rawValue }
    }

    /// Maximum file size: 10 MB
    static let maxFileSizeBytes = 10 * 1024 * 1024

    init(
        caseEntryId: UUID,
        ownerId: UUID,
        ownerName: String,
        mediaType: MediaType,
        fileName: String,
        localPath: String
    ) {
        self.id = UUID()
        self.caseEntryId = caseEntryId
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.mediaTypeRaw = mediaType.rawValue
        self.fileName = fileName
        self.localPath = localPath
        self.cloudPath = nil
        self.thumbnailPath = nil
        self.fileSizeBytes = 0
        self.contentHash = ""
        self.width = nil
        self.height = nil
        self.durationSeconds = nil
        self.searchTerms = []
        self.isSharedWithFellowship = false
        self.caseDate = nil
        self.comment = nil
        self.textDetectionRan = false
        self.textWasDetected = false
        self.detectedTextRegions = nil
        self.detectedTextConfidence = nil
        self.userConfirmedNoPHI = false
        self.userConfirmedAt = nil
        self.redactionApplied = false
        self.redactedRegions = nil
        self.capturedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.uploadedToCloudAt = nil
    }
}

// MARK: - Search Term Suggestion (Auto-suggest for media labels)

@Model
final class SearchTermSuggestion {
    @Attribute(.unique) var term: String     // Normalized lowercase
    var displayText: String                  // Original casing
    var usageCount: Int
    var lastUsedAt: Date
    var createdAt: Date

    init(term: String) {
        self.term = term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayText = term.trimmingCharacters(in: .whitespacesAndNewlines)
        self.usageCount = 1
        self.lastUsedAt = Date()
        self.createdAt = Date()
    }

    /// Increment usage count and update last used timestamp
    func recordUsage() {
        usageCount += 1
        lastUsedAt = Date()
    }
}

// MARK: - Duty Hours Entry

@Model
final class DutyHoursEntry {
    @Attribute(.unique) var id: UUID
    var userId: UUID                         // Fellow's user ID or ownerId
    var programId: UUID?                     // For institutional mode
    var weekBucket: String                   // e.g., "2024-W03"
    var hours: Double                        // Hours worked that week
    var notes: String?                       // Optional notes
    var createdAt: Date
    var updatedAt: Date

    init(
        userId: UUID,
        programId: UUID? = nil,
        weekBucket: String,
        hours: Double,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.userId = userId
        self.programId = programId
        self.weekBucket = weekBucket
        self.hours = hours
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Week bucket display label (e.g., "Jan 1–7, 2024")
    var weekLabel: String {
        weekBucket.toWeekTimeframeLabel()
    }
}

// MARK: - Duty Hours Shift (Comprehensive Tracking)

@Model
final class DutyHoursShift {
    @Attribute(.unique) var id: UUID
    var userId: UUID                         // Fellow's user ID
    var programId: UUID?                     // For institutional mode
    var weekBucket: String                   // Links to existing system e.g., "2024-W03"

    // Shift timing
    var shiftDate: Date                      // Date of the shift
    var startTime: Date                      // Shift start time
    var endTime: Date?                       // Shift end time (nil if still active)

    // Shift details
    var shiftTypeRaw: String                 // DutyHoursShiftType raw value
    var locationRaw: String                  // DutyHoursShiftLocation raw value
    var isActiveShift: Bool                  // True if currently clocked in

    // Break tracking
    var breakMinutes: Int                    // Total break time in minutes
    var breakPeriodsJSON: String?            // JSON array of break periods

    // Calculated hours
    var totalHours: Double                   // Total hours including breaks
    var effectiveHours: Double               // Hours minus breaks

    // At-home call tracking
    var wasCalledIn: Bool                    // For at-home call, was trainee called in?
    var calledInAt: Date?                    // Time called in (if applicable)

    // Notes
    var notes: String?

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Properties

    @Transient var shiftType: DutyHoursShiftType {
        get { DutyHoursShiftType(rawValue: shiftTypeRaw) ?? .regular }
        set { shiftTypeRaw = newValue.rawValue }
    }

    @Transient var location: DutyHoursShiftLocation {
        get { DutyHoursShiftLocation(rawValue: locationRaw) ?? .inHouse }
        set { locationRaw = newValue.rawValue }
    }

    /// Duration of shift in hours (live calculation if still active)
    @Transient var durationHours: Double {
        let end = endTime ?? Date()
        let duration = end.timeIntervalSince(startTime)
        return max(0, duration / 3600.0)
    }

    /// Duration minus breaks
    @Transient var effectiveDurationHours: Double {
        max(0, durationHours - (Double(breakMinutes) / 60.0))
    }

    init(
        userId: UUID,
        programId: UUID? = nil,
        shiftDate: Date,
        startTime: Date,
        shiftType: DutyHoursShiftType = .regular,
        location: DutyHoursShiftLocation = .inHouse
    ) {
        self.id = UUID()
        self.userId = userId
        self.programId = programId
        self.weekBucket = shiftDate.toWeekBucket()
        self.shiftDate = shiftDate
        self.startTime = startTime
        self.endTime = nil
        self.shiftTypeRaw = shiftType.rawValue
        self.locationRaw = location.rawValue
        self.isActiveShift = true
        self.breakMinutes = 0
        self.breakPeriodsJSON = nil
        self.totalHours = 0
        self.effectiveHours = 0
        self.wasCalledIn = false
        self.calledInAt = nil
        self.notes = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Clock out and calculate final hours
    func clockOut(at time: Date = Date()) {
        self.endTime = time
        self.isActiveShift = false
        self.totalHours = durationHours
        self.effectiveHours = effectiveDurationHours
        self.updatedAt = Date()
    }

    /// Add break time
    func addBreak(minutes: Int) {
        self.breakMinutes += minutes
        self.updatedAt = Date()
    }
}

// MARK: - Duty Hours Violation

@Model
final class DutyHoursViolation {
    @Attribute(.unique) var id: UUID
    var userId: UUID                         // Fellow who has the violation
    var programId: UUID?                     // For institutional mode
    var weekBucket: String                   // Week when violation occurred

    // Violation details
    var violationTypeRaw: String             // DutyHoursViolationType raw value
    var severityRaw: String                  // ViolationSeverity raw value
    var actualValue: Double                  // Actual value that violated limit
    var limitValue: Double                   // The ACGME limit that was exceeded

    // Period of violation
    var periodStart: Date                    // Start of violation period
    var periodEnd: Date                      // End of violation period

    // Resolution
    var isResolved: Bool
    var resolvedAt: Date?
    var resolutionNotes: String?
    var resolvedByUserId: UUID?              // Admin who resolved it

    // Timestamps
    var detectedAt: Date
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Properties

    @Transient var violationType: DutyHoursViolationType {
        get { DutyHoursViolationType(rawValue: violationTypeRaw) ?? .weeklyHoursExceeded }
        set { violationTypeRaw = newValue.rawValue }
    }

    @Transient var severity: ViolationSeverity {
        get { ViolationSeverity(rawValue: severityRaw) ?? .minor }
        set { severityRaw = newValue.rawValue }
    }

    init(
        userId: UUID,
        programId: UUID? = nil,
        weekBucket: String,
        violationType: DutyHoursViolationType,
        severity: ViolationSeverity,
        actualValue: Double,
        limitValue: Double,
        periodStart: Date,
        periodEnd: Date
    ) {
        self.id = UUID()
        self.userId = userId
        self.programId = programId
        self.weekBucket = weekBucket
        self.violationTypeRaw = violationType.rawValue
        self.severityRaw = severity.rawValue
        self.actualValue = actualValue
        self.limitValue = limitValue
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.isResolved = false
        self.resolvedAt = nil
        self.resolutionNotes = nil
        self.resolvedByUserId = nil
        self.detectedAt = Date()
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Mark violation as resolved
    func resolve(by adminId: UUID, notes: String?) {
        self.isResolved = true
        self.resolvedAt = Date()
        self.resolvedByUserId = adminId
        self.resolutionNotes = notes
        self.updatedAt = Date()
    }
}

// MARK: - Media Comment (Comments on Teaching Files)

@Model
final class MediaComment {
    @Attribute(.unique) var id: UUID
    var mediaId: UUID                        // FK to CaseMedia
    var authorId: UUID                       // User who wrote the comment
    var authorName: String                   // Display name
    var authorRoleRaw: String                // "fellow" or "attending"
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool

    @Transient var authorRole: UserRole? {
        get { UserRole(rawValue: authorRoleRaw) }
        set { authorRoleRaw = newValue?.rawValue ?? "fellow" }
    }

    init(
        mediaId: UUID,
        authorId: UUID,
        authorName: String,
        authorRole: UserRole,
        text: String
    ) {
        self.id = UUID()
        self.mediaId = mediaId
        self.authorId = authorId
        self.authorName = authorName
        self.authorRoleRaw = authorRole.rawValue
        self.text = text
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isDeleted = false
    }
}
