import Foundation

/// Represents a parsed booking from a Gmail email, before it's committed to SwiftData.
enum BookingCategory: String, Codable {
    case flight, hotel, shortTermRental, train, carRental
}

struct ParsedBooking: Identifiable, Codable {
    let id: UUID
    let category: BookingCategory
    let provider: String
    let confirmationNumber: String
    let startDate: Date
    let endDate: Date?
    let details: BookingDetails
    let sourceEmailID: String
    let sourceEmailSubject: String
    let parsedAt: Date
    var isCancellation: Bool

    /// Flight bookings only: confirmed legs beyond the primary outbound leg carried
    /// in `details` — e.g. additional forward segments of a multi-city itinerary, or
    /// a single (unambiguous) return leg. These are committed automatically alongside
    /// the outbound leg.
    let additionalLegs: [FlightDetails]

    /// Flight bookings only: alternative return flights the traveler must choose
    /// between (e.g. two candidate return dates on the same route). Present only when
    /// there are 2+ candidates; the traveler picks at most one to commit.
    let returnOptions: [FlightDetails]

    init(category: BookingCategory, provider: String, confirmationNumber: String,
         startDate: Date, endDate: Date? = nil, details: BookingDetails,
         sourceEmailID: String, sourceEmailSubject: String, isCancellation: Bool = false,
         additionalLegs: [FlightDetails] = [], returnOptions: [FlightDetails] = []) {
        self.id = UUID()
        self.category = category
        self.provider = provider
        self.confirmationNumber = confirmationNumber
        self.startDate = startDate
        self.endDate = endDate
        self.details = details
        self.sourceEmailID = sourceEmailID
        self.sourceEmailSubject = sourceEmailSubject
        self.parsedAt = Date()
        self.isCancellation = isCancellation
        self.additionalLegs = additionalLegs
        self.returnOptions = returnOptions
    }
}

enum BookingDetails: Codable {
    case flight(FlightDetails)
    case hotel(HotelDetails)
    case rental(RentalDetails)
    case train(TrainDetails)
    case carRental(CarRentalDetails)
}

struct FlightDetails: Codable, Hashable {
    let airline: String
    let flightNumber: String
    let departureAirport: String
    let arrivalAirport: String
    let departureDateTime: Date
    let arrivalDateTime: Date
    let seatAssignment: String?

    var route: String { "\(departureAirport) → \(arrivalAirport)" }
}

struct HotelDetails: Codable {
    let hotelName: String
    let address: String
    let checkIn: Date
    let checkOut: Date
}

struct RentalDetails: Codable {
    let propertyName: String
    let address: String
    let checkIn: Date
    let checkOut: Date
    let hostName: String?
}

struct TrainDetails: Codable {
    let route: String
    let departureStation: String
    let arrivalStation: String
    let departureDateTime: Date
    let arrivalDateTime: Date
    let seatAssignment: String?
    let carNumber: String?
}

struct CarRentalDetails: Codable {
    let company: String
    let pickupLocation: String
    let dropoffLocation: String
    let pickupDateTime: Date
    let dropoffDateTime: Date
}

/// A suggested trip grouping when multiple bookings fall in the same date window.
struct SuggestedTrip: Identifiable {
    let id = UUID()
    let suggestedName: String
    let startDate: Date
    let endDate: Date
    let bookings: [ParsedBooking]
    let destination: String
}
