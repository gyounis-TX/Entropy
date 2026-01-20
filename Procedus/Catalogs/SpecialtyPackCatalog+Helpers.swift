// SpecialtyPackCatalog+Helpers.swift
// Procedus - Unified
// Helper methods for SpecialtyPackCatalog
// NOTE: Uses PackCategory from your existing SpecialtyPackCatalog

import Foundation

extension SpecialtyPackCatalog {
    
    /// Find the category for a given procedure tag ID
    static func findCategory(for tagId: String) -> ProcedureCategory? {
        for pack in allPacks {
            for packCategory in pack.categories {
                if packCategory.procedures.contains(where: { $0.id == tagId }) {
                    return packCategory.category
                }
            }
        }
        return nil
    }
    
    /// Find a procedure by its tag ID
    static func findProcedure(by tagId: String) -> ProcedureTag? {
        for pack in allPacks {
            for packCategory in pack.categories {
                if let procedure = packCategory.procedures.first(where: { $0.id == tagId }) {
                    return procedure
                }
            }
        }
        return nil
    }
    
    /// Get all procedures in a category across all packs
    static func allProcedures(in category: ProcedureCategory) -> [ProcedureTag] {
        var procedures: [ProcedureTag] = []
        for pack in allPacks {
            for packCategory in pack.categories where packCategory.category == category {
                procedures.append(contentsOf: packCategory.procedures)
            }
        }
        return procedures
    }
}
