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

    init(text: String, boundingBox: CGRect, confidence: Float) {
        self.id = UUID()
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
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
}

/// Result of text detection scan
struct TextDetectionResult {
    let textWasDetected: Bool
    let regions: [DetectedTextRegion]
    let averageConfidence: Double

    var regionsJson: String? {
        guard !regions.isEmpty else { return nil }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(regions) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static let noTextDetected = TextDetectionResult(textWasDetected: false, regions: [], averageConfidence: 0)
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
    /// - Parameter image: The image to scan
    /// - Returns: TextDetectionResult with detected regions (excluding allowlisted terms)
    func detectText(in image: UIImage) async -> TextDetectionResult {
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

                let regions = self.processObservations(observations)
                let avgConfidence = regions.isEmpty ? 0 : Double(regions.map { $0.confidence }.reduce(0, +)) / Double(regions.count)

                continuation.resume(returning: TextDetectionResult(
                    textWasDetected: !regions.isEmpty,
                    regions: regions,
                    averageConfidence: avgConfidence
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
    private func processObservations(_ observations: [VNRecognizedTextObservation]) -> [DetectedTextRegion] {
        var regions: [DetectedTextRegion] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }

            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty or very short text
            guard text.count >= 2 else { continue }

            // Check if text is allowlisted
            if isAllowlisted(text) { continue }

            regions.append(DetectedTextRegion(
                text: text,
                boundingBox: observation.boundingBox,
                confidence: candidate.confidence
            ))
        }

        return regions
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
            averageConfidence: avgConfidence
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
