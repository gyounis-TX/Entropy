// SearchTermService.swift
// Procedus - Unified
// Track and suggest search terms for media labels

import Foundation
import SwiftData

@MainActor
final class SearchTermService {
    static let shared = SearchTermService()

    private var modelContext: ModelContext?

    private init() {}

    // MARK: - Configuration

    func configure(with context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Track Usage

    /// Record usage of search terms when media is saved
    /// - Parameter terms: Array of search terms used
    func recordTermUsage(_ terms: [String]) {
        guard let context = modelContext else { return }

        for term in terms {
            let normalizedTerm = term.lowercased().trimmingCharacters(in: .whitespaces)
            guard !normalizedTerm.isEmpty else { continue }

            // Try to find existing term
            let descriptor = FetchDescriptor<SearchTermSuggestion>(
                predicate: #Predicate { $0.term == normalizedTerm }
            )

            do {
                let existing = try context.fetch(descriptor).first

                if let suggestion = existing {
                    // Update existing
                    suggestion.recordUsage()
                } else {
                    // Create new - initializer sets displayText from the original term
                    let suggestion = SearchTermSuggestion(term: term)
                    context.insert(suggestion)
                }

                try context.save()
            } catch {
                print("SearchTermService: Failed to record term usage: \(error)")
            }
        }
    }

    // MARK: - Get Suggestions

    /// Get suggested terms based on a prefix
    /// - Parameters:
    ///   - prefix: The prefix to match
    ///   - limit: Maximum number of suggestions to return
    /// - Returns: Array of suggested terms
    func getSuggestions(for prefix: String, limit: Int = 10) -> [String] {
        guard let context = modelContext else { return [] }

        let normalizedPrefix = prefix.lowercased().trimmingCharacters(in: .whitespaces)

        // If empty prefix, return most popular terms
        if normalizedPrefix.isEmpty {
            return getPopularTerms(limit: limit)
        }

        // Fetch all suggestions and filter (SwiftData predicate limitations)
        let descriptor = FetchDescriptor<SearchTermSuggestion>(
            sortBy: [SortDescriptor(\.usageCount, order: .reverse)]
        )

        do {
            let allSuggestions = try context.fetch(descriptor)
            return allSuggestions
                .filter { $0.term.hasPrefix(normalizedPrefix) || $0.displayText.lowercased().hasPrefix(normalizedPrefix) }
                .prefix(limit)
                .map { $0.displayText }
        } catch {
            print("SearchTermService: Failed to get suggestions: \(error)")
            return []
        }
    }

    /// Get the most popular terms overall
    /// - Parameter limit: Maximum number of terms to return
    /// - Returns: Array of popular terms
    func getPopularTerms(limit: Int = 10) -> [String] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<SearchTermSuggestion>(
            sortBy: [SortDescriptor(\.usageCount, order: .reverse)]
        )

        do {
            let suggestions = try context.fetch(descriptor)
            return Array(suggestions.prefix(limit).map { $0.displayText })
        } catch {
            print("SearchTermService: Failed to get popular terms: \(error)")
            return []
        }
    }

    /// Get recently used terms
    /// - Parameter limit: Maximum number of terms to return
    /// - Returns: Array of recently used terms
    func getRecentTerms(limit: Int = 10) -> [String] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<SearchTermSuggestion>(
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )

        do {
            let suggestions = try context.fetch(descriptor)
            return Array(suggestions.prefix(limit).map { $0.displayText })
        } catch {
            print("SearchTermService: Failed to get recent terms: \(error)")
            return []
        }
    }

    // MARK: - Predefined Suggestions

    /// Common medical imaging labels for initial suggestions
    static let commonLabels: [String] = [
        // Anatomy
        "LAD", "LCX", "RCA", "LM", "LMCA",
        "Aortic Valve", "Mitral Valve", "Tricuspid Valve",
        "Left Ventricle", "Right Ventricle", "Atrium",

        // Findings
        "Stenosis", "Occlusion", "Thrombus", "Dissection",
        "Calcification", "Aneurysm", "Plaque", "Lesion",
        "Bifurcation", "Ostial", "Diffuse Disease",

        // Procedures
        "Pre-PCI", "Post-PCI", "Pre-Stent", "Post-Stent",
        "IVUS", "OCT", "FFR", "Angiogram",
        "Balloon Inflation", "Wire Crossing",

        // Devices
        "DES", "BMS", "Drug-Eluting Stent", "Bare Metal Stent",
        "TAVR", "MitraClip", "Impella", "IABP",
        "Pacemaker", "ICD", "CRT",

        // Quality
        "Teaching Case", "Interesting", "Rare Finding",
        "Complication", "Successful", "Challenging"
    ]

    /// Get combined suggestions: user's recent + popular + predefined
    func getCombinedSuggestions(for prefix: String, limit: Int = 15) -> [String] {
        var results: [String] = []
        var seen = Set<String>()

        // Add user's suggestions first
        let userSuggestions = getSuggestions(for: prefix, limit: limit)
        for term in userSuggestions {
            let lower = term.lowercased()
            if !seen.contains(lower) {
                results.append(term)
                seen.insert(lower)
            }
        }

        // Add predefined suggestions that match
        let normalizedPrefix = prefix.lowercased()
        for term in Self.commonLabels {
            if results.count >= limit { break }
            let lower = term.lowercased()
            if !seen.contains(lower) && (normalizedPrefix.isEmpty || lower.contains(normalizedPrefix)) {
                results.append(term)
                seen.insert(lower)
            }
        }

        return Array(results.prefix(limit))
    }
}
