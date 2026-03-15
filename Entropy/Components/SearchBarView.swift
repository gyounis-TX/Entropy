import SwiftUI
import SwiftData

/// Global search view that searches across all sections.
struct GlobalSearchView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var query = ""
    @State private var results: [SearchService.SearchResult] = []
    private let searchService = SearchService()

    var body: some View {
        List {
            if results.isEmpty && !query.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                let grouped = Dictionary(grouping: results, by: \.section)
                ForEach(SearchService.SearchResult.Section.allCases, id: \.self) { section in
                    if let sectionResults = grouped[section], !sectionResults.isEmpty {
                        Section(section.rawValue) {
                            ForEach(sectionResults) { result in
                                Button {
                                    navigateToResult(result)
                                } label: {
                                    HStack {
                                        Image(systemName: result.section.icon)
                                            .foregroundStyle(.blue)
                                            .frame(width: 24)
                                        VStack(alignment: .leading) {
                                            Text(result.title)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                            Text(result.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search everything")
        .onChange(of: query) {
            results = searchService.search(query: query, context: context)
        }
        .navigationTitle("Search")
    }

    private func navigateToResult(_ result: SearchService.SearchResult) {
        let entityID = result.entityID.uuidString
        switch result.section {
        case .vacations:
            appState.selectedTab = .vacations
            appState.deepLinkAction = .viewTrip(id: entityID)
        case .notes:
            appState.selectedTab = .notes
            appState.deepLinkAction = .viewNote(id: entityID)
        case .vault:
            appState.selectedTab = .vault
            appState.deepLinkAction = .viewVaultItem(id: entityID)
        case .projects:
            appState.selectedTab = .projects
            appState.deepLinkAction = .viewProject(id: entityID)
        case .reminders:
            appState.selectedTab = .reminders
            appState.deepLinkAction = .viewReminder(id: entityID)
        }
    }
}
