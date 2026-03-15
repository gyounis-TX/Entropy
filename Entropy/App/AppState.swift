import SwiftUI
import SwiftData

@Observable
final class AppState {
    var selectedTab: AppTab = .vacations
    var isGmailConnected: Bool {
        get { UserDefaults.standard.bool(forKey: "isGmailConnected") }
        set { UserDefaults.standard.set(newValue, forKey: "isGmailConnected") }
    }
    var gmailScanStatus: GmailScanStatus = .idle
    var searchQuery: String = ""
    var deepLinkAction: DeepLinkAction?

    enum AppTab: Int, CaseIterable {
        case vacations, notes, vault, projects, reminders
    }

    enum GmailScanStatus: Equatable {
        case idle
        case scanning
        case found(Int)
        case error(String)

        static func == (lhs: GmailScanStatus, rhs: GmailScanStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.scanning, .scanning): return true
            case (.found(let a), .found(let b)): return a == b
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    /// Actions triggered by deep links from widgets or share sheet.
    enum DeepLinkAction: Equatable {
        case createNote(categoryID: String?)
        case createTrip
        case importEmail
        case viewTrip(id: String)
        case viewNote(id: String)
        case viewVaultItem(id: String)
        case viewProject(id: String)
        case viewReminder(id: String)

        static func == (lhs: DeepLinkAction, rhs: DeepLinkAction) -> Bool {
            switch (lhs, rhs) {
            case (.createNote(let a), .createNote(let b)): return a == b
            case (.createTrip, .createTrip): return true
            case (.importEmail, .importEmail): return true
            case (.viewTrip(let a), .viewTrip(let b)): return a == b
            case (.viewNote(let a), .viewNote(let b)): return a == b
            case (.viewVaultItem(let a), .viewVaultItem(let b)): return a == b
            case (.viewProject(let a), .viewProject(let b)): return a == b
            case (.viewReminder(let a), .viewReminder(let b)): return a == b
            default: return false
            }
        }
    }

    /// Consume the deep link action (call after handling it).
    func consumeDeepLink() {
        deepLinkAction = nil
    }
}
