import Foundation
import SwiftData

/// Exports app data as a JSON backup file.
final class ExportService {

    struct ExportData: Codable {
        let exportDate: Date
        let version: String
        let trips: [TripExport]
        let categories: [CategoryExport]
        let projects: [ProjectExport]
        let reminders: [ReminderExport]
    }

    struct TripExport: Codable {
        let name: String
        let startDate: Date
        let endDate: Date
        let status: String
        let notes: String
    }

    struct CategoryExport: Codable {
        let name: String
        let icon: String?
        let color: String?
        let notes: [NoteExport]
    }

    struct NoteExport: Codable {
        let title: String
        let body: String
        let isPinned: Bool
        let tags: [String]
        let createdAt: Date
        let updatedAt: Date
    }

    struct ProjectExport: Codable {
        let name: String
        let status: String
        let currentStatus: String
        let projectDescription: String
        let tags: [String]
    }

    struct ReminderExport: Codable {
        let title: String
        let body: String?
        let triggerDate: Date
        let isCompleted: Bool
        let sourceType: String
    }

    func exportAll(context: ModelContext) throws -> Data {
        let trips = (try? context.fetch(FetchDescriptor<Trip>())) ?? []
        let categories = (try? context.fetch(FetchDescriptor<NoteCategory>())) ?? []
        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        let reminders = (try? context.fetch(FetchDescriptor<Reminder>())) ?? []

        let export = ExportData(
            exportDate: Date(),
            version: "1.0",
            trips: trips.map { trip in
                TripExport(
                    name: trip.name,
                    startDate: trip.startDate,
                    endDate: trip.endDate,
                    status: trip.status.rawValue,
                    notes: trip.notes
                )
            },
            categories: categories.map { cat in
                CategoryExport(
                    name: cat.name,
                    icon: cat.icon,
                    color: cat.color,
                    notes: cat.notes.map { note in
                        NoteExport(
                            title: note.title,
                            body: note.body,
                            isPinned: note.isPinned,
                            tags: note.tags,
                            createdAt: note.createdAt,
                            updatedAt: note.updatedAt
                        )
                    }
                )
            },
            projects: projects.map { proj in
                ProjectExport(
                    name: proj.name,
                    status: proj.status.rawValue,
                    currentStatus: proj.currentStatus,
                    projectDescription: proj.projectDescription,
                    tags: proj.tags
                )
            },
            reminders: reminders.map { rem in
                ReminderExport(
                    title: rem.title,
                    body: rem.body,
                    triggerDate: rem.triggerDate,
                    isCompleted: rem.isCompleted,
                    sourceType: rem.sourceType.rawValue
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    func exportFileURL(data: Data) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fileName = "Entropy-Backup-\(formatter.string(from: Date())).json"

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }
}
