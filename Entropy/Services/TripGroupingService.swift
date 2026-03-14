import Foundation

/// Groups parsed bookings into suggested trips when they fall within the same date window.
final class TripGroupingService {

    /// Maximum days between bookings to consider them part of the same trip.
    private let maxGapDays: Int = 3

    /// Groups bookings that overlap or are close in time into suggested trips.
    func groupBookings(_ bookings: [ParsedBooking]) -> [SuggestedTrip] {
        guard !bookings.isEmpty else { return [] }

        // Sort by start date
        let sorted = bookings.sorted { $0.startDate < $1.startDate }

        var groups: [[ParsedBooking]] = []
        var currentGroup: [ParsedBooking] = [sorted[0]]
        var currentEnd = sorted[0].endDate ?? sorted[0].startDate

        for booking in sorted.dropFirst() {
            let gapDays = Calendar.current.dateComponents(
                [.day], from: currentEnd, to: booking.startDate
            ).day ?? Int.max

            if gapDays <= maxGapDays {
                // This booking overlaps or is close to the current group
                currentGroup.append(booking)
                if let end = booking.endDate, end > currentEnd {
                    currentEnd = end
                }
            } else {
                // Start a new group
                groups.append(currentGroup)
                currentGroup = [booking]
                currentEnd = booking.endDate ?? booking.startDate
            }
        }
        groups.append(currentGroup)

        // Only suggest trips for groups with 2+ bookings
        return groups
            .filter { $0.count >= 2 }
            .map { makeSuggestedTrip(from: $0) }
    }

    private func makeSuggestedTrip(from bookings: [ParsedBooking]) -> SuggestedTrip {
        let startDate = bookings.map(\.startDate).min() ?? Date()
        let endDate = bookings.compactMap(\.endDate).max() ?? startDate

        let destination = inferDestination(from: bookings)
        let name = suggestTripName(destination: destination, startDate: startDate)

        return SuggestedTrip(
            suggestedName: name,
            startDate: startDate,
            endDate: endDate,
            bookings: bookings,
            destination: destination
        )
    }

    /// Infers the destination from flight arrival airports, hotel locations, etc.
    private func inferDestination(from bookings: [ParsedBooking]) -> String {
        // Try to get destination from flight arrivals first
        for booking in bookings {
            if case .flight(let details) = booking.details {
                return details.arrivalAirport
            }
        }

        // Try hotel/rental location
        for booking in bookings {
            switch booking.details {
            case .hotel(let details):
                if !details.address.isEmpty { return details.address }
                return details.hotelName
            case .rental(let details):
                if !details.address.isEmpty { return details.address }
                return details.propertyName
            case .train(let details):
                return details.arrivalStation
            case .carRental(let details):
                return details.pickupLocation
            default:
                continue
            }
        }

        return "Trip"
    }

    /// Generates a suggested trip name like "Miami June 12–18".
    private func suggestTripName(destination: String, startDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return "\(destination) \(formatter.string(from: startDate))"
    }
}
