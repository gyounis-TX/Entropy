import Foundation
import SwiftData

/// Exports app data as a JSON backup file.
@MainActor
final class ExportService {

    struct ExportData: Codable {
        let exportDate: Date
        let version: String
        let trips: [TripExport]
        let categories: [CategoryExport]
        let projects: [ProjectExport]
        let reminders: [ReminderExport]
        let vaultItems: [VaultItemExport]
    }

    struct TripExport: Codable {
        let name: String
        let startDate: Date
        let endDate: Date
        let status: String
        let notes: String
        let flights: [FlightExport]
        let accommodations: [AccommodationExport]
        let reservations: [ReservationExport]
        let todos: [TripTodoExport]
    }

    struct FlightExport: Codable {
        let airline: String
        let flightNumber: String
        let departureAirport: String
        let arrivalAirport: String
        let departureDateTime: Date
        let arrivalDateTime: Date
        let confirmationCode: String
        let seatAssignment: String?
        let isCancelled: Bool
    }

    struct AccommodationExport: Codable {
        let hotelName: String
        let address: String
        let checkIn: Date
        let checkOut: Date
        let confirmationNumber: String
        let notes: String
        let isCancelled: Bool
    }

    struct ReservationExport: Codable {
        let type: String
        let name: String
        let location: String
        let dateTime: Date
        let endDateTime: Date?
        let confirmationNumber: String?
        let notes: String
        let isCancelled: Bool
    }

    struct TripTodoExport: Codable {
        let title: String
        let isCompleted: Bool
        let dueDate: Date?
    }

    struct VaultItemExport: Codable {
        let type: String
        let label: String
        let expirationDate: Date?
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
        let vaultItems = (try? context.fetch(FetchDescriptor<VaultItem>())) ?? []

        let export = ExportData(
            exportDate: Date(),
            version: "1.0",
            trips: trips.map { trip in
                TripExport(
                    name: trip.name,
                    startDate: trip.startDate,
                    endDate: trip.endDate,
                    status: trip.status.rawValue,
                    notes: trip.notes,
                    flights: trip.flights.map { flight in
                        FlightExport(
                            airline: flight.airline,
                            flightNumber: flight.flightNumber,
                            departureAirport: flight.departureAirport,
                            arrivalAirport: flight.arrivalAirport,
                            departureDateTime: flight.departureDateTime,
                            arrivalDateTime: flight.arrivalDateTime,
                            confirmationCode: flight.confirmationCode,
                            seatAssignment: flight.seatAssignment,
                            isCancelled: flight.isCancelled
                        )
                    },
                    accommodations: trip.accommodations.map { acc in
                        AccommodationExport(
                            hotelName: acc.hotelName,
                            address: acc.address,
                            checkIn: acc.checkIn,
                            checkOut: acc.checkOut,
                            confirmationNumber: acc.confirmationNumber,
                            notes: acc.notes,
                            isCancelled: acc.isCancelled
                        )
                    },
                    reservations: trip.reservations.map { res in
                        ReservationExport(
                            type: res.type.rawValue,
                            name: res.name,
                            location: res.location,
                            dateTime: res.dateTime,
                            endDateTime: res.endDateTime,
                            confirmationNumber: res.confirmationNumber,
                            notes: res.notes,
                            isCancelled: res.isCancelled
                        )
                    },
                    todos: trip.todoItems.map { todo in
                        TripTodoExport(
                            title: todo.title,
                            isCompleted: todo.isCompleted,
                            dueDate: todo.dueDate
                        )
                    }
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
            },
            vaultItems: vaultItems.map { item in
                VaultItemExport(
                    type: item.type.rawValue,
                    label: item.label,
                    expirationDate: item.expirationDate,
                    notes: item.notes
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
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let fileName = "Entropy-Backup-\(formatter.string(from: Date())).json"

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }
}
