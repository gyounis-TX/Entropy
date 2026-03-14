import SwiftUI
import SwiftData

@main
struct EntropyApp: App {
    let modelContainer: ModelContainer

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
                .environment(AppState())
        }
        .modelContainer(modelContainer)
    }
}
