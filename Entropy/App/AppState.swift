import SwiftUI
import SwiftData

@Observable
final class AppState {
    var selectedTab: AppTab = .vacations
    var isGmailConnected: Bool = false
    var gmailScanStatus: GmailScanStatus = .idle
    var searchQuery: String = ""

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
}
