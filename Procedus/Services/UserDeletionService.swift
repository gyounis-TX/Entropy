// UserDeletionService.swift
// Procedus - Unified
// Prevent deletion of users if referenced by case data

import Foundation
import SwiftData
import SwiftUI

// MARK: - User Deletion Service

class UserDeletionService {
    static let shared = UserDeletionService()
    private init() {}
    
    private var modelContext: ModelContext?
    
    func configure(with context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Reference Check Result
    
    struct ReferenceCheckResult {
        let canDelete: Bool
        let references: [EntityReference]
        let totalReferences: Int
        
        var message: String {
            if canDelete {
                return "This user can be safely archived."
            } else {
                var msg = "This user cannot be deleted because they are referenced by:\n"
                for ref in references {
                    msg += "• \(ref.count) \(ref.entityType)(s)\n"
                }
                return msg
            }
        }
    }
    
    struct EntityReference {
        let entityType: String
        let count: Int
        let sampleIds: [UUID]
    }
    
    // MARK: - Check User References
    
    /// Check if a user can be safely deleted/archived
    func checkUserReferences(userId: UUID) -> ReferenceCheckResult {
        guard let context = modelContext else {
            return ReferenceCheckResult(canDelete: false, references: [], totalReferences: 0)
        }
        
        var references: [EntityReference] = []
        var totalReferences = 0
        
        // Check CaseEntry - as owner (Fellow)
        let ownedCasesDescriptor = FetchDescriptor<CaseEntry>(
            predicate: #Predicate { entry in
                entry.ownerId == userId
            }
        )
        
        if let ownedCases = try? context.fetch(ownedCasesDescriptor), !ownedCases.isEmpty {
            references.append(EntityReference(
                entityType: "case (as Fellow)",
                count: ownedCases.count,
                sampleIds: Array(ownedCases.prefix(5).map { $0.id })
            ))
            totalReferences += ownedCases.count
        }
        
        // Check CaseEntry - as supervisor (Attending)
        let supervisedCasesDescriptor = FetchDescriptor<CaseEntry>(
            predicate: #Predicate { entry in
                entry.supervisorId == userId
            }
        )
        
        if let supervisedCases = try? context.fetch(supervisedCasesDescriptor), !supervisedCases.isEmpty {
            references.append(EntityReference(
                entityType: "case (as Supervisor)",
                count: supervisedCases.count,
                sampleIds: Array(supervisedCases.prefix(5).map { $0.id })
            ))
            totalReferences += supervisedCases.count
        }
        
        // Check CaseEntry - as attestor
        let attestedCasesDescriptor = FetchDescriptor<CaseEntry>(
            predicate: #Predicate { entry in
                entry.attestorId == userId
            }
        )
        
        if let attestedCases = try? context.fetch(attestedCasesDescriptor), !attestedCases.isEmpty {
            references.append(EntityReference(
                entityType: "case (as Attestor)",
                count: attestedCases.count,
                sampleIds: Array(attestedCases.prefix(5).map { $0.id })
            ))
            totalReferences += attestedCases.count
        }
        
        // Check CaseEntry - as proxy attestor
        let proxyAttestedDescriptor = FetchDescriptor<CaseEntry>(
            predicate: #Predicate { entry in
                entry.proxyAttestorId == userId
            }
        )
        
        if let proxyAttested = try? context.fetch(proxyAttestedDescriptor), !proxyAttested.isEmpty {
            references.append(EntityReference(
                entityType: "case (as Proxy Attestor)",
                count: proxyAttested.count,
                sampleIds: Array(proxyAttested.prefix(5).map { $0.id })
            ))
            totalReferences += proxyAttested.count
        }
        
        // Check CustomProcedure - as creator
        let customProcsDescriptor = FetchDescriptor<CustomProcedure>(
            predicate: #Predicate { proc in
                proc.creatorId == userId
            }
        )
        
        if let customProcs = try? context.fetch(customProcsDescriptor), !customProcs.isEmpty {
            references.append(EntityReference(
                entityType: "custom procedure",
                count: customProcs.count,
                sampleIds: Array(customProcs.prefix(5).map { $0.id })
            ))
            totalReferences += customProcs.count
        }
        
        // Check AuditEntry - as actor (doesn't prevent deletion, just informational)
        // Note: We skip counting audit entries and notifications as they don't prevent deletion
        // and can cause predicate issues with SwiftData
        
        // User can be deleted if no case references exist
        let hasCaseReferences = references.contains { ref in
            ref.entityType.contains("case")
        }
        
        return ReferenceCheckResult(
            canDelete: !hasCaseReferences,
            references: references,
            totalReferences: totalReferences
        )
    }
    
    // MARK: - Safe Archive
    
    /// Safely archive a user after checking references
    func safeArchiveUser(_ user: User, by admin: User?) -> Result<Void, ArchiveError> {
        // Even if user is referenced, we can archive (not delete)
        user.isArchived = true
        user.isActive = false
        user.updatedAt = Date()
        
        try? modelContext?.save()
        
        // Log the archive action
        if let admin = admin {
            AuditService.shared.logUserArchived(by: admin, archivedUser: user)
        }
        
        return .success(())
    }
    
    /// Check if user can be permanently deleted (only if no references)
    func canPermanentlyDelete(userId: UUID) -> Bool {
        let checkResult = checkUserReferences(userId: userId)
        return checkResult.canDelete
    }
    
    /// Permanently delete a user (only if no references exist)
    func permanentlyDeleteUser(_ user: User) -> Result<Void, ArchiveError> {
        guard let context = modelContext else {
            return .failure(.databaseError("No database context"))
        }
        
        let checkResult = checkUserReferences(userId: user.id)
        
        guard checkResult.canDelete else {
            return .failure(.hasReferences(checkResult.references.map { $0.entityType }))
        }
        
        // Delete associated notifications first
        // Fetch all notifications and filter in memory to avoid predicate issues
        let allNotificationsDescriptor = FetchDescriptor<Notification>()
        
        if let allNotifications = try? context.fetch(allNotificationsDescriptor) {
            let userNotifications = allNotifications.filter { $0.userId == user.id }
            for notification in userNotifications {
                context.delete(notification)
            }
        }
        
        // Delete the user
        context.delete(user)
        
        do {
            try context.save()
            return .success(())
        } catch {
            return .failure(.databaseError(error.localizedDescription))
        }
    }
    
    enum ArchiveError: Error, LocalizedError {
        case hasReferences([String])
        case databaseError(String)
        case userNotFound
        
        var errorDescription: String? {
            switch self {
            case .hasReferences(let types):
                return "User cannot be deleted because they are referenced by: \(types.joined(separator: ", "))"
            case .databaseError(let message):
                return "Database error: \(message)"
            case .userNotFound:
                return "User not found"
            }
        }
    }
}

// MARK: - Attending Deletion Service

extension UserDeletionService {
    
    /// Check if an Attending can be safely deleted/archived
    func checkAttendingReferences(attendingId: UUID) -> ReferenceCheckResult {
        guard let context = modelContext else {
            return ReferenceCheckResult(canDelete: false, references: [], totalReferences: 0)
        }
        
        var references: [EntityReference] = []
        var totalReferences = 0
        
        // Check CaseEntry - as supervisor
        let supervisedCasesDescriptor = FetchDescriptor<CaseEntry>(
            predicate: #Predicate { entry in
                entry.supervisorId == attendingId
            }
        )
        
        if let supervisedCases = try? context.fetch(supervisedCasesDescriptor), !supervisedCases.isEmpty {
            references.append(EntityReference(
                entityType: "case (as Supervisor)",
                count: supervisedCases.count,
                sampleIds: Array(supervisedCases.prefix(5).map { $0.id })
            ))
            totalReferences += supervisedCases.count
        }
        
        return ReferenceCheckResult(
            canDelete: references.isEmpty,
            references: references,
            totalReferences: totalReferences
        )
    }
    
    /// Safely archive an Attending
    func safeArchiveAttending(_ attending: Attending) -> Result<Void, ArchiveError> {
        attending.isArchived = true
        try? modelContext?.save()
        return .success(())
    }
}

// MARK: - Facility Deletion Service

extension UserDeletionService {
    
    /// Check if a Facility can be safely deleted/archived
    func checkFacilityReferences(facilityId: UUID) -> ReferenceCheckResult {
        guard let context = modelContext else {
            return ReferenceCheckResult(canDelete: false, references: [], totalReferences: 0)
        }
        
        var references: [EntityReference] = []
        var totalReferences = 0
        
        // Check CaseEntry - as hospital
        let casesDescriptor = FetchDescriptor<CaseEntry>(
            predicate: #Predicate { entry in
                entry.hospitalId == facilityId
            }
        )
        
        if let cases = try? context.fetch(casesDescriptor), !cases.isEmpty {
            references.append(EntityReference(
                entityType: "case",
                count: cases.count,
                sampleIds: Array(cases.prefix(5).map { $0.id })
            ))
            totalReferences += cases.count
        }
        
        return ReferenceCheckResult(
            canDelete: references.isEmpty,
            references: references,
            totalReferences: totalReferences
        )
    }
    
    /// Safely archive a Facility
    func safeArchiveFacility(_ facility: TrainingFacility) -> Result<Void, ArchiveError> {
        facility.isArchived = true
        try? modelContext?.save()
        return .success(())
    }
}

// MARK: - Deletion Confirmation View

struct DeletionConfirmationView: View {
    let entityName: String
    let entityType: String
    let checkResult: UserDeletionService.ReferenceCheckResult
    let onConfirmArchive: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Warning icon
            Image(systemName: checkResult.canDelete ? "trash.circle" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(checkResult.canDelete ? ProcedusTheme.error : ProcedusTheme.warning)
            
            // Title
            Text(checkResult.canDelete ? "Delete \(entityType)?" : "Cannot Delete \(entityType)")
                .font(.headline)
            
            // Entity name
            Text(entityName)
                .font(.subheadline)
                .foregroundStyle(ProcedusTheme.textSecondary)
            
            // References info
            if !checkResult.references.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This \(entityType) is referenced by:")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                    
                    ForEach(checkResult.references, id: \.entityType) { ref in
                        HStack {
                            Image(systemName: "link")
                                .foregroundStyle(ProcedusTheme.warning)
                            Text("\(ref.count) \(ref.entityType)")
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(ProcedusTheme.warning.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Explanation
            if !checkResult.canDelete {
                Text("You can archive this \(entityType) instead. Archived items are hidden but preserved for historical records.")
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ProcedusTheme.cardBackground)
                .cornerRadius(10)
                
                Button(checkResult.canDelete ? "Delete" : "Archive") {
                    onConfirmArchive()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(checkResult.canDelete ? ProcedusTheme.error : ProcedusTheme.warning)
                .foregroundStyle(.white)
                .cornerRadius(10)
            }
        }
        .padding(24)
    }
}
