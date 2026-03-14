import Foundation
import SwiftData

/// Auto-generates pre-trip checklist items with relative reminders
/// based on the trip's bookings (flights, hotels, etc.).
final class TripChecklistGenerator {

    struct ChecklistTemplate {
        let title: String
        let daysBefore: Int  // days before the anchor date
        let anchor: Anchor
        let condition: Condition

        enum Anchor {
            case tripStart
            case firstFlight
            case firstHotel
            case tripEnd
        }

        enum Condition {
            case always
            case hasFlights
            case hasAccommodation
            case hasInternationalFlight
            case hasCarRental
            case tripLongerThan(days: Int)
        }
    }

    // MARK: - Template Library

    private let templates: [ChecklistTemplate] = [
        // General trip prep
        ChecklistTemplate(title: "Check passport expiration", daysBefore: 90, anchor: .tripStart, condition: .hasInternationalFlight),
        ChecklistTemplate(title: "Get travel insurance", daysBefore: 30, anchor: .tripStart, condition: .tripLongerThan(days: 3)),
        ChecklistTemplate(title: "Notify bank of travel dates", daysBefore: 7, anchor: .tripStart, condition: .always),
        ChecklistTemplate(title: "Check weather forecast", daysBefore: 5, anchor: .tripStart, condition: .always),
        ChecklistTemplate(title: "Pack bags", daysBefore: 2, anchor: .tripStart, condition: .always),
        ChecklistTemplate(title: "Charge devices & bring chargers", daysBefore: 1, anchor: .tripStart, condition: .always),
        ChecklistTemplate(title: "Download offline maps", daysBefore: 3, anchor: .tripStart, condition: .always),

        // Flight-specific
        ChecklistTemplate(title: "Select seats", daysBefore: 14, anchor: .firstFlight, condition: .hasFlights),
        ChecklistTemplate(title: "Check in for flight", daysBefore: 1, anchor: .firstFlight, condition: .hasFlights),
        ChecklistTemplate(title: "Save boarding pass", daysBefore: 1, anchor: .firstFlight, condition: .hasFlights),
        ChecklistTemplate(title: "Arrange airport transportation", daysBefore: 3, anchor: .firstFlight, condition: .hasFlights),

        // Accommodation-specific
        ChecklistTemplate(title: "Confirm hotel reservation", daysBefore: 3, anchor: .firstHotel, condition: .hasAccommodation),
        ChecklistTemplate(title: "Note check-in time and instructions", daysBefore: 2, anchor: .firstHotel, condition: .hasAccommodation),

        // Car rental
        ChecklistTemplate(title: "Print/save rental car confirmation", daysBefore: 2, anchor: .tripStart, condition: .hasCarRental),
        ChecklistTemplate(title: "Check rental car insurance coverage", daysBefore: 7, anchor: .tripStart, condition: .hasCarRental),
    ]

    // MARK: - Generation

    /// Generates checklist items for a trip based on its current bookings.
    /// Returns only new items (skips titles that already exist on the trip).
    func generateChecklist(for trip: Trip, context: ModelContext) -> [TripTodo] {
        let existingTitles = Set(trip.todoItems.map(\.title))
        var newTodos: [TripTodo] = []

        for template in templates {
            guard shouldInclude(template, for: trip) else { continue }
            guard !existingTitles.contains(template.title) else { continue }

            let anchorDate = anchorDate(for: template.anchor, trip: trip)
            let dueDate = Calendar.current.date(
                byAdding: .day,
                value: -template.daysBefore,
                to: anchorDate
            ) ?? anchorDate

            // Skip if the due date is already in the past
            guard dueDate > Date() else { continue }

            let todo = TripTodo(title: template.title, dueDate: dueDate)
            todo.trip = trip
            context.insert(todo)

            // Create a matching reminder
            let reminder = ReminderEngine.shared.createRelativeReminder(
                title: template.title,
                daysBefore: template.daysBefore,
                anchorDate: anchorDate,
                sourceType: .trip
            )
            reminder.trip = trip
            todo.reminder = reminder
            context.insert(reminder)

            newTodos.append(todo)
        }

        try? context.save()

        // Schedule all reminders after saving — collected to avoid fire-and-forget Tasks in the loop
        let remindersToSchedule = newTodos.compactMap(\.reminder)
        Task {
            for reminder in remindersToSchedule {
                await ReminderEngine.shared.schedule(reminder)
            }
        }

        return newTodos
    }

    // MARK: - Conditions

    private func shouldInclude(_ template: ChecklistTemplate, for trip: Trip) -> Bool {
        switch template.condition {
        case .always:
            return true
        case .hasFlights:
            return !trip.flights.isEmpty
        case .hasAccommodation:
            return !trip.accommodations.isEmpty
        case .hasInternationalFlight:
            return trip.flights.contains { isInternational($0) }
        case .hasCarRental:
            return trip.reservations.contains { $0.type == .carRental }
        case .tripLongerThan(let days):
            let tripDays = Calendar.current.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 0
            return tripDays > days
        }
    }

    private func anchorDate(for anchor: ChecklistTemplate.Anchor, trip: Trip) -> Date {
        switch anchor {
        case .tripStart:
            return trip.startDate
        case .firstFlight:
            return trip.flights
                .sorted(by: { $0.departureDateTime < $1.departureDateTime })
                .first?.departureDateTime ?? trip.startDate
        case .firstHotel:
            return trip.accommodations
                .sorted(by: { $0.checkIn < $1.checkIn })
                .first?.checkIn ?? trip.startDate
        case .tripEnd:
            return trip.endDate
        }
    }

    /// Known US domestic airport codes (IATA). A flight is international if either
    /// endpoint is not in this set. In production, use a full airport database.
    private static let knownDomesticAirports: Set<String> = [
        "ATL", "LAX", "ORD", "DFW", "DEN", "JFK", "SFO", "SEA", "LAS", "MCO",
        "EWR", "CLT", "PHX", "IAH", "MIA", "BOS", "MSP", "FLL", "DTW", "PHL",
        "LGA", "BWI", "SLC", "SAN", "IAD", "DCA", "MDW", "TPA", "PDX", "HNL",
        "STL", "BNA", "AUS", "OAK", "MSY", "RDU", "SJC", "SMF", "SNA", "CLE",
        "MKE", "PIT", "SAT", "IND", "CMH", "BDL", "RSW", "JAX", "OGG", "ABQ"
    ]

    /// A flight is international if either airport is not a known US domestic airport.
    /// Falls back to assuming domestic if both codes are unknown (conservative default).
    private func isInternational(_ flight: Flight) -> Bool {
        let dep = flight.departureAirport.uppercased()
        let arr = flight.arrivalAirport.uppercased()
        guard dep.count == 3, arr.count == 3 else { return false }
        let depKnown = Self.knownDomesticAirports.contains(dep)
        let arrKnown = Self.knownDomesticAirports.contains(arr)
        // If both are known domestic, it's domestic
        if depKnown && arrKnown { return false }
        // If one is known domestic and the other is unknown, assume international
        if depKnown || arrKnown { return true }
        // Both unknown — conservatively assume domestic
        return false
    }
}
