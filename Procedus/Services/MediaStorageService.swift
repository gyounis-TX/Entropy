// MediaStorageService.swift
// Procedus - Unified
// Local file storage for case media with thumbnail generation

import Foundation
import UIKit
import AVFoundation
import CryptoKit

final class MediaStorageService {
    static let shared = MediaStorageService()

    // MARK: - Constants

    /// Maximum image file size: 10 MB
    static let maxFileSizeBytes = 10 * 1024 * 1024

    /// Maximum video file size: 200 MB
    static let maxVideoFileSizeBytes = 200 * 1024 * 1024

    /// Thumbnail size
    static let thumbnailSize = CGSize(width: 200, height: 200)

    /// JPEG compression quality
    static let imageCompressionQuality: CGFloat = 0.8

    // MARK: - Directory Management

    /// Base directory for all case media
    private var mediaDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("CaseMedia", isDirectory: true)
    }

    /// Thumbnails directory
    private var thumbnailsDirectory: URL {
        mediaDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    private init() {
        createDirectoriesIfNeeded()
    }

    /// Create required directories
    private func createDirectoriesIfNeeded() {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: mediaDirectory.path) {
            try? fileManager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        }

        if !fileManager.fileExists(atPath: thumbnailsDirectory.path) {
            try? fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - File Size Validation

    /// Check if data is within size limit
    func isWithinSizeLimit(_ data: Data) -> Bool {
        data.count <= Self.maxFileSizeBytes
    }

    /// Get formatted file size string
    func formattedFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    // MARK: - Save Image

    /// Save an image for a case entry
    /// - Parameters:
    ///   - image: The UIImage to save
    ///   - caseId: The case entry ID
    /// - Returns: Tuple of (localPath, thumbnailPath, fileSize, width, height, contentHash) or nil on failure
    func saveImage(
        _ image: UIImage,
        forCaseId caseId: UUID
    ) -> (localPath: String, thumbnailPath: String?, fileSize: Int, width: Int, height: Int, contentHash: String)? {
        // Compress image to JPEG
        guard let imageData = image.jpegData(compressionQuality: Self.imageCompressionQuality) else {
            return nil
        }

        // Check size limit
        guard isWithinSizeLimit(imageData) else {
            return nil
        }

        // Create case directory
        let caseDirectory = mediaDirectory.appendingPathComponent(caseId.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: caseDirectory, withIntermediateDirectories: true)

        // Generate unique filename
        let fileName = "\(UUID().uuidString).jpg"
        let filePath = caseDirectory.appendingPathComponent(fileName)

        // Save image
        do {
            try imageData.write(to: filePath)
        } catch {
            print("MediaStorageService: Failed to save image: \(error)")
            return nil
        }

        // Compute hash
        let hash = computeSHA256(data: imageData)

        // Generate thumbnail
        let thumbnailPath = generateThumbnail(from: image, caseId: caseId, originalFileName: fileName)

        // Get dimensions
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)

        // Return relative path from Documents
        let relativePath = "CaseMedia/\(caseId.uuidString)/\(fileName)"
        let relativeThumbnailPath = thumbnailPath.map { "CaseMedia/Thumbnails/\($0)" }

        return (relativePath, relativeThumbnailPath, imageData.count, width, height, hash)
    }

    // MARK: - Save Video

    /// Save a video for a case entry
    /// - Parameters:
    ///   - sourceURL: The source URL of the video
    ///   - caseId: The case entry ID
    /// - Returns: Tuple of media info or nil on failure
    func saveVideo(
        from sourceURL: URL,
        forCaseId caseId: UUID
    ) async -> (localPath: String, thumbnailPath: String?, fileSize: Int, width: Int?, height: Int?, duration: Double?, contentHash: String)? {
        // Get file size from attributes (avoid loading entire video into memory)
        guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
              let fileSize = fileAttributes[.size] as? Int else {
            print("MediaStorageService: Failed to read video file attributes at \(sourceURL.path)")
            return nil
        }

        // Check video size limit (200 MB)
        guard fileSize <= Self.maxVideoFileSizeBytes else {
            print("MediaStorageService: Video exceeds size limit (\(formattedFileSize(fileSize)) > \(formattedFileSize(Self.maxVideoFileSizeBytes)))")
            return nil
        }

        // Create case directory
        let caseDirectory = mediaDirectory.appendingPathComponent(caseId.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: caseDirectory, withIntermediateDirectories: true)

        // Generate unique filename
        let fileExtension = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let filePath = caseDirectory.appendingPathComponent(fileName)

        // Copy video file
        do {
            try FileManager.default.copyItem(at: sourceURL, to: filePath)
        } catch {
            print("MediaStorageService: Failed to save video: \(error)")
            return nil
        }

        // Compute hash from the copied file
        let hash: String
        if let videoData = try? Data(contentsOf: filePath) {
            hash = computeSHA256(data: videoData)
        } else {
            hash = UUID().uuidString // Fallback hash if file read fails
        }

        // Get video metadata off main thread
        let destURL = filePath
        let metadata = await Task.detached(priority: .userInitiated) { () async -> (duration: Double?, width: Int?, height: Int?) in
            let asset = AVAsset(url: destURL)

            // Get duration
            var duration: Double?
            if let durationValue = try? await asset.load(.duration) {
                duration = durationValue.seconds
            }

            // Get dimensions
            var width: Int?
            var height: Int?
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                if let size = try? await track.load(.naturalSize) {
                    let transform = try? await track.load(.preferredTransform)
                    let isPortrait = transform.map { $0.a == 0 && abs($0.b) == 1 } ?? false
                    width = Int(isPortrait ? size.height : size.width)
                    height = Int(isPortrait ? size.width : size.height)
                }
            }

            return (duration, width, height)
        }.value

        // Generate video thumbnail
        let thumbnailFileName = generateVideoThumbnail(from: filePath, caseId: caseId, originalFileName: fileName)

        // Return relative paths
        let relativePath = "CaseMedia/\(caseId.uuidString)/\(fileName)"
        let relativeThumbnailPath = thumbnailFileName.map { "CaseMedia/Thumbnails/\($0)" }

        return (relativePath, relativeThumbnailPath, fileSize, metadata.width, metadata.height, metadata.duration, hash)
    }

    // MARK: - Thumbnail Generation

    /// Generate thumbnail for an image
    private func generateThumbnail(from image: UIImage, caseId: UUID, originalFileName: String) -> String? {
        let thumbnailImage = image.preparingThumbnail(of: Self.thumbnailSize) ?? resizeImage(image, to: Self.thumbnailSize)

        guard let thumbnailData = thumbnailImage?.jpegData(compressionQuality: 0.7) else {
            return nil
        }

        let thumbnailFileName = "thumb_\(caseId.uuidString)_\(originalFileName)"
        let thumbnailPath = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)

        do {
            try thumbnailData.write(to: thumbnailPath)
            return thumbnailFileName
        } catch {
            print("MediaStorageService: Failed to save thumbnail: \(error)")
            return nil
        }
    }

    /// Generate thumbnail for a video
    private func generateVideoThumbnail(from videoURL: URL, caseId: UUID, originalFileName: String) -> String? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = Self.thumbnailSize

        var actualTime = CMTime.zero
        guard let cgImage = try? imageGenerator.copyCGImage(at: .zero, actualTime: &actualTime) else {
            print("MediaStorageService: Failed to generate video thumbnail")
            return nil
        }

        let thumbnail = UIImage(cgImage: cgImage)
        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else {
            return nil
        }

        let baseName = (originalFileName as NSString).deletingPathExtension
        let thumbnailFileName = "thumb_\(caseId.uuidString)_\(baseName).jpg"
        let thumbnailPath = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)

        do {
            try thumbnailData.write(to: thumbnailPath)
            return thumbnailFileName
        } catch {
            print("MediaStorageService: Failed to save video thumbnail: \(error)")
            return nil
        }
    }

    /// Resize image helper
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Hash Computation

    /// Compute SHA256 hash of data
    func computeSHA256(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Load Media

    /// Get the full URL for a relative media path
    func fullURL(for relativePath: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(relativePath)
    }

    /// Load image from relative path
    func loadImage(from relativePath: String) -> UIImage? {
        let url = fullURL(for: relativePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Load thumbnail image
    func loadThumbnail(from relativePath: String?) -> UIImage? {
        guard let path = relativePath else { return nil }
        return loadImage(from: path)
    }

    // MARK: - Delete Media

    /// Delete a media file and its thumbnail
    func deleteMedia(localPath: String, thumbnailPath: String?) {
        let fileManager = FileManager.default

        // Delete main file
        let mainURL = fullURL(for: localPath)
        try? fileManager.removeItem(at: mainURL)

        // Delete thumbnail if exists
        if let thumbPath = thumbnailPath {
            let thumbURL = fullURL(for: thumbPath)
            try? fileManager.removeItem(at: thumbURL)
        }

        // Try to clean up empty case directory
        let caseDirectory = mainURL.deletingLastPathComponent()
        let contents = try? fileManager.contentsOfDirectory(atPath: caseDirectory.path)
        if contents?.isEmpty == true {
            try? fileManager.removeItem(at: caseDirectory)
        }
    }

    /// Delete all media for a case
    func deleteAllMedia(forCaseId caseId: UUID) {
        let caseDirectory = mediaDirectory.appendingPathComponent(caseId.uuidString)
        try? FileManager.default.removeItem(at: caseDirectory)

        // Also clean up thumbnails for this case
        let fileManager = FileManager.default
        if let thumbnails = try? fileManager.contentsOfDirectory(atPath: thumbnailsDirectory.path) {
            for thumbnail in thumbnails where thumbnail.contains(caseId.uuidString) {
                let thumbnailPath = thumbnailsDirectory.appendingPathComponent(thumbnail)
                try? fileManager.removeItem(at: thumbnailPath)
            }
        }
    }

    // MARK: - Storage Info

    /// Get total storage used by case media
    func totalStorageUsed() -> Int {
        var totalSize = 0
        let fileManager = FileManager.default

        if let enumerator = fileManager.enumerator(at: mediaDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            while let fileURL = enumerator.nextObject() as? URL {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += fileSize
                }
            }
        }

        return totalSize
    }

    /// Get count of media files
    func mediaCount() -> Int {
        var count = 0
        let fileManager = FileManager.default

        if let enumerator = fileManager.enumerator(at: mediaDirectory, includingPropertiesForKeys: nil) {
            while let fileURL = enumerator.nextObject() as? URL {
                // Skip thumbnails directory
                if fileURL.path.contains("/Thumbnails/") { continue }
                // Count only files, not directories
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                    count += 1
                }
            }
        }

        return count
    }
}
