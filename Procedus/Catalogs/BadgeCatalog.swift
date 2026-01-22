// BadgeCatalog.swift
// Procedus - Unified
// Predefined badge definitions for fellow achievements

import Foundation

/// Catalog of all predefined badges
struct BadgeCatalog {

    // MARK: - Badge Generation

    /// Get all predefined badges
    static func allBadges() -> [Badge] {
        var badges: [Badge] = []

        // First procedure badges
        badges.append(contentsOf: firstProcedureBadges)

        // Procedure milestone badges (every 50)
        badges.append(contentsOf: generateProcedureMilestones())

        // Category milestone badges
        badges.append(contentsOf: categoryMilestoneBadges)

        // Total case badges
        badges.append(contentsOf: totalCaseBadges)

        // Diversity badges
        badges.append(contentsOf: diversityBadges)

        return badges
    }

    // MARK: - First Procedure Badges (First as Primary Operator)

    static var firstProcedureBadges: [Badge] {
        [
            // Coronary Intervention
            Badge(
                id: "first-pci-primary",
                title: "First PCI",
                description: "Completed your first coronary intervention as primary operator",
                iconName: "heart.fill",
                badgeType: .firstAsPrimary,
                criteria: .firstAsPrimary(anyOf: [
                    "ic-pci-stent", "ic-pci-poba", "ic-pci-dcb",
                    "ic-pci-rotablator", "ic-pci-orbital", "ic-pci-laser",
                    "ic-pci-ivl", "ic-pci-thrombectomy"
                ]),
                tier: .silver,
                pointValue: 50
            ),

            // Structural - TAVR
            Badge(
                id: "first-tavr-primary",
                title: "First TAVR",
                description: "Performed your first TAVR as primary operator",
                iconName: "bolt.heart.fill",
                badgeType: .firstAsPrimary,
                criteria: .firstAsPrimary(procedureTagId: "ic-struct-tavr"),
                tier: .gold,
                pointValue: 100
            ),

            // Structural - TEER
            Badge(
                id: "first-teer-primary",
                title: "First TEER",
                description: "Performed your first MitraClip/PASCAL as primary operator",
                iconName: "bolt.heart",
                badgeType: .firstAsPrimary,
                criteria: .firstAsPrimary(procedureTagId: "ic-struct-teer"),
                tier: .gold,
                pointValue: 100
            ),

            // EP - Ablation
            Badge(
                id: "first-ablation-primary",
                title: "First Ablation",
                description: "Completed your first cardiac ablation as primary operator",
                iconName: "bolt.fill",
                badgeType: .firstAsPrimary,
                criteria: .firstInCategoryAsPrimary(category: ProcedureCategory.ablation.rawValue),
                tier: .silver,
                pointValue: 50
            ),

            // EP - PVI
            Badge(
                id: "first-pvi-primary",
                title: "First PVI",
                description: "Performed your first Pulmonary Vein Isolation as primary operator",
                iconName: "waveform.path.ecg",
                badgeType: .firstAsPrimary,
                criteria: .firstAsPrimary(procedureTagId: "ep-abl-pvi"),
                tier: .gold,
                pointValue: 75
            ),

            // Device Implant
            Badge(
                id: "first-device-primary",
                title: "First Device Implant",
                description: "Implanted your first cardiac device as primary operator",
                iconName: "waveform.badge.plus",
                badgeType: .firstAsPrimary,
                criteria: .firstInCategoryAsPrimary(category: ProcedureCategory.implants.rawValue),
                tier: .silver,
                pointValue: 50
            ),

            // Peripheral
            Badge(
                id: "first-peripheral-primary",
                title: "First Peripheral",
                description: "Completed your first peripheral arterial intervention as primary operator",
                iconName: "figure.walk",
                badgeType: .firstAsPrimary,
                criteria: .firstInCategoryAsPrimary(category: ProcedureCategory.peripheralArterial.rawValue),
                tier: .silver,
                pointValue: 50
            ),

            // MCS - Impella
            Badge(
                id: "first-impella-primary",
                title: "First Impella",
                description: "Placed your first Impella as primary operator",
                iconName: "heart.circle.fill",
                badgeType: .firstAsPrimary,
                criteria: .firstAsPrimary(procedureTagId: "ic-mcs-impella"),
                tier: .gold,
                pointValue: 75
            ),

            // Diagnostic - Right Heart Cath
            Badge(
                id: "first-rhc-primary",
                title: "First Right Heart Cath",
                description: "Performed your first RHC as primary operator",
                iconName: "arrow.up.heart.fill",
                badgeType: .firstAsPrimary,
                criteria: .firstAsPrimary(procedureTagId: "ic-dx-rhc"),
                tier: .bronze,
                pointValue: 25
            ),

            // Diagnostic - Coronary Angio
            Badge(
                id: "first-coro-primary",
                title: "First Coronary Angio",
                description: "Performed your first coronary angiogram as primary operator",
                iconName: "heart.text.square.fill",
                badgeType: .firstAsPrimary,
                criteria: .firstAsPrimary(procedureTagId: "ic-dx-coro"),
                tier: .bronze,
                pointValue: 25
            )
        ]
    }

    // MARK: - Procedure Milestone Badges

    /// Generate milestone badges (50, 100, 150, etc.) for key procedures
    static func generateProcedureMilestones() -> [Badge] {
        var badges: [Badge] = []

        // Procedures to track with milestones
        let trackedProcedures: [(tagId: String, name: String, iconName: String)] = [
            ("ic-pci-stent", "Coronary Stent", "heart.fill"),
            ("ic-dx-coro", "Coronary Angio", "heart.text.square.fill"),
            ("ic-dx-rhc", "Right Heart Cath", "arrow.up.heart.fill"),
            ("ic-struct-tavr", "TAVR", "bolt.heart.fill"),
            ("ic-struct-teer", "TEER", "bolt.heart"),
            ("ep-abl-pvi", "PVI", "waveform.path.ecg"),
            ("ep-dev-ppm-dp", "Pacemaker", "waveform.badge.plus"),
            ("ep-dev-icd", "ICD", "bolt.badge.checkmark.fill")
        ]

        let milestones = [50, 100, 150, 200, 250, 300, 400, 500]

        for procedure in trackedProcedures {
            for (index, milestone) in milestones.enumerated() {
                // Determine tier based on milestone level
                let tier: BadgeTier
                switch index {
                case 0...1: tier = .bronze
                case 2...3: tier = .silver
                case 4...5: tier = .gold
                default: tier = .platinum
                }

                let points = milestone / 5 * 2  // Scale points with milestone

                badges.append(Badge(
                    id: "milestone-\(milestone)-\(procedure.tagId)",
                    title: "\(milestone) \(procedure.name)s",
                    description: "Completed \(milestone) \(procedure.name) procedures",
                    iconName: procedure.iconName,
                    badgeType: .milestone,
                    criteria: .milestone(procedureTagId: procedure.tagId, count: milestone),
                    tier: tier,
                    pointValue: points
                ))
            }
        }

        return badges
    }

    // MARK: - Category Milestone Badges

    static var categoryMilestoneBadges: [Badge] {
        var badges: [Badge] = []

        let categoryMilestones: [(category: ProcedureCategory, milestones: [Int], iconName: String)] = [
            (.coronaryIntervention, [100, 250, 500, 1000], "heart.fill"),
            (.structuralValve, [25, 50, 100, 200], "bolt.heart.fill"),
            (.ablation, [50, 100, 200, 300], "bolt.fill"),
            (.implants, [50, 100, 200, 300], "waveform.badge.plus"),
            (.peripheralArterial, [50, 100, 200], "figure.walk"),
            (.mcs, [25, 50, 100], "heart.circle.fill")
        ]

        for (category, milestones, iconName) in categoryMilestones {
            for (index, milestone) in milestones.enumerated() {
                let tier: BadgeTier
                switch index {
                case 0: tier = .bronze
                case 1: tier = .silver
                case 2: tier = .gold
                default: tier = .platinum
                }

                let categoryId = category.rawValue.lowercased()
                    .replacingOccurrences(of: " ", with: "-")
                    .replacingOccurrences(of: "/", with: "-")

                badges.append(Badge(
                    id: "category-\(milestone)-\(categoryId)",
                    title: "\(milestone) \(category.rawValue)",
                    description: "Completed \(milestone) total \(category.rawValue) procedures",
                    iconName: iconName,
                    badgeType: .categoryMilestone,
                    criteria: .categoryMilestone(category: category.rawValue, count: milestone),
                    tier: tier,
                    pointValue: milestone / 10 * 3
                ))
            }
        }

        return badges
    }

    // MARK: - Total Case Badges

    static var totalCaseBadges: [Badge] {
        [
            Badge(
                id: "total-cases-100",
                title: "Century",
                description: "Logged 100 total cases",
                iconName: "100.circle.fill",
                badgeType: .totalCases,
                criteria: .totalCases(count: 100),
                tier: .bronze,
                pointValue: 50
            ),
            Badge(
                id: "total-cases-250",
                title: "Quarter Millennium",
                description: "Logged 250 total cases",
                iconName: "number.circle.fill",
                badgeType: .totalCases,
                criteria: .totalCases(count: 250),
                tier: .silver,
                pointValue: 100
            ),
            Badge(
                id: "total-cases-500",
                title: "Half Millennium",
                description: "Logged 500 total cases",
                iconName: "star.circle.fill",
                badgeType: .totalCases,
                criteria: .totalCases(count: 500),
                tier: .gold,
                pointValue: 150
            ),
            Badge(
                id: "total-cases-1000",
                title: "Millennium",
                description: "Logged 1000 total cases",
                iconName: "trophy.fill",
                badgeType: .totalCases,
                criteria: .totalCases(count: 1000),
                tier: .platinum,
                pointValue: 300
            )
        ]
    }

    // MARK: - Diversity Badges

    static var diversityBadges: [Badge] {
        [
            Badge(
                id: "diversity-10",
                title: "Well-Rounded",
                description: "Performed 10 different procedure types",
                iconName: "chart.pie.fill",
                badgeType: .diversity,
                criteria: .diversity(uniqueProcedureCount: 10),
                tier: .bronze,
                pointValue: 40
            ),
            Badge(
                id: "diversity-25",
                title: "Versatile",
                description: "Performed 25 different procedure types",
                iconName: "chart.pie.fill",
                badgeType: .diversity,
                criteria: .diversity(uniqueProcedureCount: 25),
                tier: .silver,
                pointValue: 75
            ),
            Badge(
                id: "diversity-50",
                title: "Polymath",
                description: "Performed 50 different procedure types",
                iconName: "chart.pie.fill",
                badgeType: .diversity,
                criteria: .diversity(uniqueProcedureCount: 50),
                tier: .gold,
                pointValue: 150
            )
        ]
    }

    // MARK: - Helper to Find Badge by ID

    static func badge(withId id: String) -> Badge? {
        allBadges().first { $0.id == id }
    }
}
