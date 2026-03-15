import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var showingSettings = false

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
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }
}
