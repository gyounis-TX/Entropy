// NotificationManager.swift
// Procedus - Unified
// In-app notification management with auto-clear behavior
// NOTE: Uses Notification model from Models.swift

import Foundation
import SwiftData
import SwiftUI
import Combine

// MARK: - Notification Manager

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    private init() {}
    
    private var modelContext: ModelContext?
    
    @Published var unreadCount: Int = 0
    
    func configure(with context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Create Notifications
    
    func notifyAttestationRequested(
        toAttendingId: UUID,
        fellowName: String,
        caseId: UUID,
        procedureCount: Int,
        procedureTitles: [String]? = nil,
        programId: UUID?
    ) {
        // Build message with procedure names if available
        let message: String
        if let titles = procedureTitles, !titles.isEmpty {
            let procedureList = titles.prefix(3).joined(separator: ", ")
            let suffix = titles.count > 3 ? " + \(titles.count - 3) more" : ""
            message = "\(fellowName) submitted a case of \(procedureList)\(suffix) for your attestation."
        } else {
            message = "\(fellowName) submitted a case of \(procedureCount) procedure(s) for your attestation."
        }

        createNotification(
            userId: toAttendingId,
            attendingId: toAttendingId,
            title: "New Attestation Request",
            message: message,
            type: .attestationRequested,
            caseId: caseId
        )
    }
    
    func notifyAttestationComplete(
        toFellowId: UUID,
        attendingName: String,
        caseId: UUID,
        weekBucket: String,
        programId: UUID?
    ) {
        createNotification(
            userId: toFellowId,
            title: "Case Attested",
            message: "Your case from \(weekBucket) was attested by \(attendingName).",
            type: .attestationComplete,
            caseId: caseId
        )
        
        autoClearNotifications(
            forCaseId: caseId,
            types: [.attestationRequested],
            reason: "Case has been attested"
        )
    }
    
    func notifyCaseRejected(
        toFellowId: UUID,
        attendingName: String,
        caseId: UUID,
        weekBucket: String,
        reason: String,
        programId: UUID?
    ) {
        createNotification(
            userId: toFellowId,
            title: "Case Rejected",
            message: "Your case from \(weekBucket) was rejected by \(attendingName). Reason: \(reason)",
            type: .caseRejected,
            caseId: caseId
        )
        
        autoClearNotifications(
            forCaseId: caseId,
            types: [.attestationRequested],
            reason: "Case has been rejected"
        )
    }
    
    func notifyProgramChange(
        toUserIds: [UUID],
        changeDescription: String,
        programId: UUID
    ) {
        for userId in toUserIds {
            createNotification(
                userId: userId,
                title: "Program Update",
                message: changeDescription,
                type: .programChange,
                caseId: nil
            )
        }
    }

    // MARK: - Duty Hours Notifications

    /// Notify about duty hours warning (approaching limit)
    func notifyDutyHoursWarning(
        toFellowId: UUID,
        fellowName: String,
        warningTypes: [DutyHoursViolationType],
        adminIds: [UUID],
        programId: UUID?
    ) {
        guard !warningTypes.isEmpty else { return }

        let warningDescriptions = warningTypes.map { $0.displayName }
        let warningList = warningDescriptions.joined(separator: ", ")

        // Notify fellow
        createNotification(
            userId: toFellowId,
            title: "Duty Hours Warning",
            message: "You are approaching ACGME duty hours limits: \(warningList). Please monitor your hours.",
            type: .dutyHoursWarning,
            caseId: nil
        )

        // Notify admin(s)
        for adminId in adminIds {
            createNotification(
                userId: adminId,
                title: "Fellow Duty Hours Warning",
                message: "\(fellowName) is approaching ACGME duty hours limits: \(warningList)",
                type: .dutyHoursWarning,
                caseId: nil
            )
        }
    }

    /// Notify about duty hours violation (limit exceeded)
    func notifyDutyHoursViolation(
        toFellowId: UUID,
        fellowName: String,
        violationTypes: [DutyHoursViolationType],
        adminIds: [UUID],
        programId: UUID?
    ) {
        guard !violationTypes.isEmpty else { return }

        let violationDescriptions = violationTypes.map { $0.displayName }
        let violationList = violationDescriptions.joined(separator: ", ")

        // Notify fellow
        createNotification(
            userId: toFellowId,
            title: "Duty Hours Violation",
            message: "ACGME duty hours violation detected: \(violationList). Please contact your program director.",
            type: .dutyHoursViolation,
            caseId: nil
        )

        // Notify admin(s)
        for adminId in adminIds {
            createNotification(
                userId: adminId,
                title: "Fellow Duty Hours Violation",
                message: "\(fellowName) has a duty hours violation: \(violationList). Immediate attention required.",
                type: .dutyHoursViolation,
                caseId: nil
            )
        }
    }

    // MARK: - Teaching Files Notifications

    /// Notify all fellows and attendings in a program that a new teaching file was uploaded.
    func notifyTeachingFileUploaded(
        uploaderName: String,
        uploaderUserId: UUID,
        mediaId: UUID,
        programId: UUID
    ) {
        guard let context = modelContext else { return }

        // Fetch active fellows in the same program
        let fellowDescriptor = FetchDescriptor<User>(
            predicate: #Predicate { user in
                user.programId == programId &&
                user.isActive &&
                !user.isArchived &&
                !user.hasGraduated
            }
        )

        // Fetch active attendings in the same program
        let attendingDescriptor = FetchDescriptor<Attending>(
            predicate: #Predicate { attending in
                attending.programId == programId &&
                !attending.isArchived
            }
        )

        do {
            let fellows = try context.fetch(fellowDescriptor)
            let attendings = try context.fetch(attendingDescriptor)

            let message = "\(uploaderName) has uploaded a new case to Teaching Files. Navigate to Teaching Files to view and comment."

            // Notify fellows (skip the uploader)
            for fellow in fellows where fellow.id != uploaderUserId {
                createNotification(
                    userId: fellow.id,
                    title: "New Teaching File",
                    message: message,
                    type: .teachingFileUploaded,
                    caseId: nil
                )
            }

            // Notify attendings (skip if the uploader is also an attending by userId match)
            for attending in attendings {
                if attending.userId == uploaderUserId { continue }
                createNotification(
                    userId: attending.id,
                    title: "New Teaching File",
                    message: message,
                    type: .teachingFileUploaded,
                    caseId: nil
                )
            }
        } catch {
            print("[NotificationManager] Failed to send teaching file notifications: \(error)")
        }
    }

    // MARK: - Private Helpers

    private func createNotification(
        userId: UUID,
        attendingId: UUID? = nil,
        title: String,
        message: String,
        type: NotificationType,
        caseId: UUID?
    ) {
        guard let context = modelContext else { return }

        let notification = Notification(
            userId: userId,
            title: title,
            message: message,
            notificationType: type.rawValue,
            caseId: caseId
        )
        notification.attendingId = attendingId

        context.insert(notification)
        try? context.save()
        updateUnreadCount(forUserId: userId)
    }
    
    // MARK: - Auto-Clear Behavior
    
    func autoClearNotifications(
        forCaseId caseId: UUID,
        types: [NotificationType],
        reason: String
    ) {
        guard let context = modelContext else { return }
        
        let typeStrings = types.map { $0.rawValue }
        
        let descriptor = FetchDescriptor<Notification>(
            predicate: #Predicate { notification in
                notification.caseId == caseId && !notification.isCleared
            }
        )
        
        do {
            let notifications = try context.fetch(descriptor)
            let now = Date()
            
            for notification in notifications {
                if typeStrings.contains(notification.notificationType) {
                    notification.isCleared = true
                    notification.autoCleared = true
                    notification.autoClearReason = reason
                    notification.clearedAt = now
                }
            }
            
            try context.save()
        } catch {
            print("Failed to auto-clear notifications: \(error)")
        }
    }
    
    // MARK: - User Actions
    
    func markAsRead(_ notification: Notification) {
        notification.isRead = true
        notification.readAt = Date()
        try? modelContext?.save()
        updateUnreadCount(forUserId: notification.userId)
    }
    
    func markAllAsRead(forUserId userId: UUID) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Notification>(
            predicate: #Predicate { notification in
                notification.userId == userId && !notification.isRead && !notification.isCleared
            }
        )
        
        do {
            let notifications = try context.fetch(descriptor)
            let now = Date()
            for notification in notifications {
                notification.isRead = true
                notification.readAt = now
            }
            try context.save()
            updateUnreadCount(forUserId: userId)
        } catch {
            print("Failed to mark all as read: \(error)")
        }
    }
    
    func clearNotification(_ notification: Notification) {
        notification.isCleared = true
        notification.clearedAt = Date()
        try? modelContext?.save()
        updateUnreadCount(forUserId: notification.userId)
    }
    
    func clearAllNotifications(forUserId userId: UUID) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Notification>(
            predicate: #Predicate { notification in
                notification.userId == userId && !notification.isCleared
            }
        )
        
        do {
            let notifications = try context.fetch(descriptor)
            let now = Date()
            for notification in notifications {
                notification.isCleared = true
                notification.clearedAt = now
            }
            try context.save()
            updateUnreadCount(forUserId: userId)
        } catch {
            print("Failed to clear all notifications: \(error)")
        }
    }
    
    // MARK: - Fetch
    
    func fetchNotifications(forUserId userId: UUID, includeCleared: Bool = false) -> [Notification] {
        guard let context = modelContext else { return [] }
        
        var descriptor: FetchDescriptor<Notification>
        
        if includeCleared {
            descriptor = FetchDescriptor<Notification>(
                predicate: #Predicate { notification in
                    notification.userId == userId
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<Notification>(
                predicate: #Predicate { notification in
                    notification.userId == userId && !notification.isCleared
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        }
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch notifications: \(error)")
            return []
        }
    }
    
    func updateUnreadCount(forUserId userId: UUID) {
        guard let context = modelContext else {
            unreadCount = 0
            return
        }
        
        let descriptor = FetchDescriptor<Notification>(
            predicate: #Predicate { notification in
                notification.userId == userId && !notification.isRead && !notification.isCleared
            }
        )
        
        do {
            let count = try context.fetchCount(descriptor)
            DispatchQueue.main.async {
                self.unreadCount = count
            }
        } catch {
            print("Failed to count unread notifications: \(error)")
        }
    }
}

// MARK: - Audit Service

class AuditService {
    static let shared = AuditService()
    private init() {}
    
    private var modelContext: ModelContext?
    
    func configure(with context: ModelContext) {
        self.modelContext = context
    }
    
    func log(
        userId: UUID?,
        userRole: UserRole,
        userName: String,
        action: AuditActionType,
        entityType: AuditEntityType,
        entityId: UUID?,
        entityName: String,
        details: String = "",
        previousValue: String? = nil,
        newValue: String? = nil,
        programId: UUID? = nil
    ) {
        guard let context = modelContext else {
            print("AuditService: ModelContext not configured")
            return
        }
        
        let entry = AuditEntry(
            userId: userId,
            userRole: userRole.rawValue,
            userName: userName,
            actionType: action.rawValue,
            entityType: entityType.rawValue,
            entityId: entityId,
            entityName: entityName,
            details: details,
            programId: programId
        )
        
        context.insert(entry)
        try? context.save()
    }
    
    func logCaseCreated(by user: User, caseEntry: CaseEntry, procedureCount: Int) {
        log(
            userId: user.id,
            userRole: user.role,
            userName: user.displayName,
            action: .created,
            entityType: .caseEntry,
            entityId: caseEntry.id,
            entityName: "Case \(caseEntry.weekBucket)",
            details: "Created case with \(procedureCount) procedures",
            programId: user.programId
        )
    }
    
    func logCaseAttested(by user: User, caseEntry: CaseEntry, fellowName: String) {
        log(
            userId: user.id,
            userRole: user.role,
            userName: user.displayName,
            action: .attested,
            entityType: .caseEntry,
            entityId: caseEntry.id,
            entityName: "\(fellowName)'s case \(caseEntry.weekBucket)",
            programId: user.programId
        )
    }
    
    func logUserArchived(by admin: User, archivedUser: User) {
        log(
            userId: admin.id,
            userRole: admin.role,
            userName: admin.displayName,
            action: .archived,
            entityType: .user,
            entityId: archivedUser.id,
            entityName: archivedUser.fullName,
            programId: admin.programId
        )
    }
    
    func logDataImported(by user: User, caseCount: Int, source: String) {
        log(
            userId: user.id,
            userRole: user.role,
            userName: user.displayName,
            action: .imported,
            entityType: .caseEntry,
            entityId: nil,
            entityName: "\(caseCount) cases",
            details: "Imported from \(source)",
            programId: user.programId
        )
    }
}
