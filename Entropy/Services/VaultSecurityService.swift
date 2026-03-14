import Foundation
import LocalAuthentication
import Security

/// Manages biometric authentication and secure storage for the Personal Vault.
final class VaultSecurityService {
    static let shared = VaultSecurityService()

    private let context = LAContext()

    private init() {}

    // MARK: - Biometric Authentication

    enum BiometricType {
        case faceID, touchID, none
    }

    var availableBiometric: BiometricType {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .none
        }
    }

    var biometricName: String {
        switch availableBiometric {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .none: return "Passcode"
        }
    }

    /// Authenticate user with biometrics (Face ID / Touch ID) or device passcode.
    func authenticate(reason: String = "Unlock your vault") async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch {
            print("Biometric auth failed: \(error)")
            return false
        }
    }

    // MARK: - Keychain Storage (for OAuth tokens, sensitive config)

    func saveToKeychain(key: String, data: Data) -> Bool {
        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.entropy.app"
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.entropy.app",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    func loadFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.entropy.app",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func deleteFromKeychain(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.entropy.app"
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Token Management

    func saveGmailTokens(access: String, refresh: String) {
        if let accessData = access.data(using: .utf8) {
            _ = saveToKeychain(key: "gmail_access_token", data: accessData)
        }
        if let refreshData = refresh.data(using: .utf8) {
            _ = saveToKeychain(key: "gmail_refresh_token", data: refreshData)
        }
    }

    func loadGmailTokens() -> (access: String, refresh: String)? {
        guard let accessData = loadFromKeychain(key: "gmail_access_token"),
              let refreshData = loadFromKeychain(key: "gmail_refresh_token"),
              let access = String(data: accessData, encoding: .utf8),
              let refresh = String(data: refreshData, encoding: .utf8) else {
            return nil
        }
        return (access, refresh)
    }

    func clearGmailTokens() {
        _ = deleteFromKeychain(key: "gmail_access_token")
        _ = deleteFromKeychain(key: "gmail_refresh_token")
    }
}
