// AppLockService.swift
// Procedus - Unified
// Passcode and biometric authentication service

import Foundation
import LocalAuthentication
import SwiftUI

@Observable
class AppLockService {
    // MARK: - Passcode State
    private(set) var isPasscodeSet: Bool = false
    private(set) var isLocked: Bool = false
    var isBiometricsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "biometricsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "biometricsEnabled") }
    }
    
    // MARK: - Biometry Info
    private let context = LAContext()
    
    var isBiometryAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    var biometryType: LABiometryType {
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }
    
    var biometrySystemImage: String {
        switch biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        @unknown default:
            return "lock"
        }
    }
    
    var biometryName: String {
        switch biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        @unknown default:
            return "Biometrics"
        }
    }
    
    // MARK: - Keychain Keys
    private let passcodeKey = "procedus_passcode"
    
    // MARK: - Initialization
    
    init() {
        checkPasscodeStatus()
    }
    
    private func checkPasscodeStatus() {
        isPasscodeSet = getStoredPasscode() != nil
        isLocked = isPasscodeSet
    }
    
    // MARK: - Passcode Management
    
    func setPasscode(_ passcode: String) -> Bool {
        guard passcode.count >= 4 else { return false }
        
        let success = saveToKeychain(key: passcodeKey, value: passcode)
        if success {
            isPasscodeSet = true
            isLocked = false
        }
        return success
    }
    
    func removePasscode() {
        deleteFromKeychain(key: passcodeKey)
        isPasscodeSet = false
        isLocked = false
        isBiometricsEnabled = false
    }
    
    func verifyPasscode(_ passcode: String) -> Bool {
        guard let stored = getStoredPasscode() else { return false }
        let success = passcode == stored
        if success {
            isLocked = false
        }
        return success
    }
    
    private func getStoredPasscode() -> String? {
        loadFromKeychain(key: passcodeKey)
    }
    
    // MARK: - Biometric Authentication
    
    func authenticateWithBiometrics() async -> Bool {
        guard isBiometryAvailable && isBiometricsEnabled else { return false }
        
        let context = LAContext()
        context.localizedCancelTitle = "Use Passcode"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock Procedus"
            )
            if success {
                await MainActor.run {
                    isLocked = false
                }
            }
            return success
        } catch {
            return false
        }
    }
    
    // MARK: - Lock
    
    func lock() {
        if isPasscodeSet {
            isLocked = true
        }
    }
    
    // MARK: - Keychain Helpers
    
    private func saveToKeychain(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
