// RedactionService.swift
// Procedus - Unified
// Apply solid black rectangles over detected PHI text regions

import Foundation
import UIKit

@MainActor
final class RedactionService {
    static let shared = RedactionService()

    private init() {}

    // MARK: - Redaction

    /// Apply redaction to an image by covering text regions with solid black rectangles
    /// - Parameters:
    ///   - image: The original image
    ///   - regions: Detected text regions to redact (with normalized coordinates)
    ///   - padding: Extra padding around each region (in points, scaled to image size)
    /// - Returns: New image with redactions applied, or nil on failure
    func applyRedaction(
        to image: UIImage,
        regions: [DetectedTextRegion],
        padding: CGFloat = 4
    ) -> UIImage? {
        guard !regions.isEmpty else { return image }

        let imageSize = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )

        // Calculate padding relative to image size
        let scaledPadding = padding * image.scale

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)

        return renderer.image { context in
            // Draw original image
            image.draw(at: .zero)

            // Draw black rectangles over each region
            UIColor.black.setFill()

            for region in regions {
                // Convert normalized Vision coordinates to UIKit coordinates
                let rect = convertToUIKitRect(
                    normalizedRect: region.boundingBox,
                    imageSize: imageSize,
                    padding: scaledPadding
                )

                // Scale rect back to renderer coordinates (not pixel coordinates)
                let scaledRect = CGRect(
                    x: rect.origin.x / image.scale,
                    y: rect.origin.y / image.scale,
                    width: rect.width / image.scale,
                    height: rect.height / image.scale
                )

                context.fill(scaledRect)
            }
        }
    }

    /// Apply redaction to specific regions only (for selective redaction)
    /// - Parameters:
    ///   - image: The original image
    ///   - regionIds: Set of region IDs to redact
    ///   - allRegions: All detected regions
    /// - Returns: New image with selected redactions applied
    func applySelectiveRedaction(
        to image: UIImage,
        regionIds: Set<UUID>,
        allRegions: [DetectedTextRegion]
    ) -> UIImage? {
        let regionsToRedact = allRegions.filter { regionIds.contains($0.id) }
        return applyRedaction(to: image, regions: regionsToRedact)
    }

    // MARK: - Manual Redaction

    /// Apply manual redaction from user-drawn rectangles (normalized coordinates, origin top-left)
    /// - Parameters:
    ///   - image: The original image
    ///   - rects: Array of normalized rectangles (0-1 range, UIKit coordinate system)
    /// - Returns: New image with redactions applied
    func applyManualRedaction(to image: UIImage, rects: [CGRect]) -> UIImage? {
        guard !rects.isEmpty else { return image }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)

        return renderer.image { context in
            // Draw original image
            image.draw(at: .zero)

            // Draw black rectangles over each region
            UIColor.black.setFill()

            for rect in rects {
                // Convert normalized rect to image coordinates
                let imageRect = CGRect(
                    x: rect.origin.x * image.size.width,
                    y: rect.origin.y * image.size.height,
                    width: rect.width * image.size.width,
                    height: rect.height * image.size.height
                )
                context.fill(imageRect)
            }
        }
    }

    // MARK: - Coordinate Conversion

    /// Convert Vision normalized rect (origin bottom-left) to UIKit coordinates (origin top-left)
    private func convertToUIKitRect(
        normalizedRect: CGRect,
        imageSize: CGSize,
        padding: CGFloat
    ) -> CGRect {
        // Vision coordinates: origin at bottom-left, Y increases upward
        // UIKit coordinates: origin at top-left, Y increases downward

        let x = normalizedRect.origin.x * imageSize.width - padding
        let y = (1 - normalizedRect.origin.y - normalizedRect.height) * imageSize.height - padding
        let width = normalizedRect.width * imageSize.width + (padding * 2)
        let height = normalizedRect.height * imageSize.height + (padding * 2)

        // Clamp to image bounds
        return CGRect(
            x: max(0, x),
            y: max(0, y),
            width: min(width, imageSize.width - x),
            height: min(height, imageSize.height - y)
        )
    }

    // MARK: - Preview Drawing

    /// Draw preview rectangles on image showing detected text regions
    /// - Parameters:
    ///   - image: The original image
    ///   - regions: Detected text regions to highlight
    ///   - color: Color for the highlight boxes (default red)
    ///   - lineWidth: Width of the border lines
    /// - Returns: New image with highlighted regions
    func drawPreviewHighlights(
        on image: UIImage,
        regions: [DetectedTextRegion],
        color: UIColor = .red,
        lineWidth: CGFloat = 3
    ) -> UIImage? {
        guard !regions.isEmpty else { return image }

        let imageSize = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)

        return renderer.image { context in
            // Draw original image
            image.draw(at: .zero)

            // Set stroke properties
            color.setStroke()
            context.cgContext.setLineWidth(lineWidth / image.scale)

            for region in regions {
                let rect = convertToUIKitRect(
                    normalizedRect: region.boundingBox,
                    imageSize: imageSize,
                    padding: 2
                )

                // Scale rect to renderer coordinates
                let scaledRect = CGRect(
                    x: rect.origin.x / image.scale,
                    y: rect.origin.y / image.scale,
                    width: rect.width / image.scale,
                    height: rect.height / image.scale
                )

                // Draw border
                context.stroke(scaledRect)

                // Add semi-transparent fill
                color.withAlphaComponent(0.15).setFill()
                context.fill(scaledRect)
            }
        }
    }

    // MARK: - Redacted Regions JSON

    /// Encode redacted regions to JSON for storage
    func encodeRedactedRegions(_ regions: [DetectedTextRegion]) -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(regions) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Decode redacted regions from JSON
    func decodeRedactedRegions(_ json: String?) -> [DetectedTextRegion] {
        guard let json = json,
              let data = json.data(using: .utf8) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([DetectedTextRegion].self, from: data)) ?? []
    }
}
