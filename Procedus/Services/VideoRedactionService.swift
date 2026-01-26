// VideoRedactionService.swift
// Procedus - Unified
// Apply static redaction regions to videos using AVFoundation

import Foundation
import AVFoundation
import UIKit
import CoreImage

/// Represents a redaction region on video (normalized 0-1 coordinates)
struct VideoRedactionRegion: Codable, Identifiable {
    let id: UUID
    var rect: CGRect  // Normalized coordinates (0-1)

    init(rect: CGRect) {
        self.id = UUID()
        self.rect = rect
    }

    /// Convert to pixel coordinates for a given video size
    func pixelRect(for videoSize: CGSize) -> CGRect {
        CGRect(
            x: rect.origin.x * videoSize.width,
            y: rect.origin.y * videoSize.height,
            width: rect.width * videoSize.width,
            height: rect.height * videoSize.height
        )
    }
}

/// Result of video redaction export
struct VideoRedactionResult {
    let success: Bool
    let outputURL: URL?
    let error: String?

    static func failure(_ error: String) -> VideoRedactionResult {
        VideoRedactionResult(success: false, outputURL: nil, error: error)
    }

    static func success(_ url: URL) -> VideoRedactionResult {
        VideoRedactionResult(success: true, outputURL: url, error: nil)
    }
}

final class VideoRedactionService {
    static let shared = VideoRedactionService()

    private init() {}

    // MARK: - Get Video Thumbnail

    /// Get a thumbnail from the video at specified time
    func getThumbnail(from videoURL: URL, at time: CMTime = .zero) async -> UIImage? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero

        var actualTime = CMTime.zero
        guard let cgImage = try? imageGenerator.copyCGImage(at: time, actualTime: &actualTime) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// Get video dimensions
    func getVideoDimensions(from videoURL: URL) async -> CGSize? {
        let asset = AVAsset(url: videoURL)

        guard let track = try? await asset.loadTracks(withMediaType: .video).first else {
            return nil
        }

        let size = try? await track.load(.naturalSize)
        let transform = try? await track.load(.preferredTransform)

        guard let size = size, let transform = transform else {
            return nil
        }

        // Account for video orientation
        let isPortrait = transform.a == 0 && abs(transform.b) == 1
        if isPortrait {
            return CGSize(width: size.height, height: size.width)
        }
        return size
    }

    /// Get video duration
    func getVideoDuration(from videoURL: URL) async -> Double? {
        let asset = AVAsset(url: videoURL)
        guard let duration = try? await asset.load(.duration) else {
            return nil
        }
        return duration.seconds
    }

    // MARK: - Apply Redaction

    /// Apply redaction regions to video and export
    /// - Parameters:
    ///   - videoURL: Source video URL
    ///   - regions: Redaction regions (normalized coordinates)
    ///   - progress: Progress callback (0.0 to 1.0)
    /// - Returns: VideoRedactionResult with output URL on success
    func applyRedaction(
        to videoURL: URL,
        regions: [VideoRedactionRegion],
        progress: ((Float) -> Void)? = nil
    ) async -> VideoRedactionResult {
        guard !regions.isEmpty else {
            return .failure("No redaction regions specified")
        }

        let asset = AVAsset(url: videoURL)

        // Get video track
        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
            return .failure("Could not load video track")
        }

        // Get video properties
        guard let naturalSize = try? await videoTrack.load(.naturalSize),
              let transform = try? await videoTrack.load(.preferredTransform),
              let duration = try? await asset.load(.duration) else {
            return .failure("Could not load video properties")
        }

        // Calculate actual video size accounting for orientation
        let isPortrait = transform.a == 0 && abs(transform.b) == 1
        let videoSize = isPortrait ? CGSize(width: naturalSize.height, height: naturalSize.width) : naturalSize

        // Create composition
        let composition = AVMutableComposition()

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return .failure("Could not create composition video track")
        }

        // Add audio track if present
        if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first {
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            try? compositionAudioTrack?.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: audioTrack,
                at: .zero
            )
        }

        // Insert video track
        do {
            try compositionVideoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: videoTrack,
                at: .zero
            )
        } catch {
            return .failure("Could not insert video track: \(error.localizedDescription)")
        }

        // Apply original transform
        compositionVideoTrack.preferredTransform = transform

        // Capture regions for the closure (normalized 0-1 coordinates)
        let capturedRegions = regions

        // Create video composition using CIImage compositing (thread-safe, no CALayer needed)
        let videoComposition = AVMutableVideoComposition(asset: composition) { request in
            let sourceImage = request.sourceImage
            let extent = sourceImage.extent
            var output = sourceImage.clampedToExtent()

            for region in capturedRegions {
                // Convert normalized rect to CIImage pixel coordinates
                // CIImage uses bottom-left origin; regions use top-left origin (UIKit)
                let ciRect = CGRect(
                    x: extent.origin.x + region.rect.origin.x * extent.width,
                    y: extent.origin.y + (1.0 - region.rect.origin.y - region.rect.height) * extent.height,
                    width: region.rect.width * extent.width,
                    height: region.rect.height * extent.height
                )
                let blackRect = CIImage(color: .black).cropped(to: ciRect)
                output = blackRect.composited(over: output)
            }

            request.finish(with: output.cropped(to: extent), context: nil)
        }

        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        // Create output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("redacted_\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        // Export
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            return .failure("Could not create export session")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true

        // Monitor progress
        let progressTask = Task {
            while !Task.isCancelled && exportSession.status == .exporting {
                progress?(exportSession.progress)
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }

        // Perform export
        await exportSession.export()
        progressTask.cancel()

        switch exportSession.status {
        case .completed:
            progress?(1.0)
            return .success(outputURL)
        case .failed:
            return .failure(exportSession.error?.localizedDescription ?? "Export failed")
        case .cancelled:
            return .failure("Export was cancelled")
        default:
            return .failure("Unknown export status")
        }
    }

    // MARK: - Preview

    /// Generate a preview image with redaction applied
    func generatePreviewImage(
        from videoURL: URL,
        regions: [VideoRedactionRegion],
        at time: CMTime = .zero
    ) async -> UIImage? {
        guard let thumbnail = await getThumbnail(from: videoURL, at: time) else {
            return nil
        }

        guard let videoSize = await getVideoDimensions(from: videoURL) else {
            return thumbnail
        }

        // Draw redaction on thumbnail
        let renderer = UIGraphicsImageRenderer(size: thumbnail.size)
        return renderer.image { context in
            thumbnail.draw(at: .zero)

            // Scale factor from video to thumbnail
            let scaleX = thumbnail.size.width / videoSize.width
            let scaleY = thumbnail.size.height / videoSize.height

            context.cgContext.setFillColor(UIColor.black.cgColor)

            for region in regions {
                let pixelRect = region.pixelRect(for: videoSize)
                let scaledRect = CGRect(
                    x: pixelRect.origin.x * scaleX,
                    y: pixelRect.origin.y * scaleY,
                    width: pixelRect.width * scaleX,
                    height: pixelRect.height * scaleY
                )
                context.cgContext.fill(scaledRect)
            }
        }
    }
}
