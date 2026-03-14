import SwiftUI
import SwiftData

@main
struct EntropyApp: App {
    let modelContainer: ModelContainer
    @State private var appState = AppState()
    @State private var gmailService = GmailScanService()

    init() {
        let schema = Schema([
            Trip.self,
            Accommodation.self,
            Flight.self,
            Reservation.self,
            ItineraryDay.self,
            ItineraryItem.self,
            TripTodo.self,
            NoteCategory.self,
            Note.self,
            VaultItem.self,
            VaultField.self,
            Project.self,
            ProjectStep.self,
            ProjectNote.self,
            Reminder.self,
            Attachment.self
        ])

        let config = ModelConfiguration(
            "Entropy",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(appState)
                .environment(gmailService)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(modelContainer)
    }

    /// Handles deep links from widgets and share sheet.
    /// URL scheme: entropy://action?params
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "entropy" else { return }

        switch url.host {
        case "new-note":
            appState.selectedTab = .notes
            appState.deepLinkAction = .createNote(
                categoryID: url.queryValue(for: "category")
            )

        case "new-trip":
            appState.selectedTab = .vacations
            appState.deepLinkAction = .createTrip

        case "reminders":
            appState.selectedTab = .reminders

        case "import-email":
            appState.selectedTab = .vacations
            appState.deepLinkAction = .importEmail

        default:
            break
        }
    }
}

// MARK: - URL Query Helpers

private extension URL {
    func queryValue(for key: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == key })?
            .value
    }
}
