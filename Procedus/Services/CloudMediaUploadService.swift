// CloudMediaUploadService.swift
// Procedus - Unified
// Firebase Storage uploader for CaseMedia with retry and network awareness

import Foundation
import FirebaseAuth
import FirebaseStorage

// MARK: - Upload Errors

enum MediaUploadError: LocalizedError {
    case networkUnavailable(reason: String)
    case uploadFailed(underlyingError: Error, attempts: Int)
    case authenticationFailed(underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable(let reason):
            return "Upload unavailable: \(reason)"
        case .uploadFailed(let error, let attempts):
            return "Upload failed after \(attempts) attempt\(attempts == 1 ? "" : "s"): \(error.localizedDescription)"
        case .authenticationFailed(let error):
            return "Authentication failed: \(error.localizedDescription)"
        }
    }
}

actor CloudMediaUploadService {
    static let shared = CloudMediaUploadService()

    private init() {}

    /// Returns the current Firebase Auth uid, signing in anonymously if needed.
    func authUid() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid {
            return uid
        }

        // Anonymous sign-in (minimal setup so Storage rules can require auth).
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            Auth.auth().signInAnonymously { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let uid = result?.user.uid else {
                    continuation.resume(throwing: NSError(domain: "CloudMediaUploadService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Anonymous sign-in returned no user"]))
                    return
                }
                continuation.resume(returning: uid)
            }
        }
    }

    func uploadLocalDocumentsFile(
        relativeLocalPath: String,
        to cloudPath: String,
        contentType: String
    ) async throws {
        // Ensure we have an authenticated user before any Storage operations.
        _ = try await authUid()

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docs.appendingPathComponent(relativeLocalPath)

        let ref = Storage.storage().reference(withPath: cloudPath)
        let metadata = StorageMetadata()
        metadata.contentType = contentType

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.putFile(from: fileURL, metadata: metadata) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// Upload with network pre-check and exponential-backoff retry.
    func uploadWithRetry(
        relativeLocalPath: String,
        to cloudPath: String,
        contentType: String,
        maxAttempts: Int = 3
    ) async throws {
        // Soft network pre-check (warn but don't block — monitor may not have
        // received its first path update yet on app launch).
        let canUpload = await MainActor.run { NetworkMonitorService.shared.canUploadMedia() }
        if !canUpload {
            let reason = await MainActor.run { NetworkMonitorService.shared.uploadBlockedReason() ?? "Unknown" }
            print("[MediaUpload] Network pre-check: \(reason) — will attempt upload anyway")
        }

        // Authenticate before upload attempts
        do {
            _ = try await authUid()
        } catch {
            throw MediaUploadError.authenticationFailed(underlyingError: error)
        }

        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                try await uploadLocalDocumentsFile(
                    relativeLocalPath: relativeLocalPath,
                    to: cloudPath,
                    contentType: contentType
                )
                return // success
            } catch {
                lastError = error
                print("[MediaUpload] Attempt \(attempt)/\(maxAttempts) failed: \(error.localizedDescription)")
                if attempt < maxAttempts {
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000 // 2s, 4s
                    try await Task.sleep(nanoseconds: delay)
                }
            }
        }

        throw MediaUploadError.uploadFailed(
            underlyingError: lastError!,
            attempts: maxAttempts
        )
    }
}
