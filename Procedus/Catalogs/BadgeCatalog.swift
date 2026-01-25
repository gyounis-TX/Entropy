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

        // First procedure badges (any operator role)
        badges.append(contentsOf: firstProcedureAnyRoleBadges)

        // First as primary operator badges
        badges.append(contentsOf: firstAsPrimaryBadges)

        // Procedure milestone badges (every 50)
        badges.append(contentsOf: generateProcedureMilestones())

        // Category milestone badges
        badges.append(contentsOf: categoryMilestoneBadges)

        // Total case badges
        badges.append(contentsOf: totalCaseBadges)

        // Diversity badges
        badges.append(contentsOf: diversityBadges)

        // COCATS training level badges (cardiology-specific)
        badges.append(contentsOf: cocatsTrainingBadges)

        return badges
    }

    // MARK: - First Procedure Badges (Any Operator Role)

    static var firstProcedureAnyRoleBadges: [Badge] {
        [
            Badge(
                id: "first-pci-any",
                title: "First PCI",
                description: "Participated in your first coronary intervention",
                iconName: "heart.fill",
                badgeType: .firstProcedure,
                criteria: .firstProcedure(anyOf: [
                    "ic-pci-stent", "ic-pci-poba", "ic-pci-dcb",
                    "ic-pci-rotablator", "ic-pci-orbital", "ic-pci-laser",
                    "ic-pci-ivl", "ic-pci-thrombectomy"
                ]),
                tier: .bronze,
                pointValue: 25
            ),
            Badge(
                id: "first-tavr-any",
                title: "First TAVR",
                description: "Participated in your first TAVR procedure",
                iconName: "bolt.heart.fill",
                badgeType: .firstProcedure,
                criteria: .firstProcedure(procedureTagId: "ic-struct-tavr"),
                tier: .silver,
                pointValue: 50
            ),
            Badge(
                id: "first-teer-any",
                title: "First TEER",
                description: "Participated in your first MitraClip/PASCAL procedure",
                iconName: "bolt.heart",
                badgeType: .firstProcedure,
                criteria: .firstProcedure(procedureTagId: "ic-struct-teer"),
                tier: .silver,
                pointValue: 50
            ),
            Badge(
                id: "first-ablation-any",
                title: "First Ablation",
                description: "Participated in your first cardiac ablation",
                iconName: "bolt.fill",
                badgeType: .firstProcedure,
                criteria: .firstProcedureInCategory(category: ProcedureCategory.ablation.rawValue),
                tier: .bronze,
                pointValue: 25
            ),
            Badge(
                id: "first-device-any",
                title: "First Device Implant",
                description: "Participated in your first cardiac device implant",
                iconName: "waveform.badge.plus",
                badgeType: .firstProcedure,
                criteria: .firstProcedureInCategory(category: ProcedureCategory.implants.rawValue),
                tier: .bronze,
                pointValue: 25
            ),
            Badge(
                id: "first-coro-any",
                title: "First Coronary Angio",
                description: "Participated in your first coronary angiogram",
                iconName: "heart.text.square.fill",
                badgeType: .firstProcedure,
                criteria: .firstProcedure(procedureTagId: "ic-dx-coro"),
                tier: .bronze,
                pointValue: 15
            ),
            Badge(
                id: "first-rhc-any",
                title: "First Right Heart Cath",
                description: "Participated in your first right heart catheterization",
                iconName: "arrow.up.heart.fill",
                badgeType: .firstProcedure,
                criteria: .firstProcedure(procedureTagId: "ic-dx-rhc"),
                tier: .bronze,
                pointValue: 15
            ),
            Badge(
                id: "first-peripheral-any",
                title: "First Peripheral Intervention",
                description: "Participated in your first peripheral arterial intervention",
                iconName: "figure.walk",
                badgeType: .firstProcedure,
                criteria: .firstProcedureInCategory(category: ProcedureCategory.peripheralArterial.rawValue),
                tier: .bronze,
                pointValue: 25
            )
        ]
    }

    // MARK: - First as Primary Operator Badges

    static var firstAsPrimaryBadges: [Badge] {
        [
            // Coronary Intervention - Primary
            Badge(
                id: "first-pci-primary",
                title: "First PCI as Primary",
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

            // Structural - TAVR Primary
            Badge(
                id: "first-tavr-primary",
                title: "First TAVR as Primary",
                description: "Performed your first TAVR as primary operator",
                iconName: "bolt.heart.fill",
                badgeType: .firstAsPrimary,
                criteria: .firstAsPrimary(procedureTagId: "ic-struct-tavr"),
                tier: .gold,
                pointValue: 100
            ),

            // Structural - TEER Primary
            Badge(
                id: "first-teer-primary",
                title: "First TEER as Primary",
                description: "Performed your first MitraClip/PASCAL as primary operator",
                iconName: "bolt.heart",
                badgeType: .firstAsPrimary,
                criteria: .firstAsPrimary(procedureTagId: "ic-struct-teer"),
                tier: .gold,
                pointValue: 100
            ),

            // EP - Ablation Primary
            Badge(
                id: "first-ablation-primary",
                title: "First Ablation as Primary",
                description: "Completed your first cardiac ablation as primary operator",
                iconName: "bolt.fill",
                badgeType: .firstAsPrimary,
                criteria: .firstInCategoryAsPrimary(category: ProcedureCategory.ablation.rawValue),
                tier: .silver,
                pointValue: 50
            ),

            // EP - PVI Primary
            Badge(
                id: "first-pvi-primary",
                title: "First PVI as Primary",
                description: "Performed your first Pulmonary Vein Isolation as primary operator",
                iconName: "waveform.path.ecg",
                badgeType: .firstAsPrimary,
                criteria: .firstAsPrimary(procedureTagId: "ep-abl-pvi"),
                tier: .gold,
                pointValue: 75
            ),

            // Device Implant Primary
            Badge(
                id: "first-device-primary",
                title: "First Device as Primary",
                description: "Implanted your first cardiac device as primary operator",
                iconName: "waveform.badge.plus",
                badgeType: .firstAsPrimary,
                criteria: .firstInCategoryAsPrimary(category: ProcedureCategory.implants.rawValue),
                tier: .silver,
                pointValue: 50
            ),

            // Peripheral Primary
            Badge(
                id: "first-peripheral-primary",
                title: "First Peripheral as Primary",
                description: "Completed your first peripheral arterial intervention as primary operator",
                iconName: "figure.walk",
                badgeType: .firstAsPrimary,
                criteria: .firstInCategoryAsPrimary(category: ProcedureCategory.peripheralArterial.rawValue),
                tier: .silver,
                pointValue: 50
            ),

            // MCS - Impella Primary
            Badge(
                id: "first-impella-primary",
                title: "First Impella as Primary",
                description: "Placed your first Impella as primary operator",
                iconName: "heart.circle.fill",
                badgeType: .firstAsPrimary,
                criteria: .firstAsPrimary(procedureTagId: "ic-mcs-impella"),
                tier: .gold,
                pointValue: 75
            ),

            // Diagnostic - Right Heart Cath Primary
            Badge(
                id: "first-rhc-primary",
                title: "First RHC as Primary",
                description: "Performed your first RHC as primary operator",
                iconName: "arrow.up.heart.fill",
                badgeType: .firstAsPrimary,
                criteria: .firstAsPrimary(procedureTagId: "ic-dx-rhc"),
                tier: .bronze,
                pointValue: 25
            ),

            // Diagnostic - Coronary Angio Primary
            Badge(
                id: "first-coro-primary",
                title: "First Angio as Primary",
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

    // MARK: - COCATS Training Level Badges

    /// COCATS (Core Cardiovascular Training Statement) requirement badges
    /// These track progress toward ACGME-defined training levels for cardiology subspecialties
    static var cocatsTrainingBadges: [Badge] {
        var badges: [Badge] = []

        // MARK: Echocardiography (Echo)

        // Level I: 150 TTE
        badges.append(Badge(
            id: "cocats-echo-level1",
            title: "Echo Level I",
            description: "COCATS Level I: 150 TTE studies interpreted",
            iconName: "waveform.path.ecg.rectangle",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagIds: ["ci-echo-tte", "ci-echo-tte-contrast"],
                minimumCount: 150
            ),
            tier: .bronze,
            pointValue: 50
        ))

        // Level II: 300 TTE + 50 TEE + 100 Stress
        badges.append(Badge(
            id: "cocats-echo-level2-tte",
            title: "Echo Level II - TTE",
            description: "COCATS Level II: 300 TTE studies",
            iconName: "waveform.path.ecg.rectangle",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagIds: ["ci-echo-tte", "ci-echo-tte-contrast"],
                minimumCount: 300
            ),
            tier: .silver,
            pointValue: 75
        ))

        badges.append(Badge(
            id: "cocats-echo-level2-tee",
            title: "Echo Level II - TEE",
            description: "COCATS Level II: 50 TEE studies",
            iconName: "waveform.path.ecg.rectangle.fill",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagId: "ci-echo-tee",
                minimumCount: 50
            ),
            tier: .silver,
            pointValue: 75
        ))

        badges.append(Badge(
            id: "cocats-echo-level2-stress",
            title: "Echo Level II - Stress",
            description: "COCATS Level II: 100 stress echos",
            iconName: "heart.circle",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagId: "ci-echo-stress",
                minimumCount: 100
            ),
            tier: .silver,
            pointValue: 75
        ))

        // Level III: 750 TTE, 100 TEE
        badges.append(Badge(
            id: "cocats-echo-level3-tte",
            title: "Echo Level III - TTE",
            description: "COCATS Level III: 750+ TTE studies",
            iconName: "waveform.path.ecg.rectangle",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagIds: ["ci-echo-tte", "ci-echo-tte-contrast"],
                minimumCount: 750
            ),
            tier: .gold,
            pointValue: 150
        ))

        badges.append(Badge(
            id: "cocats-echo-level3-tee",
            title: "Echo Level III - TEE",
            description: "COCATS Level III: 100+ TEE studies",
            iconName: "waveform.path.ecg.rectangle.fill",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagId: "ci-echo-tee",
                minimumCount: 100
            ),
            tier: .gold,
            pointValue: 150
        ))

        // MARK: Nuclear Cardiology

        // Level I: 50 reads
        badges.append(Badge(
            id: "cocats-nuclear-level1",
            title: "Nuclear Level I",
            description: "COCATS Level I: 50 nuclear studies",
            iconName: "atom",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagIds: ["ci-nuc-spect", "ci-nuc-pet", "ci-nuc-mpi"],
                minimumCount: 50
            ),
            tier: .bronze,
            pointValue: 40
        ))

        // Level II: 200 reads
        badges.append(Badge(
            id: "cocats-nuclear-level2",
            title: "Nuclear Level II",
            description: "COCATS Level II: 200 nuclear studies",
            iconName: "atom",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagIds: ["ci-nuc-spect", "ci-nuc-pet", "ci-nuc-mpi"],
                minimumCount: 200
            ),
            tier: .silver,
            pointValue: 75
        ))

        // Level III: 500+ reads
        badges.append(Badge(
            id: "cocats-nuclear-level3",
            title: "Nuclear Level III",
            description: "COCATS Level III: 500+ nuclear studies",
            iconName: "atom",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagIds: ["ci-nuc-spect", "ci-nuc-pet", "ci-nuc-mpi"],
                minimumCount: 500
            ),
            tier: .gold,
            pointValue: 150
        ))

        // MARK: Cardiac CT

        // Level I: 25 cases
        badges.append(Badge(
            id: "cocats-ct-level1",
            title: "Cardiac CT Level I",
            description: "COCATS Level I: 25 cardiac CT studies",
            iconName: "viewfinder.circle",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagIds: ["ci-ct-calcium", "ci-ct-cta", "ci-ct-cardiac"],
                minimumCount: 25
            ),
            tier: .bronze,
            pointValue: 40
        ))

        // Level II: 150 interpreted
        badges.append(Badge(
            id: "cocats-ct-level2",
            title: "Cardiac CT Level II",
            description: "COCATS Level II: 150 cardiac CT interpreted",
            iconName: "viewfinder.circle",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagIds: ["ci-ct-calcium", "ci-ct-cta", "ci-ct-cardiac"],
                minimumCount: 150
            ),
            tier: .silver,
            pointValue: 75
        ))

        // Level III: 300+ interpreted
        badges.append(Badge(
            id: "cocats-ct-level3",
            title: "Cardiac CT Level III",
            description: "COCATS Level III: 300+ cardiac CT interpreted",
            iconName: "viewfinder.circle",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagIds: ["ci-ct-calcium", "ci-ct-cta", "ci-ct-cardiac"],
                minimumCount: 300
            ),
            tier: .gold,
            pointValue: 150
        ))

        // MARK: Cardiac MRI

        // Level I: 25 cases
        badges.append(Badge(
            id: "cocats-mri-level1",
            title: "Cardiac MRI Level I",
            description: "COCATS Level I: 25 cardiac MRI studies",
            iconName: "circle.hexagongrid",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagId: "ci-mri-cardiac",
                minimumCount: 25
            ),
            tier: .bronze,
            pointValue: 40
        ))

        // Level II: 150 interpreted
        badges.append(Badge(
            id: "cocats-mri-level2",
            title: "Cardiac MRI Level II",
            description: "COCATS Level II: 150 cardiac MRI interpreted",
            iconName: "circle.hexagongrid",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagId: "ci-mri-cardiac",
                minimumCount: 150
            ),
            tier: .silver,
            pointValue: 75
        ))

        // Level III: 300+ interpreted
        badges.append(Badge(
            id: "cocats-mri-level3",
            title: "Cardiac MRI Level III",
            description: "COCATS Level III: 300+ cardiac MRI interpreted",
            iconName: "circle.hexagongrid",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagId: "ci-mri-cardiac",
                minimumCount: 300
            ),
            tier: .gold,
            pointValue: 150
        ))

        // MARK: Diagnostic Catheterization

        // Level I: 50 participated
        badges.append(Badge(
            id: "cocats-cath-level1",
            title: "Cath Level I",
            description: "COCATS Level I: 50 diagnostic caths participated",
            iconName: "heart.text.square",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagIds: ["ic-dx-lhc", "ic-dx-rhc", "ic-dx-coro", "ic-dx-lv", "ic-dx-ao"],
                minimumCount: 50
            ),
            tier: .bronze,
            pointValue: 40
        ))

        // Level II: 300 primary
        badges.append(Badge(
            id: "cocats-cath-level2",
            title: "Cath Level II",
            description: "COCATS Level II: 300 diagnostic caths as primary",
            iconName: "heart.text.square.fill",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagIds: ["ic-dx-lhc", "ic-dx-rhc", "ic-dx-coro", "ic-dx-lv", "ic-dx-ao"],
                minimumCount: 300,
                requiresPrimaryOperator: true
            ),
            tier: .silver,
            pointValue: 100
        ))

        // MARK: PCI (Percutaneous Coronary Intervention)

        // Level III: 250 PCI
        badges.append(Badge(
            id: "cocats-pci-level3",
            title: "PCI Level III",
            description: "COCATS Level III: 250+ PCI procedures",
            iconName: "heart.fill",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                procedureTagIds: [
                    "ic-pci-stent", "ic-pci-poba", "ic-pci-dcb",
                    "ic-pci-rotablator", "ic-pci-orbital", "ic-pci-laser",
                    "ic-pci-ivl", "ic-pci-thrombectomy"
                ],
                minimumCount: 250
            ),
            tier: .gold,
            pointValue: 200
        ))

        // MARK: Electrophysiology

        // Level I: 50 exposure
        badges.append(Badge(
            id: "cocats-ep-level1",
            title: "EP Level I",
            description: "COCATS Level I: 50 EP studies exposure",
            iconName: "bolt",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                category: ProcedureCategory.ablation.rawValue,
                minimumCount: 50
            ),
            tier: .bronze,
            pointValue: 40
        ))

        // Level II: 150 studies
        badges.append(Badge(
            id: "cocats-ep-level2",
            title: "EP Level II",
            description: "COCATS Level II: 150 EP studies",
            iconName: "bolt",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                category: ProcedureCategory.ablation.rawValue,
                minimumCount: 150
            ),
            tier: .silver,
            pointValue: 75
        ))

        // Level III: 160+ ablations
        badges.append(Badge(
            id: "cocats-ep-level3",
            title: "EP Level III",
            description: "COCATS Level III: 160+ ablation procedures",
            iconName: "bolt.fill",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                category: ProcedureCategory.ablation.rawValue,
                minimumCount: 160,
                requiresPrimaryOperator: true
            ),
            tier: .gold,
            pointValue: 150
        ))

        // MARK: Vascular Interventions

        // Level II: 100 studies
        badges.append(Badge(
            id: "cocats-vascular-level2",
            title: "Vascular Level II",
            description: "COCATS Level II: 100 vascular studies",
            iconName: "figure.walk",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                category: ProcedureCategory.peripheralArterial.rawValue,
                minimumCount: 100
            ),
            tier: .silver,
            pointValue: 75
        ))

        // Level III: 300+ interventions
        badges.append(Badge(
            id: "cocats-vascular-level3",
            title: "Vascular Level III",
            description: "COCATS Level III: 300+ vascular interventions",
            iconName: "figure.walk",
            badgeType: .cocatsTraining,
            criteria: BadgeCriteria(
                category: ProcedureCategory.peripheralArterial.rawValue,
                minimumCount: 300
            ),
            tier: .gold,
            pointValue: 150
        ))

        return badges
    }

    // MARK: - Helper to Find Badge by ID

    static func badge(withId id: String) -> Badge? {
        allBadges().first { $0.id == id }
    }
}
