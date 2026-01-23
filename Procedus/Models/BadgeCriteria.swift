// BadgeCriteria.swift
// Procedus - Unified
// Criteria structure for badge conditions

import Foundation

/// Defines the conditions required to earn a badge
/// Note: Manual JSON encoding/decoding to avoid Swift 6 MainActor isolation issues with Codable
struct BadgeCriteria: Equatable, Sendable {

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

    /// Create criteria for first procedure (any operator role)
    static func firstProcedure(procedureTagId: String) -> BadgeCriteria {
        BadgeCriteria(
            procedureTagId: procedureTagId,
            minimumCount: 1,
            requiresPrimaryOperator: false
        )
    }

    /// Create criteria for first procedure (any operator role, any of multiple procedures)
    static func firstProcedure(anyOf procedureTagIds: [String]) -> BadgeCriteria {
        BadgeCriteria(
            procedureTagIds: procedureTagIds,
            minimumCount: 1,
            requiresPrimaryOperator: false
        )
    }

    /// Create criteria for first procedure in a category (any operator role)
    static func firstProcedureInCategory(category: String) -> BadgeCriteria {
        BadgeCriteria(
            category: category,
            minimumCount: 1,
            requiresPrimaryOperator: false
        )
    }

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

    // MARK: - Manual JSON Encoding/Decoding (Swift 6 compatible)

    /// Decode from JSON string
    static func fromJson(_ json: String) -> BadgeCriteria? {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return BadgeCriteria(
            procedureTagId: dict["procedureTagId"] as? String,
            procedureTagIds: dict["procedureTagIds"] as? [String],
            category: dict["category"] as? String,
            categories: dict["categories"] as? [String],
            minimumCount: dict["minimumCount"] as? Int ?? 1,
            countInterval: dict["countInterval"] as? Int,
            requiresPrimaryOperator: dict["requiresPrimaryOperator"] as? Bool ?? false,
            withinDays: dict["withinDays"] as? Int,
            academicYearOnly: dict["academicYearOnly"] as? Bool ?? false,
            minimumUniqueProcedures: dict["minimumUniqueProcedures"] as? Int
        )
    }

    /// Encode to JSON string
    func toJson() -> String {
        var dict: [String: Any] = [
            "minimumCount": minimumCount,
            "requiresPrimaryOperator": requiresPrimaryOperator,
            "academicYearOnly": academicYearOnly
        ]

        if let procedureTagId = procedureTagId { dict["procedureTagId"] = procedureTagId }
        if let procedureTagIds = procedureTagIds { dict["procedureTagIds"] = procedureTagIds }
        if let category = category { dict["category"] = category }
        if let categories = categories { dict["categories"] = categories }
        if let countInterval = countInterval { dict["countInterval"] = countInterval }
        if let withinDays = withinDays { dict["withinDays"] = withinDays }
        if let minimumUniqueProcedures = minimumUniqueProcedures { dict["minimumUniqueProcedures"] = minimumUniqueProcedures }

        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
