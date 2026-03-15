import Foundation
import SwiftData

enum TripStatus: String, Codable, CaseIterable {
    case planning, booked, inProgress, completed, cancelled

    var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .booked: return "Booked"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

@Model
final class Trip {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    @Attribute(.externalStorage) var coverImageData: Data?
    var status: TripStatus
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Accommodation.trip)
    var accommodations: [Accommodation]

    @Relationship(deleteRule: .cascade, inverse: \Flight.trip)
    var flights: [Flight]

    @Relationship(deleteRule: .cascade, inverse: \Reservation.trip)
    var reservations: [Reservation]

    @Relationship(deleteRule: .cascade, inverse: \ItineraryDay.trip)
    var itineraryDays: [ItineraryDay]

    @Relationship(deleteRule: .cascade, inverse: \TripTodo.trip)
    var todoItems: [TripTodo]

    @Relationship(deleteRule: .cascade, inverse: \Reminder.trip)
    var reminders: [Reminder]

    @Relationship(deleteRule: .cascade, inverse: \Attachment.trip)
    var attachments: [Attachment]

    init(name: String, startDate: Date, endDate: Date, status: TripStatus = .planning) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.notes = ""
        self.createdAt = Date()
        self.updatedAt = Date()
        self.accommodations = []
        self.flights = []
        self.reservations = []
        self.itineraryDays = []
        self.todoItems = []
        self.reminders = []
        self.attachments = []
    }

    var daysUntilStart: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: startDate).day ?? 0)
    }

    var isUpcoming: Bool {
        startDate > Date() && status != .cancelled
    }

    var isPast: Bool {
        endDate < Date() && status != .cancelled
    }

    var isInProgress: Bool {
        startDate <= Date() && endDate >= Date() && status != .cancelled && status != .completed
    }

    var isCancelled: Bool {
        status == .cancelled
    }
}

@Model
final class Accommodation {
    var id: UUID
    var hotelName: String
    var address: String
    var checkIn: Date
    var checkOut: Date
    var confirmationNumber: String
    var notes: String
    var isCancelled: Bool
    var sourceEmail: String?

    @Relationship var trip: Trip?
    @Relationship(deleteRule: .cascade, inverse: \Attachment.accommodation)
    var attachments: [Attachment]

    init(hotelName: String, address: String = "", checkIn: Date, checkOut: Date, confirmationNumber: String = "") {
        self.id = UUID()
        self.hotelName = hotelName
        self.address = address
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.confirmationNumber = confirmationNumber
        self.notes = ""
        self.isCancelled = false
        self.attachments = []
    }
}

@Model
final class Flight {
    var id: UUID
    var airline: String
    var flightNumber: String
    var departureAirport: String
    var arrivalAirport: String
    var departureDateTime: Date
    var arrivalDateTime: Date
    var confirmationCode: String
    var seatAssignment: String?
    var isCancelled: Bool
    var sourceEmail: String?

    @Relationship var trip: Trip?
    @Relationship(deleteRule: .cascade, inverse: \Attachment.flight)
    var attachments: [Attachment]

    init(airline: String, flightNumber: String, departureAirport: String, arrivalAirport: String,
         departureDateTime: Date, arrivalDateTime: Date, confirmationCode: String = "") {
        self.id = UUID()
        self.airline = airline
        self.flightNumber = flightNumber
        self.departureAirport = departureAirport
        self.arrivalAirport = arrivalAirport
        self.departureDateTime = departureDateTime
        self.arrivalDateTime = arrivalDateTime
        self.confirmationCode = confirmationCode
        self.isCancelled = false
        self.attachments = []
    }

    var route: String {
        "\(departureAirport) → \(arrivalAirport)"
    }
}

enum ReservationType: String, Codable, CaseIterable {
    case restaurant, tour, activity, carRental, train, shortTermRental, other
}

@Model
final class Reservation {
    var id: UUID
    var type: ReservationType
    var name: String
    var location: String
    var dateTime: Date
    var endDateTime: Date?
    var confirmationNumber: String?
    var notes: String
    var isCancelled: Bool
    var sourceEmail: String?

    @Relationship var trip: Trip?

    init(type: ReservationType, name: String, location: String = "", dateTime: Date) {
        self.id = UUID()
        self.type = type
        self.name = name
        self.location = location
        self.dateTime = dateTime
        self.notes = ""
        self.isCancelled = false
    }
}

@Model
final class ItineraryDay {
    var id: UUID
    var date: Date
    var sortOrder: Int

    @Relationship var trip: Trip?
    @Relationship(deleteRule: .cascade, inverse: \ItineraryItem.day)
    var items: [ItineraryItem]

    init(date: Date, sortOrder: Int = 0) {
        self.id = UUID()
        self.date = date
        self.sortOrder = sortOrder
        self.items = []
    }
}

@Model
final class ItineraryItem {
    var id: UUID
    var title: String
    var notes: String
    var startTime: Date?
    var endTime: Date?
    var location: String?
    var sortOrder: Int

    @Relationship var day: ItineraryDay?

    init(title: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.title = title
        self.notes = ""
        self.sortOrder = sortOrder
    }
}

@Model
final class TripTodo {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var dueDate: Date?

    @Relationship var trip: Trip?
    @Relationship(deleteRule: .cascade, inverse: \Reminder.tripTodo) var reminder: Reminder?

    init(title: String, dueDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.dueDate = dueDate
    }
}
