import SwiftUI
import SwiftData

@Observable
final class AppState {
    var selectedTab: AppTab = .vacations
    var isGmailConnected: Bool = false
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

        static func == (lhs: DeepLinkAction, rhs: DeepLinkAction) -> Bool {
            switch (lhs, rhs) {
            case (.createNote(let a), .createNote(let b)): return a == b
            case (.createTrip, .createTrip): return true
            case (.importEmail, .importEmail): return true
            default: return false
            }
        }
    }

    /// Consume the deep link action (call after handling it).
    func consumeDeepLink() {
        deepLinkAction = nil
    }
}
