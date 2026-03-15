import SwiftData
import Foundation

/// Shared model container for both the app and widget extension.
/// Both targets must use the same App Group identifier.
enum SharedModelContainer {
    static let appGroupID = "group.com.entropy.app"

    static func create() -> ModelContainer? {
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

        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }

        let storeURL = containerURL.appendingPathComponent("Entropy.store")
        let config = ModelConfiguration(
            "Entropy",
            schema: schema,
            url: storeURL,
            allowsSave: false // widgets are read-only
        )

        return try? ModelContainer(for: schema, configurations: [config])
    }
}
