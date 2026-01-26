// AppState.swift
// Procedus - Unified
// Central app state management with dev mode support

import Foundation
import SwiftUI
import Security

// MARK: - App State

@Observable
class AppState {
    // Current user
    var currentUser: User?
    var accountMode: AccountMode = .individual

    // Specialty pack management
    var enabledSpecialtyPackIds: Set<String> = ["interventional-cardiology"]

    // Lock screen
    var isLocked: Bool = false
    var hasCompletedOnboarding: Bool = false

    // Individual mode profile - trigger forces view updates when names change
    private var profileUpdateTrigger: Int = 0

    // Facility selection trigger - forces view updates when default facility changes
    private var facilityUpdateTrigger: Int = 0

    // Attending selection trigger - forces view updates when selected attending changes
    private var attendingUpdateTrigger: Int = 0

    var individualFirstName: String {
        get { UserDefaults.standard.string(forKey: "individualFirstName") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "individualFirstName")
            profileUpdateTrigger += 1
        }
    }

    var individualLastName: String {
        get { UserDefaults.standard.string(forKey: "individualLastName") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "individualLastName")
            profileUpdateTrigger += 1
        }
    }

    var individualDisplayName: String {
        // Access trigger to ensure reactivity
        _ = profileUpdateTrigger
        let first = UserDefaults.standard.string(forKey: "individualFirstName")?.trimmingCharacters(in: .whitespaces) ?? ""
        let last = UserDefaults.standard.string(forKey: "individualLastName")?.trimmingCharacters(in: .whitespaces) ?? ""
        if first.isEmpty && last.isEmpty {
            return "Fellow"
        }
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Individual Mode Program Settings

    var individualFellowshipSpecialtyRaw: String {
        get { UserDefaults.standard.string(forKey: "individualFellowshipSpecialty") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "individualFellowshipSpecialty")
        }
    }

    var individualFellowshipSpecialty: FellowshipSpecialty? {
        get {
            let raw = individualFellowshipSpecialtyRaw
            return raw.isEmpty ? nil : FellowshipSpecialty(rawValue: raw)
        }
        set {
            individualFellowshipSpecialtyRaw = newValue?.rawValue ?? ""
            // Auto-enable specialty packs when specialty is selected
            if let specialty = newValue {
                enablePacksForSpecialty(specialty)
            }
        }
    }

    var individualProgramName: String {
        get { UserDefaults.standard.string(forKey: "individualProgramName") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "individualProgramName") }
    }

    var individualInstitutionName: String {
        get { UserDefaults.standard.string(forKey: "individualInstitutionName") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "individualInstitutionName") }
    }

    var individualPGYLevelRaw: Int {
        get { UserDefaults.standard.integer(forKey: "individualPGYLevel") }
        set { UserDefaults.standard.set(newValue, forKey: "individualPGYLevel") }
    }

    var individualPGYLevel: PGYLevel? {
        get {
            let raw = individualPGYLevelRaw
            return raw > 0 ? PGYLevel(rawValue: raw) : nil
        }
        set {
            individualPGYLevelRaw = newValue?.rawValue ?? 0
        }
    }

    /// Whether the user has ONLY cardiac imaging enabled (no other cardiology packs)
    var isCardiacImagingOnlyMode: Bool {
        let cardiacImaging = enabledSpecialtyPackIds.contains("cardiac-imaging")
        let interventionalCardiology = enabledSpecialtyPackIds.contains("interventional-cardiology")
        let electrophysiology = enabledSpecialtyPackIds.contains("electrophysiology")
        return cardiacImaging && !interventionalCardiology && !electrophysiology
    }

    /// Whether the user has cardiac imaging AND other cardiology packs enabled
    var hasCardiacImagingPlusOtherCardiology: Bool {
        let cardiacImaging = enabledSpecialtyPackIds.contains("cardiac-imaging")
        let interventionalCardiology = enabledSpecialtyPackIds.contains("interventional-cardiology")
        let electrophysiology = enabledSpecialtyPackIds.contains("electrophysiology")
        return cardiacImaging && (interventionalCardiology || electrophysiology)
    }

    /// Whether case entry should show the invasive/noninvasive toggle
    var shouldShowCaseTypeToggle: Bool {
        hasCardiacImagingPlusOtherCardiology
    }

    /// Whether the user's specialty is cardiology (shows operator position)
    var isCardiologyFellowship: Bool {
        individualFellowshipSpecialty?.isCardiology == true
    }

    /// Enable specialty packs based on selected specialty
    func enablePacksForSpecialty(_ specialty: FellowshipSpecialty) {
        enabledSpecialtyPackIds = Set(specialty.defaultPackIds)
        savePersistedState()
    }

    // Dev mode (DEBUG only)
    #if DEBUG
    var isDevMode: Bool = false
    var devUserRole: UserRole = .fellow
    var devUserEmail: String? = nil
    #endif

    // Identity selection for institutional mode (temporary until invite codes)
    var selectedFellowId: UUID? {
        get {
            if let uuidString = UserDefaults.standard.string(forKey: "selectedFellowId") {
                return UUID(uuidString: uuidString)
            }
            return nil
        }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: "selectedFellowId")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedFellowId")
            }
        }
    }

    var selectedAttendingId: UUID? {
        get {
            // Access trigger to ensure reactivity
            _ = attendingUpdateTrigger
            if let uuidString = UserDefaults.standard.string(forKey: "selectedAttendingId") {
                return UUID(uuidString: uuidString)
            }
            return nil
        }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: "selectedAttendingId")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedAttendingId")
            }
            attendingUpdateTrigger += 1
        }
    }

    // Default facility for case entry (can change for rotations)
    var defaultFacilityId: UUID? {
        get {
            // Access trigger to ensure reactivity
            _ = facilityUpdateTrigger
            if let uuidString = UserDefaults.standard.string(forKey: "defaultFacilityId") {
                return UUID(uuidString: uuidString)
            }
            return nil
        }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: "defaultFacilityId")
            } else {
                UserDefaults.standard.removeObject(forKey: "defaultFacilityId")
            }
            facilityUpdateTrigger += 1
        }
    }
    
    // Computed Properties
    
    var isIndividualMode: Bool {
        accountMode == .individual
    }
    
    var isAuthenticated: Bool {
        #if DEBUG
        if isDevMode { return true }
        #endif
        return currentUser != nil || accountMode == .individual
    }
    
    var userRole: UserRole {
        #if DEBUG
        if isDevMode { return devUserRole }
        #endif
        return currentUser?.role ?? .fellow
    }
    
    // MARK: - Initialization
    
    init() {
        loadPersistedState()
    }
    
    // MARK: - Setup Methods
    
    /// Setup individual mode (no login required)
    func setupIndividualMode() {
        accountMode = .individual
        currentUser = nil
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set("individual", forKey: "accountMode")
    }
    
    /// Setup institutional mode with user
    func setupInstitutionalMode(user: User) {
        accountMode = .institutional
        currentUser = user
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set("institutional", forKey: "accountMode")
    }
    
    // MARK: - Dev Mode (DEBUG only)
    
    #if DEBUG
    // MARK: - Keychain Keys (Dev Mode Persistence)

    private static let keychainDevModeEnabled = "procedus_dev_mode_enabled"
    private static let keychainDevModeRole = "procedus_dev_mode_role"
    private static let keychainHasCompletedOnboarding = "procedus_dev_has_completed_onboarding"

    func devSignIn(role: UserRole) {
        isDevMode = true
        devUserRole = role
        devUserEmail = "\(role.rawValue)@dev.procedus.app"
        accountMode = .institutional

        // Dev mode implies onboarding is complete
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Persist dev mode state to Keychain (survives reinstall)
        _ = saveToKeychain(key: Self.keychainDevModeEnabled, value: "true")
        _ = saveToKeychain(key: Self.keychainDevModeRole, value: role.rawValue)
        _ = saveToKeychain(key: Self.keychainHasCompletedOnboarding, value: "true")
    }

    func devSignOut() {
        isDevMode = false
        devUserRole = .fellow
        devUserEmail = nil
        selectedFellowId = nil

        // Clear from Keychain
        deleteFromKeychain(key: Self.keychainDevModeEnabled)
        deleteFromKeychain(key: Self.keychainDevModeRole)
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

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
    #endif
    
    // MARK: - Specialty Pack Management
    
    func getEnabledPacks() -> [SpecialtyPack] {
        enabledSpecialtyPackIds.compactMap { packId in
            SpecialtyPackCatalog.allPacks.first { $0.id == packId }
        }
    }
    
    func isPackEnabled(_ packId: String) -> Bool {
        enabledSpecialtyPackIds.contains(packId)
    }
    
    func toggleSpecialtyPack(_ packId: String) {
        if enabledSpecialtyPackIds.contains(packId) {
            enabledSpecialtyPackIds.remove(packId)
        } else {
            enabledSpecialtyPackIds.insert(packId)
        }
        savePersistedState()
    }
    
    // MARK: - Authentication
    
    func signOut() {
        #if DEBUG
        if isDevMode {
            devSignOut()
            return
        }
        #endif
        
        currentUser = nil
        accountMode = .individual
    }
    
    func startIndividualMode() {
        accountMode = .individual
        currentUser = nil
    }
    
    // MARK: - Persistence
    
    private func loadPersistedState() {
        // Load enabled packs
        if let savedPacks = UserDefaults.standard.stringArray(forKey: "enabledSpecialtyPackIds") {
            enabledSpecialtyPackIds = Set(savedPacks)
        }
        
        // Load onboarding state
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        #if DEBUG
        // Keychain fallback for onboarding state (survives reinstall)
        if !hasCompletedOnboarding,
           loadFromKeychain(key: Self.keychainHasCompletedOnboarding) == "true" {
            hasCompletedOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }

        // Restore dev mode from Keychain (survives reinstall)
        if loadFromKeychain(key: Self.keychainDevModeEnabled) == "true",
           let roleString = loadFromKeychain(key: Self.keychainDevModeRole),
           let role = UserRole(rawValue: roleString) {
            devSignIn(role: role)
        }
        // Migration: copy existing UserDefaults dev mode state to Keychain
        else if UserDefaults.standard.bool(forKey: "devModeEnabled"),
                let roleString = UserDefaults.standard.string(forKey: "devModeRole"),
                let role = UserRole(rawValue: roleString) {
            devSignIn(role: role) // This now persists to Keychain
        }

        // Clean up stale Keychain key from prior dev builds
        deleteFromKeychain(key: "procedus_dev_user_id")

        // Dev mode defaults to cardiology fellowship if not set
        if individualFellowshipSpecialty == nil {
            individualFellowshipSpecialtyRaw = FellowshipSpecialty.cardiology.rawValue
            // Also enable cardiology packs if none are set
            if enabledSpecialtyPackIds.isEmpty || enabledSpecialtyPackIds == ["interventional-cardiology"] {
                enabledSpecialtyPackIds = Set(FellowshipSpecialty.cardiology.defaultPackIds)
                savePersistedState()
            }
        }

        // Dev mode defaults fellow name to a Simpson's character if not set
        if individualFirstName.isEmpty && individualLastName.isEmpty {
            individualFirstName = "Bart"
            individualLastName = "Simpson"
        }

        // Dev mode defaults PGY level to PGY-4 if not set
        if individualPGYLevel == nil {
            individualPGYLevel = .pgy4
        }
        #endif
    }
    
    private func savePersistedState() {
        UserDefaults.standard.set(Array(enabledSpecialtyPackIds), forKey: "enabledSpecialtyPackIds")
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        #if DEBUG
        _ = saveToKeychain(key: Self.keychainHasCompletedOnboarding, value: "true")
        #endif
    }
    
    // Current week bucket helper
    var currentWeekBucket: String {
        CaseEntry.makeWeekBucket(for: Date())
    }
}
