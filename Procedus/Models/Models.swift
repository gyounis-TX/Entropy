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
    var evaluationChecks: [String]
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
    var isRequired: Bool
    var displayOrder: Int
    var programId: UUID?
    var isDefault: Bool
    var isArchived: Bool
    var createdAt: Date
    
    init(title: String, isRequired: Bool = false, displayOrder: Int = 0, programId: UUID? = nil, isDefault: Bool = false) {
        self.id = UUID()
        self.title = title
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
