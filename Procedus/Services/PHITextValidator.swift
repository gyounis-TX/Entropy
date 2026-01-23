// PHITextValidator.swift
// Procedus - Unified
// Validates free text fields for potential PHI content

import Foundation

/// Result of PHI validation
struct PHIValidationResult {
    let containsPotentialPHI: Bool
    let detectedPatterns: [PHIPattern]
    let warningMessage: String?

    static let clean = PHIValidationResult(containsPotentialPHI: false, detectedPatterns: [], warningMessage: nil)
}

/// Types of PHI patterns that can be detected
enum PHIPatternType: String, CaseIterable {
    case ssn = "Social Security Number"
    case mrn = "Medical Record Number"
    case phoneNumber = "Phone Number"
    case email = "Email Address"
    case dateOfBirth = "Date of Birth"
    case address = "Street Address"
    case patientName = "Possible Patient Name"
}

/// A detected PHI pattern
struct PHIPattern {
    let type: PHIPatternType
    let matchedText: String
    let range: Range<String.Index>
}

/// Validates text for potential PHI content
@MainActor
final class PHITextValidator {
    static let shared = PHITextValidator()

    private init() {}

    // MARK: - PHI Detection Patterns

    /// Regex patterns for various PHI types
    private lazy var patterns: [(PHIPatternType, NSRegularExpression)] = {
        var result: [(PHIPatternType, NSRegularExpression)] = []

        // Social Security Number: XXX-XX-XXXX or XXXXXXXXX
        if let p = try? NSRegularExpression(pattern: "\\b\\d{3}[\\s-]?\\d{2}[\\s-]?\\d{4}\\b") {
            result.append((.ssn, p))
        }

        // Medical Record Number: common patterns (MRN: followed by digits, or 6+ digit numbers with potential prefix)
        if let p = try? NSRegularExpression(pattern: "\\b(MRN|MR#?|Patient\\s*#?)\\s*:?\\s*\\d{4,}\\b", options: .caseInsensitive) {
            result.append((.mrn, p))
        }

        // Phone Number: various US formats
        if let p = try? NSRegularExpression(pattern: "\\b(\\+1[\\s-]?)?(\\(?\\d{3}\\)?[\\s.-]?)\\d{3}[\\s.-]?\\d{4}\\b") {
            result.append((.phoneNumber, p))
        }

        // Email Address
        if let p = try? NSRegularExpression(pattern: "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b") {
            result.append((.email, p))
        }

        // Date of Birth: DOB: followed by date, or "born on", "birth date"
        if let p = try? NSRegularExpression(pattern: "\\b(DOB|D\\.O\\.B|Date\\s+of\\s+Birth|Birth\\s*date|Born\\s+on)\\s*:?\\s*\\d{1,2}[/\\-]\\d{1,2}[/\\-]\\d{2,4}\\b", options: .caseInsensitive) {
            result.append((.dateOfBirth, p))
        }

        // Street Address: number followed by street name and common suffixes
        if let p = try? NSRegularExpression(pattern: "\\b\\d+\\s+[A-Za-z]+\\s+(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Court|Ct|Circle|Cir|Way|Place|Pl)\\b", options: .caseInsensitive) {
            result.append((.address, p))
        }

        return result
    }()

    /// Common medical terms that should NOT trigger PHI warnings (false positive prevention)
    private let allowlistedTerms: Set<String> = [
        // Medical procedure terms
        "patient", "mr", "mrs", "dr", "procedure", "case", "admission",
        // Anatomy
        "left", "right", "anterior", "posterior", "superior", "inferior",
        // Common medical abbreviations
        "lad", "lcx", "rca", "lm", "pci", "cabg", "stemi", "nstemi",
        // Descriptors
        "successful", "complicated", "routine", "emergent", "elective",
        // Outcomes
        "discharged", "transferred", "admitted", "stable", "critical",
    ]

    /// Name prefixes/suffixes that suggest PHI
    private let nameIndicators: Set<String> = [
        "mr.", "mrs.", "ms.", "miss", "dr.", "patient name:", "pt:",
        "patient:", "name:", "full name:"
    ]

    // MARK: - Validation

    /// Validate text for potential PHI
    /// - Parameter text: The text to validate
    /// - Returns: PHIValidationResult indicating if PHI was detected
    func validate(_ text: String) -> PHIValidationResult {
        guard !text.isEmpty else { return .clean }

        var detectedPatterns: [PHIPattern] = []

        // Check regex patterns
        let range = NSRange(text.startIndex..., in: text)
        for (patternType, regex) in patterns {
            let matches = regex.matches(in: text, options: [], range: range)
            for match in matches {
                if let swiftRange = Range(match.range, in: text) {
                    let matchedText = String(text[swiftRange])

                    // Skip if it matches an allowlisted term
                    if !isAllowlisted(matchedText) {
                        detectedPatterns.append(PHIPattern(
                            type: patternType,
                            matchedText: matchedText,
                            range: swiftRange
                        ))
                    }
                }
            }
        }

        // Check for potential patient names (words following name indicators)
        detectedPatterns.append(contentsOf: detectPotentialNames(in: text))

        if detectedPatterns.isEmpty {
            return .clean
        }

        // Generate warning message
        let uniqueTypes = Set(detectedPatterns.map { $0.type })
        let typeNames = uniqueTypes.map { $0.rawValue }.joined(separator: ", ")
        let warningMessage = "Potential PHI detected: \(typeNames). Please remove before saving."

        return PHIValidationResult(
            containsPotentialPHI: true,
            detectedPatterns: detectedPatterns,
            warningMessage: warningMessage
        )
    }

    /// Quick check if text might contain PHI (faster than full validation)
    func mightContainPHI(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }

        let lowercased = text.lowercased()

        // Quick checks for common PHI indicators
        // SSN pattern
        if text.range(of: "\\d{3}-\\d{2}-\\d{4}", options: .regularExpression) != nil {
            return true
        }

        // Phone pattern
        if text.range(of: "\\(\\d{3}\\)\\s*\\d{3}-\\d{4}", options: .regularExpression) != nil {
            return true
        }

        // Email
        if text.contains("@") && text.contains(".") {
            return true
        }

        // Name indicators
        for indicator in nameIndicators {
            if lowercased.contains(indicator) {
                return true
            }
        }

        // MRN indicator
        if lowercased.contains("mrn") || lowercased.contains("mr#") {
            return true
        }

        // DOB indicator
        if lowercased.contains("dob") || lowercased.contains("date of birth") {
            return true
        }

        return false
    }

    // MARK: - Helpers

    private func isAllowlisted(_ text: String) -> Bool {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return allowlistedTerms.contains(normalized)
    }

    private func detectPotentialNames(in text: String) -> [PHIPattern] {
        var results: [PHIPattern] = []
        let lowercased = text.lowercased()

        for indicator in nameIndicators {
            if let indicatorRange = lowercased.range(of: indicator) {
                // Get text after the indicator
                let afterIndicator = text[indicatorRange.upperBound...]

                // Look for capitalized words (potential names)
                if let nameMatch = afterIndicator.range(of: "\\s*[A-Z][a-z]+\\s+[A-Z][a-z]+", options: .regularExpression) {
                    let matchedText = String(afterIndicator[nameMatch]).trimmingCharacters(in: .whitespaces)
                    if !isAllowlisted(matchedText) {
                        results.append(PHIPattern(
                            type: .patientName,
                            matchedText: matchedText,
                            range: nameMatch
                        ))
                    }
                }
            }
        }

        return results
    }
}

// MARK: - SwiftUI View Modifier for PHI Validation

import SwiftUI

/// A view modifier that adds PHI validation to text fields
struct PHIValidatedTextFieldModifier: ViewModifier {
    @Binding var text: String
    @State private var showingWarning = false
    @State private var warningMessage: String?

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content
                .onChange(of: text) { _, newValue in
                    let result = PHITextValidator.shared.validate(newValue)
                    if result.containsPotentialPHI {
                        warningMessage = result.warningMessage
                        showingWarning = true
                    } else {
                        showingWarning = false
                        warningMessage = nil
                    }
                }

            if showingWarning, let message = warningMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(message)
                        .font(.caption2)
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 4)
            }
        }
    }
}

extension View {
    /// Add PHI validation to a text input view
    func phiValidated(text: Binding<String>) -> some View {
        self.modifier(PHIValidatedTextFieldModifier(text: text))
    }
}

// MARK: - PHI Warning Banner

struct PHIWarningBanner: View {
    let message: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(message)
                .font(.caption)
                .foregroundColor(.primary)

            Spacer()

            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(8)
    }
}
