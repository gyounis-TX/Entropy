// TextDetectionService.swift
// Procedus - Unified
// On-device text detection for PHI protection using Vision framework

import Foundation
import UIKit
import Vision
import AVFoundation

/// Represents a detected text region in an image
struct DetectedTextRegion: Codable, Identifiable {
    let id: UUID
    let text: String
    let boundingBox: CGRect  // Normalized coordinates (0-1)
    let confidence: Float
    let isHandwritten: Bool

    init(text: String, boundingBox: CGRect, confidence: Float, isHandwritten: Bool = false) {
        self.id = UUID()
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.isHandwritten = isHandwritten
    }

    /// Convert Vision coordinates (origin bottom-left) to UIKit coordinates (origin top-left)
    func boundingBoxInUIKitCoordinates(imageSize: CGSize) -> CGRect {
        CGRect(
            x: boundingBox.origin.x * imageSize.width,
            y: (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )
    }

    /// Check if text is in the top-right corner (PHI label region for diagrams)
    /// Vision uses bottom-left origin, so top-right in UIKit means high Y value (top in Vision coords)
    var isInTopRightCorner: Bool {
        // Top 30% of image and right 40% of image (in Vision coordinates, y is from bottom)
        let topThreshold: CGFloat = 0.7  // Vision y=0.7 means top 30% of image
        let rightThreshold: CGFloat = 0.6  // Vision x=0.6 means right 40% of image
        return boundingBox.origin.y >= topThreshold && boundingBox.origin.x >= rightThreshold
    }
}

/// Result of text detection scan
struct TextDetectionResult {
    let textWasDetected: Bool
    let regions: [DetectedTextRegion]
    let averageConfidence: Double
    let isHandDrawnDiagram: Bool

    var regionsJson: String? {
        guard !regions.isEmpty else { return nil }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(regions) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static let noTextDetected = TextDetectionResult(textWasDetected: false, regions: [], averageConfidence: 0, isHandDrawnDiagram: false)
}

@MainActor
final class TextDetectionService {
    static let shared = TextDetectionService()

    private init() {}

    // MARK: - Allowlist for Medical Terms

    /// Words that are safe to have in medical images (not PHI)
    private let allowlistedWords: Set<String> = [
        // Fluoroscopy markers
        "FOV", "LAO", "RAO", "CAU", "CRA", "AP", "PA", "LL", "RL",

        // Body regions
        "CHEST", "ABDOMEN", "PELVIS", "HEAD", "SPINE", "THORAX",
        "LUMBAR", "CERVICAL", "THORACIC", "SACRAL",

        // Technical terms
        "CT", "MRI", "MPR", "SERIES", "SLICE", "DOSE", "KVP", "MA", "MAS",
        "DLP", "CTDI", "WINDOW", "LEVEL", "SCOUT", "AXIAL", "SAGITTAL", "CORONAL",

        // Directional descriptors
        "LEFT", "RIGHT", "ANTERIOR", "POSTERIOR", "SUPERIOR", "INFERIOR",
        "MEDIAL", "LATERAL", "PROXIMAL", "DISTAL", "L", "R",

        // Practice-specific (can be extended)
        "YOUNIS", "CARDIOLOGY", "ASSOCIATES", "PROCEDUS",

        // Time/Date components (will also use regex)
        "AM", "PM", "DATE", "TIME",

        // Common medical abbreviations
        "PRE", "POST", "IV", "IM", "SC", "PO", "PRN", "STAT",
        "EKG", "ECG", "ECHO", "CATH", "PCI", "CABG", "STEMI", "NSTEMI",
    ]

    /// Patterns that are safe (dates, times, measurements, etc.)
    private let allowlistedPatterns: [NSRegularExpression] = {
        var patterns: [NSRegularExpression] = []

        // Numbers 1-4 digits (measurements, counts)
        if let p = try? NSRegularExpression(pattern: "^\\d{1,4}$") { patterns.append(p) }

        // Dates: various formats
        if let p = try? NSRegularExpression(pattern: "^\\d{1,2}[/\\-]\\d{1,2}[/\\-]\\d{2,4}$") { patterns.append(p) }

        // Times: HH:MM:SS or HH:MM
        if let p = try? NSRegularExpression(pattern: "^\\d{1,2}:\\d{2}(:\\d{2})?$") { patterns.append(p) }

        // Radiation doses: number + mGy or Gy
        if let p = try? NSRegularExpression(pattern: "^\\d+(\\.\\d+)?\\s*(mGy|Gy|mSv|Sv)$", options: .caseInsensitive) { patterns.append(p) }

        // Measurements: number + unit
        if let p = try? NSRegularExpression(pattern: "^\\d+(\\.\\d+)?\\s*(mm|cm|m|in|ml|cc|L|kg|g|lb)$", options: .caseInsensitive) { patterns.append(p) }

        // Frame/slice numbers: "Frame 12", "Slice 45", etc.
        if let p = try? NSRegularExpression(pattern: "^(Frame|Slice|Image|Series)\\s*#?\\d+$", options: .caseInsensitive) { patterns.append(p) }

        // Window/Level values
        if let p = try? NSRegularExpression(pattern: "^(W|L|WW|WL)\\s*:?\\s*\\d+$", options: .caseInsensitive) { patterns.append(p) }

        return patterns
    }()

    // MARK: - Text Detection for Images

    /// Detect text in an image
    /// - Parameters:
    ///   - image: The image to scan
    ///   - isHandDrawnDiagram: If true, only flag text in top-right corner (patient label area)
    /// - Returns: TextDetectionResult with detected regions (excluding allowlisted terms)
    func detectText(in image: UIImage, isHandDrawnDiagram: Bool = false) async -> TextDetectionResult {
        guard let cgImage = image.cgImage else {
            return .noTextDetected
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: .noTextDetected)
                    return
                }

                let (regions, detectedAsDiagram) = self.processObservations(observations, isHandDrawnDiagram: isHandDrawnDiagram)
                let avgConfidence = regions.isEmpty ? 0 : Double(regions.map { $0.confidence }.reduce(0, +)) / Double(regions.count)

                continuation.resume(returning: TextDetectionResult(
                    textWasDetected: !regions.isEmpty,
                    regions: regions,
                    averageConfidence: avgConfidence,
                    isHandDrawnDiagram: detectedAsDiagram
                ))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false  // Faster, we don't need correction

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: .noTextDetected)
            }
        }
    }

    /// Process Vision observations and filter out allowlisted text
    /// - Parameters:
    ///   - observations: Vision text observations
    ///   - isHandDrawnDiagram: If true, only include text in top-right corner
    /// - Returns: Tuple of (filtered regions, whether image appears to be a hand-drawn diagram)
    private func processObservations(_ observations: [VNRecognizedTextObservation], isHandDrawnDiagram: Bool) -> ([DetectedTextRegion], Bool) {
        var allRegions: [DetectedTextRegion] = []
        var handwrittenCount = 0
        var printedCount = 0

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }

            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty or very short text
            guard text.count >= 2 else { continue }

            // Detect if text appears to be handwritten based on confidence and characteristics
            // Handwriting typically has lower confidence (< 0.7) and more variable spacing
            let isHandwritten = isLikelyHandwritten(text: text, confidence: candidate.confidence)

            if isHandwritten {
                handwrittenCount += 1
            } else {
                printedCount += 1
            }

            // Check if text is allowlisted
            if isAllowlisted(text) { continue }

            allRegions.append(DetectedTextRegion(
                text: text,
                boundingBox: observation.boundingBox,
                confidence: candidate.confidence,
                isHandwritten: isHandwritten
            ))
        }

        // Determine if image is a hand-drawn diagram
        // Heuristic: majority of text is handwritten, or user explicitly indicated
        let appearsToBeHandDrawn = isHandDrawnDiagram || (handwrittenCount > printedCount && handwrittenCount >= 3)

        // Filter regions based on diagram detection
        let filteredRegions: [DetectedTextRegion]
        if appearsToBeHandDrawn {
            // For hand-drawn diagrams, only flag text in the top-right corner (patient label area)
            // Handwritten text elsewhere (annotations, labels on diagram) should be excluded
            filteredRegions = allRegions.filter { region in
                // Always flag printed text (could be patient stickers/labels)
                if !region.isHandwritten {
                    return true
                }
                // For handwritten text, only flag if it's in the top-right corner
                return region.isInTopRightCorner
            }
        } else {
            // For regular images, flag all non-allowlisted text
            filteredRegions = allRegions
        }

        return (filteredRegions, appearsToBeHandDrawn)
    }

    /// Determine if text appears to be handwritten
    private func isLikelyHandwritten(text: String, confidence: Float) -> Bool {
        // Handwriting detection heuristics:
        // 1. Lower recognition confidence (Vision struggles with handwriting)
        // 2. Irregular capitalization or mixed case typical of quick notes
        // 3. Short words/abbreviations common in diagram labels

        // Low confidence often indicates handwriting
        if confidence < 0.65 {
            return true
        }

        // Mixed case within words (like "RCa" or "LmAin") suggests handwriting
        let words = text.split(separator: " ")
        for word in words where word.count >= 3 {
            var hasLower = false
            var hasUpper = false
            for (index, char) in word.enumerated() where index > 0 {
                if char.isUppercase { hasUpper = true }
                if char.isLowercase { hasLower = true }
            }
            if hasLower && hasUpper {
                return true
            }
        }

        // Very short text (1-3 chars) at moderate confidence could be handwritten labels
        if text.count <= 3 && confidence < 0.85 {
            return true
        }

        return false
    }

    /// Check if text matches allowlist (safe to keep)
    private func isAllowlisted(_ text: String) -> Bool {
        let normalizedText = text.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check word allowlist
        if allowlistedWords.contains(normalizedText) {
            return true
        }

        // Check pattern allowlist
        let range = NSRange(text.startIndex..., in: text)
        for pattern in allowlistedPatterns {
            if pattern.firstMatch(in: text, options: [], range: range) != nil {
                return true
            }
        }

        // Check if it's purely numeric (safe)
        if text.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }) {
            return true
        }

        return false
    }

    // MARK: - Text Detection for Videos

    /// Detect text in a video by sampling frames
    /// - Parameters:
    ///   - videoURL: URL of the video file
    ///   - sampleCount: Number of frames to sample (default 10)
    /// - Returns: Combined TextDetectionResult from all sampled frames
    func detectText(inVideo videoURL: URL, sampleCount: Int = 10) async -> TextDetectionResult {
        let asset = AVAsset(url: videoURL)

        guard let duration = try? await asset.load(.duration) else {
            return .noTextDetected
        }

        let durationSeconds = duration.seconds
        guard durationSeconds > 0 else { return .noTextDetected }

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero

        var allRegions: [DetectedTextRegion] = []
        var seenTexts: Set<String> = []

        // Sample frames evenly across the video
        for i in 0..<sampleCount {
            let time = CMTime(seconds: durationSeconds * Double(i) / Double(sampleCount), preferredTimescale: 600)

            do {
                let cgImage = try await imageGenerator.image(at: time).image
                let frameImage = UIImage(cgImage: cgImage)
                let result = await detectText(in: frameImage)

                // Add unique text regions (avoid duplicates from similar frames)
                for region in result.regions {
                    let normalizedText = region.text.lowercased()
                    if !seenTexts.contains(normalizedText) {
                        seenTexts.insert(normalizedText)
                        allRegions.append(region)
                    }
                }
            } catch {
                // Skip frames that fail to generate
                continue
            }
        }

        let avgConfidence = allRegions.isEmpty ? 0 : Double(allRegions.map { $0.confidence }.reduce(0, +)) / Double(allRegions.count)

        return TextDetectionResult(
            textWasDetected: !allRegions.isEmpty,
            regions: allRegions,
            averageConfidence: avgConfidence,
            isHandDrawnDiagram: false  // Videos are not hand-drawn diagrams
        )
    }

    // MARK: - Validation

    /// Validate that media file size is within limits
    func validateFileSize(data: Data) -> Bool {
        data.count <= CaseMedia.maxFileSizeBytes
    }

    /// Validate that media file size from URL is within limits
    func validateFileSize(at url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int else {
            return false
        }
        return fileSize <= CaseMedia.maxFileSizeBytes
    }
}
