// BadgeCriteria.swift
// Procedus - Unified
// Criteria structure for badge conditions

import Foundation

/// Defines the conditions required to earn a badge
struct BadgeCriteria: Codable, Equatable {

    // MARK: - Procedure Targeting

    /// Specific procedure tag ID (e.g., "ic-pci-stent")
    var procedureTagId: String?

    /// Multiple procedure tag IDs (any of these count)
    var procedureTagIds: [String]?

    // MARK: - Category Targeting

    /// Procedure category raw value (e.g., "Coronary Intervention")
    var category: String?

    /// Multiple categories (any of these count)
    var categories: [String]?

    // MARK: - Count Requirements

    /// Minimum count required to earn the badge
    var minimumCount: Int

    /// For repeating badges (e.g., every 50)
    var countInterval: Int?

    // MARK: - Operator Position Filter

    /// Only count cases where fellow was primary operator
    var requiresPrimaryOperator: Bool

    // MARK: - Time Constraints

    /// Only count cases within this many days
    var withinDays: Int?

    /// Only count cases in current academic year
    var academicYearOnly: Bool

    // MARK: - Special Criteria

    /// For diversity badges: minimum number of unique procedure types
    var minimumUniqueProcedures: Int?

    // MARK: - Initialization

    init(
        procedureTagId: String? = nil,
        procedureTagIds: [String]? = nil,
        category: String? = nil,
        categories: [String]? = nil,
        minimumCount: Int = 1,
        countInterval: Int? = nil,
        requiresPrimaryOperator: Bool = false,
        withinDays: Int? = nil,
        academicYearOnly: Bool = false,
        minimumUniqueProcedures: Int? = nil
    ) {
        self.procedureTagId = procedureTagId
        self.procedureTagIds = procedureTagIds
        self.category = category
        self.categories = categories
        self.minimumCount = minimumCount
        self.countInterval = countInterval
        self.requiresPrimaryOperator = requiresPrimaryOperator
        self.withinDays = withinDays
        self.academicYearOnly = academicYearOnly
        self.minimumUniqueProcedures = minimumUniqueProcedures
    }

    // MARK: - Convenience Initializers

    /// Create criteria for first procedure as primary operator
    static func firstAsPrimary(procedureTagId: String) -> BadgeCriteria {
        BadgeCriteria(
            procedureTagId: procedureTagId,
            minimumCount: 1,
            requiresPrimaryOperator: true
        )
    }

    /// Create criteria for first procedure as primary operator (any of multiple procedures)
    static func firstAsPrimary(anyOf procedureTagIds: [String]) -> BadgeCriteria {
        BadgeCriteria(
            procedureTagIds: procedureTagIds,
            minimumCount: 1,
            requiresPrimaryOperator: true
        )
    }

    /// Create criteria for first procedure in a category as primary operator
    static func firstInCategoryAsPrimary(category: String) -> BadgeCriteria {
        BadgeCriteria(
            category: category,
            minimumCount: 1,
            requiresPrimaryOperator: true
        )
    }

    /// Create criteria for procedure milestone (every N procedures)
    static func milestone(procedureTagId: String, count: Int, interval: Int = 50) -> BadgeCriteria {
        BadgeCriteria(
            procedureTagId: procedureTagId,
            minimumCount: count,
            countInterval: interval
        )
    }

    /// Create criteria for category milestone
    static func categoryMilestone(category: String, count: Int) -> BadgeCriteria {
        BadgeCriteria(
            category: category,
            minimumCount: count
        )
    }

    /// Create criteria for total case count milestone
    static func totalCases(count: Int) -> BadgeCriteria {
        BadgeCriteria(minimumCount: count)
    }

    /// Create criteria for procedure diversity
    static func diversity(uniqueProcedureCount: Int) -> BadgeCriteria {
        BadgeCriteria(
            minimumCount: 1,
            minimumUniqueProcedures: uniqueProcedureCount
        )
    }
}
