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

    init(category: BookingCategory, provider: String, confirmationNumber: String,
         startDate: Date, endDate: Date? = nil, details: BookingDetails,
         sourceEmailID: String, sourceEmailSubject: String, isCancellation: Bool = false) {
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
    }
}

enum BookingDetails: Codable {
    case flight(FlightDetails)
    case hotel(HotelDetails)
    case rental(RentalDetails)
    case train(TrainDetails)
    case carRental(CarRentalDetails)
}

struct FlightDetails: Codable {
    let airline: String
    let flightNumber: String
    let departureAirport: String
    let arrivalAirport: String
    let departureDateTime: Date
    let arrivalDateTime: Date
    let seatAssignment: String?
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
