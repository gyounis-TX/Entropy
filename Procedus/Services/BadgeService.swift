// BadgeService.swift
// Procedus - Unified
// Badge checking and awarding logic

import Foundation
import SwiftData
import SwiftUI

/// Service for checking and awarding badges to fellows
@Observable
class BadgeService {

    // MARK: - Singleton

    static let shared = BadgeService()
    private init() {}

    // MARK: - Recently Earned (for UI notification)

    /// Badges earned in the most recent check (for celebration overlay)
    var recentlyEarnedBadges: [BadgeEarned] = []

    // MARK: - Main Badge Check

    /// Check and award badges after case attestation
    /// - Parameters:
    ///   - fellowId: The fellow's user ID
    ///   - attestedCase: The case that was just attested
    ///   - allCases: All cases for this fellow
    ///   - existingBadges: Badges the fellow has already earned
    ///   - modelContext: SwiftData context for saving
    /// - Returns: Array of newly earned badges
    func checkAndAwardBadges(
        for fellowId: UUID,
        attestedCase: CaseEntry,
        allCases: [CaseEntry],
        existingBadges: [BadgeEarned],
        modelContext: ModelContext
    ) -> [BadgeEarned] {
        var newlyEarned: [BadgeEarned] = []

        // Filter to eligible cases (attested, not rejected, not archived)
        let eligibleCases = allCases.filter { caseEntry in
            (caseEntry.ownerId == fellowId || caseEntry.fellowId == fellowId) &&
            caseEntry.attestationStatus == .attested &&
            !caseEntry.isArchived
        }

        // Get all badge definitions from catalog
        let allBadges = BadgeCatalog.allBadges()
        let earnedBadgeIds = Set(existingBadges.map { $0.badgeId })

        // Check each badge that hasn't been earned yet
        for badge in allBadges where badge.isActive && !earnedBadgeIds.contains(badge.id) {
            if let criteria = badge.criteria,
               checkCriteriaMet(criteria, badge: badge, eligibleCases: eligibleCases) {

                // Award the badge
                let earned = BadgeEarned(
                    badgeId: badge.id,
                    fellowId: fellowId,
                    programId: attestedCase.programId,
                    triggeringCaseId: attestedCase.id,
                    procedureCount: countForCriteria(criteria, cases: eligibleCases)
                )

                modelContext.insert(earned)
                newlyEarned.append(earned)
            }
        }

        if !newlyEarned.isEmpty {
            try? modelContext.save()
            recentlyEarnedBadges = newlyEarned
        }

        return newlyEarned
    }

    // MARK: - Criteria Checking

    private func checkCriteriaMet(
        _ criteria: BadgeCriteria,
        badge: Badge,
        eligibleCases: [CaseEntry]
    ) -> Bool {
        // Check diversity badges separately
        if let uniqueCount = criteria.minimumUniqueProcedures {
            return checkDiversityCriteria(uniqueCount: uniqueCount, cases: eligibleCases)
        }

        let count = countForCriteria(criteria, cases: eligibleCases)
        return count >= criteria.minimumCount
    }

    private func checkDiversityCriteria(uniqueCount: Int, cases: [CaseEntry]) -> Bool {
        var uniqueProcedures = Set<String>()
        for caseEntry in cases {
            for tagId in caseEntry.procedureTagIds {
                uniqueProcedures.insert(tagId)
            }
        }
        return uniqueProcedures.count >= uniqueCount
    }

    /// Count procedures/cases that match criteria
    private func countForCriteria(_ criteria: BadgeCriteria, cases: [CaseEntry]) -> Int {
        var matchingCases = cases

        // Filter by operator position if required
        if criteria.requiresPrimaryOperator {
            matchingCases = matchingCases.filter { $0.operatorPosition == .primary }
        }

        // Filter by time if specified
        if let withinDays = criteria.withinDays {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -withinDays, to: Date()) ?? Date()
            matchingCases = matchingCases.filter { $0.createdAt >= cutoffDate }
        }

        // Filter by academic year if required
        if criteria.academicYearOnly {
            let startOfAcademicYear = academicYearStartDate(for: Date())
            matchingCases = matchingCases.filter { $0.createdAt >= startOfAcademicYear }
        }

        // Count based on criteria type
        if let procedureTagId = criteria.procedureTagId {
            // Single procedure type - count procedure occurrences
            return matchingCases.reduce(0) { count, caseEntry in
                count + caseEntry.procedureTagIds.filter { $0 == procedureTagId }.count
            }
        } else if let procedureTagIds = criteria.procedureTagIds, !procedureTagIds.isEmpty {
            // Multiple procedure types (any of) - count procedure occurrences
            let tagSet = Set(procedureTagIds)
            return matchingCases.reduce(0) { count, caseEntry in
                count + caseEntry.procedureTagIds.filter { tagSet.contains($0) }.count
            }
        } else if let categoryRaw = criteria.category {
            // Category-based - count procedures in category
            return matchingCases.reduce(0) { count, caseEntry in
                count + caseEntry.procedureTagIds.filter { tagId in
                    SpecialtyPackCatalog.findCategory(for: tagId)?.rawValue == categoryRaw
                }.count
            }
        } else {
            // Total case count
            return matchingCases.count
        }
    }

    // MARK: - Progress Tracking

    /// Get progress toward next milestone for a specific procedure
    func progressTowardNextMilestone(
        procedureTagId: String,
        fellowId: UUID,
        cases: [CaseEntry],
        earnedBadges: [BadgeEarned]
    ) -> (current: Int, next: Int, percentage: Double)? {
        let eligibleCases = cases.filter {
            ($0.ownerId == fellowId || $0.fellowId == fellowId) &&
            $0.attestationStatus == .attested &&
            !$0.isArchived
        }

        let currentCount = eligibleCases.reduce(0) { count, caseEntry in
            count + caseEntry.procedureTagIds.filter { $0 == procedureTagId }.count
        }

        // Find next milestone (every 50)
        let nextMilestone = ((currentCount / 50) + 1) * 50
        let progress = currentCount % 50
        let percentage = Double(progress) / 50.0

        return (current: currentCount, next: nextMilestone, percentage: percentage)
    }

    /// Get progress toward total case milestone
    func progressTowardTotalCases(
        fellowId: UUID,
        cases: [CaseEntry],
        earnedBadges: [BadgeEarned]
    ) -> (current: Int, next: Int, percentage: Double)? {
        let eligibleCases = cases.filter {
            ($0.ownerId == fellowId || $0.fellowId == fellowId) &&
            $0.attestationStatus == .attested &&
            !$0.isArchived
        }

        let currentCount = eligibleCases.count

        // Find next milestone (100, 250, 500, 1000)
        let milestones = [100, 250, 500, 1000]
        let nextMilestone = milestones.first { $0 > currentCount } ?? 1000
        let previousMilestone = milestones.filter { $0 <= currentCount }.last ?? 0
        let progressInRange = currentCount - previousMilestone
        let rangeSize = nextMilestone - previousMilestone
        let percentage = rangeSize > 0 ? Double(progressInRange) / Double(rangeSize) : 1.0

        return (current: currentCount, next: nextMilestone, percentage: percentage)
    }

    /// Get all progress data for dashboard based on enabled specialty packs
    func getAllProgress(
        fellowId: UUID,
        cases: [CaseEntry],
        earnedBadges: [BadgeEarned],
        enabledPackIds: Set<String> = []
    ) -> [BadgeProgress] {
        var progress: [BadgeProgress] = []
        var keyProcedures: [(tagId: String, name: String, iconName: String)] = []

        // Add procedures based on enabled specialty packs
        let hasInterventional = enabledPackIds.contains("interventional-cardiology")
        let hasEP = enabledPackIds.contains("electrophysiology")

        if hasInterventional {
            // Coronary interventions
            keyProcedures.append(("ic-pci-stent", "Coronary Stent", "heart.fill"))
            keyProcedures.append(("ic-dx-coro", "Coronary Angio", "heart.text.square.fill"))
            keyProcedures.append(("ic-struct-tavr", "TAVR", "bolt.heart.fill"))
            // Peripheral interventions (from interventional cardiology pack)
            keyProcedures.append(contentsOf: peripheralMilestones())
        }

        if hasEP {
            // Ablations
            keyProcedures.append(("ep-abl-pvi", "PVI", "waveform.path.ecg"))
            // Could add category-based progress for all ablations
            // Implants
            keyProcedures.append(("ep-dev-ppm-dp", "Pacemaker", "waveform.badge.plus"))
            keyProcedures.append(("ep-dev-icd", "ICD", "bolt.badge.checkmark.fill"))
            // EP Studies
            keyProcedures.append(("ep-dx-eps", "EP Study", "bolt"))
        }

        // If no cardiology packs, just show total cases
        if keyProcedures.isEmpty {
            if let totalData = progressTowardTotalCases(
                fellowId: fellowId,
                cases: cases,
                earnedBadges: earnedBadges
            ) {
                progress.append(BadgeProgress(
                    title: "Total Cases",
                    current: totalData.current,
                    next: totalData.next,
                    percentage: totalData.percentage,
                    iconName: "number.circle.fill"
                ))
            }
            return progress
        }

        for (tagId, name, iconName) in keyProcedures {
            if let data = progressTowardNextMilestone(
                procedureTagId: tagId,
                fellowId: fellowId,
                cases: cases,
                earnedBadges: earnedBadges
            ) {
                // Only show if user has at least 1 procedure in this category
                if data.current > 0 {
                    progress.append(BadgeProgress(
                        title: name,
                        current: data.current,
                        next: data.next,
                        percentage: data.percentage,
                        iconName: iconName
                    ))
                }
            }
        }

        // Add total cases progress
        if let totalData = progressTowardTotalCases(
            fellowId: fellowId,
            cases: cases,
            earnedBadges: earnedBadges
        ) {
            progress.append(BadgeProgress(
                title: "Total Cases",
                current: totalData.current,
                next: totalData.next,
                percentage: totalData.percentage,
                iconName: "number.circle.fill"
            ))
        }

        return progress
    }

    /// Get peripheral intervention milestone procedures
    private func peripheralMilestones() -> [(tagId: String, name: String, iconName: String)] {
        // Track peripheral interventions as a category-based milestone
        // Instead of individual procedures, we'll track the most common ones
        return [
            ("ic-periph-iliac", "Iliac Intervention", "figure.walk"),
            ("ic-periph-fem", "Femoral Intervention", "figure.walk"),
            ("ic-periph-renal", "Renal Intervention", "figure.walk")
        ]
    }

    // MARK: - Helpers

    private func academicYearStartDate(for date: Date) -> Date {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let academicYearStartYear = month < 7 ? year - 1 : year
        var components = DateComponents()
        components.year = academicYearStartYear
        components.month = 7
        components.day = 1
        return calendar.date(from: components) ?? date
    }

    // MARK: - Clear Recent Badges

    func clearRecentlyEarned() {
        recentlyEarnedBadges = []
    }
}

// MARK: - Badge Progress Model

struct BadgeProgress: Identifiable {
    let id = UUID()
    let title: String
    let current: Int
    let next: Int
    let percentage: Double
    let iconName: String
}
