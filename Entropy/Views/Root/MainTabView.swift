import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            Tab("Trips", systemImage: "airplane", value: .vacations) {
                NavigationStack {
                    TripListView()
                }
            }

            Tab("Notes", systemImage: "note.text", value: .notes) {
                NavigationStack {
                    NotesHomeView()
                }
            }

            Tab("Vault", systemImage: "lock.shield.fill", value: .vault) {
                NavigationStack {
                    VaultHomeView()
                }
            }

            Tab("Projects", systemImage: "folder.fill", value: .projects) {
                NavigationStack {
                    ProjectsDashboardView()
                }
            }

            Tab("Reminders", systemImage: "bell.fill", value: .reminders) {
                NavigationStack {
                    RemindersHubView()
                }
            }
        }
    }
}
