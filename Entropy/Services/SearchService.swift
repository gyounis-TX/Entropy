import Foundation
import SwiftData

/// Cross-section full-text search across all entities.
/// Uses SwiftData predicates to push filtering to the database layer.
@MainActor
final class SearchService {

    struct SearchResult: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let section: Section
        let entityID: UUID

        enum Section: String, CaseIterable {
            case vacations = "Vacations"
            case notes = "Notes"
            case vault = "Vault"
            case projects = "Projects"
            case reminders = "Reminders"

            var icon: String {
                switch self {
                case .vacations: return "airplane"
                case .notes: return "note.text"
                case .vault: return "lock.shield.fill"
                case .projects: return "folder.fill"
                case .reminders: return "bell.fill"
                }
            }
        }
    }

    /// Search across all sections. Vault results only included if `includeVault` is true
    /// (caller must verify biometric authentication first).
    func search(query: String, context: ModelContext, includeVault: Bool = false) -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        var results: [SearchResult] = []

        // Search trips — use predicate for DB-level filtering
        let tripDescriptor = FetchDescriptor<Trip>(
            predicate: #Predicate<Trip> { trip in
                trip.name.localizedStandardContains(query) ||
                trip.notes.localizedStandardContains(query)
            }
        )
        if let trips = try? context.fetch(tripDescriptor) {
            for trip in trips {
                results.append(SearchResult(
                    title: trip.name,
                    subtitle: "Trip · \(trip.status.displayName)",
                    section: .vacations,
                    entityID: trip.id
                ))
            }
        }

        // Search notes
        let noteDescriptor = FetchDescriptor<Note>(
            predicate: #Predicate<Note> { note in
                note.title.localizedStandardContains(query) ||
                note.body.localizedStandardContains(query)
            }
        )
        if let notes = try? context.fetch(noteDescriptor) {
            for note in notes {
                results.append(SearchResult(
                    title: note.title,
                    subtitle: "Note · \(note.category?.name ?? "Uncategorized")",
                    section: .notes,
                    entityID: note.id
                ))
            }
        }

        // Search vault items — only if authenticated
        if includeVault {
            let vaultDescriptor = FetchDescriptor<VaultItem>(
                predicate: #Predicate<VaultItem> { item in
                    item.label.localizedStandardContains(query) ||
                    item.notes.localizedStandardContains(query)
                }
            )
            if let items = try? context.fetch(vaultDescriptor) {
                for item in items {
                    results.append(SearchResult(
                        title: item.label,
                        subtitle: "Vault · \(item.type.rawValue)",
                        section: .vault,
                        entityID: item.id
                    ))
                }
            }
        }

        // Search projects
        let projectDescriptor = FetchDescriptor<Project>(
            predicate: #Predicate<Project> { project in
                project.name.localizedStandardContains(query) ||
                project.currentStatus.localizedStandardContains(query) ||
                project.projectDescription.localizedStandardContains(query)
            }
        )
        if let projects = try? context.fetch(projectDescriptor) {
            for project in projects {
                results.append(SearchResult(
                    title: project.name,
                    subtitle: "Project · \(project.status.displayName)",
                    section: .projects,
                    entityID: project.id
                ))
            }
        }

        // Search reminders
        let reminderDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.title.localizedStandardContains(query)
            }
        )
        if let reminders = try? context.fetch(reminderDescriptor) {
            for reminder in reminders {
                results.append(SearchResult(
                    title: reminder.title,
                    subtitle: "Reminder · \(reminder.sourceType.rawValue)",
                    section: .reminders,
                    entityID: reminder.id
                ))
            }
        }

        return results
    }
}
