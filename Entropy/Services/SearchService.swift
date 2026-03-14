import Foundation
import SwiftData

/// Cross-section full-text search across all entities.
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

    func search(query: String, context: ModelContext) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()

        var results: [SearchResult] = []

        // Search trips
        if let trips = try? context.fetch(FetchDescriptor<Trip>()) {
            for trip in trips where trip.name.lowercased().contains(lowered) || trip.notes.lowercased().contains(lowered) {
                results.append(SearchResult(
                    title: trip.name,
                    subtitle: "Trip · \(trip.status.rawValue)",
                    section: .vacations,
                    entityID: trip.id
                ))
            }
        }

        // Search notes
        if let notes = try? context.fetch(FetchDescriptor<Note>()) {
            for note in notes where note.title.lowercased().contains(lowered) || note.body.lowercased().contains(lowered) {
                results.append(SearchResult(
                    title: note.title,
                    subtitle: "Note · \(note.category?.name ?? "Uncategorized")",
                    section: .notes,
                    entityID: note.id
                ))
            }
        }

        // Search vault items
        if let items = try? context.fetch(FetchDescriptor<VaultItem>()) {
            for item in items where item.label.lowercased().contains(lowered) || item.notes.lowercased().contains(lowered) {
                results.append(SearchResult(
                    title: item.label,
                    subtitle: "Vault · \(item.type.displayName)",
                    section: .vault,
                    entityID: item.id
                ))
            }
        }

        // Search projects
        if let projects = try? context.fetch(FetchDescriptor<Project>()) {
            for project in projects where project.name.lowercased().contains(lowered) ||
                project.currentStatus.lowercased().contains(lowered) ||
                project.projectDescription.lowercased().contains(lowered) {
                results.append(SearchResult(
                    title: project.name,
                    subtitle: "Project · \(project.status.displayName)",
                    section: .projects,
                    entityID: project.id
                ))
            }
        }

        // Search reminders
        if let reminders = try? context.fetch(FetchDescriptor<Reminder>()) {
            for reminder in reminders where reminder.title.lowercased().contains(lowered) {
                results.append(SearchResult(
                    title: reminder.title,
                    subtitle: "Reminder · \(reminder.sourceDescription)",
                    section: .reminders,
                    entityID: reminder.id
                ))
            }
        }

        return results
    }
}
