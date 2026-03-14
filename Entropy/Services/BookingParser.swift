import Foundation

/// Parses Gmail messages into structured ParsedBooking objects.
/// Uses pattern matching and heuristics to extract booking data from email content.
/// In production, this would integrate with an LLM for more robust parsing.
final class BookingParser {

    // MARK: - Provider Detection

    private struct ProviderPattern {
        let domains: [String]
        let category: BookingCategory
        let name: String
    }

    private let providers: [ProviderPattern] = [
        // Airlines
        ProviderPattern(domains: ["united.com"], category: .flight, name: "United Airlines"),
        ProviderPattern(domains: ["delta.com"], category: .flight, name: "Delta Air Lines"),
        ProviderPattern(domains: ["aa.com", "americanairlines.com"], category: .flight, name: "American Airlines"),
        ProviderPattern(domains: ["southwest.com"], category: .flight, name: "Southwest Airlines"),
        ProviderPattern(domains: ["jetblue.com"], category: .flight, name: "JetBlue"),
        ProviderPattern(domains: ["spirit.com"], category: .flight, name: "Spirit Airlines"),
        ProviderPattern(domains: ["alaskaair.com"], category: .flight, name: "Alaska Airlines"),
        ProviderPattern(domains: ["britishairways.com"], category: .flight, name: "British Airways"),
        ProviderPattern(domains: ["lufthansa.com"], category: .flight, name: "Lufthansa"),
        ProviderPattern(domains: ["emirates.com"], category: .flight, name: "Emirates"),
        // Hotels
        ProviderPattern(domains: ["marriott.com"], category: .hotel, name: "Marriott"),
        ProviderPattern(domains: ["hilton.com"], category: .hotel, name: "Hilton"),
        ProviderPattern(domains: ["hyatt.com"], category: .hotel, name: "Hyatt"),
        ProviderPattern(domains: ["ihg.com"], category: .hotel, name: "IHG"),
        ProviderPattern(domains: ["booking.com"], category: .hotel, name: "Booking.com"),
        ProviderPattern(domains: ["hotels.com"], category: .hotel, name: "Hotels.com"),
        // Short-term rentals
        ProviderPattern(domains: ["airbnb.com"], category: .shortTermRental, name: "Airbnb"),
        ProviderPattern(domains: ["vrbo.com"], category: .shortTermRental, name: "VRBO"),
        ProviderPattern(domains: ["vacasa.com"], category: .shortTermRental, name: "Vacasa"),
        // Trains
        ProviderPattern(domains: ["amtrak.com"], category: .train, name: "Amtrak"),
        ProviderPattern(domains: ["thetrainline.com"], category: .train, name: "Trainline"),
        ProviderPattern(domains: ["eurostar.com"], category: .train, name: "Eurostar"),
        // Car rentals
        ProviderPattern(domains: ["hertz.com"], category: .carRental, name: "Hertz"),
        ProviderPattern(domains: ["enterprise.com"], category: .carRental, name: "Enterprise"),
        ProviderPattern(domains: ["avis.com"], category: .carRental, name: "Avis"),
        ProviderPattern(domains: ["budget.com"], category: .carRental, name: "Budget"),
        ProviderPattern(domains: ["turo.com"], category: .carRental, name: "Turo"),
    ]

    // MARK: - Parsing

    func parse(email: GmailMessage) async throws -> ParsedBooking? {
        guard let from = email.from,
              let subject = email.subject,
              let body = email.bodyText else {
            return nil
        }

        // Identify the provider
        guard let provider = identifyProvider(from: from) else {
            return nil
        }

        let isCancellation = detectCancellation(subject: subject, body: body)

        // Extract confirmation number
        let confirmationNumber = extractConfirmationNumber(from: body, provider: provider.name) ?? "Unknown"

        // Parse based on category
        let details: BookingDetails?
        let startDate: Date
        let endDate: Date?

        switch provider.category {
        case .flight:
            guard let flight = parseFlightDetails(body: body, provider: provider.name) else { return nil }
            details = .flight(flight)
            startDate = flight.departureDateTime
            endDate = flight.arrivalDateTime

        case .hotel:
            guard let hotel = parseHotelDetails(body: body) else { return nil }
            details = .hotel(hotel)
            startDate = hotel.checkIn
            endDate = hotel.checkOut

        case .shortTermRental:
            guard let rental = parseRentalDetails(body: body) else { return nil }
            details = .rental(rental)
            startDate = rental.checkIn
            endDate = rental.checkOut

        case .train:
            guard let train = parseTrainDetails(body: body) else { return nil }
            details = .train(train)
            startDate = train.departureDateTime
            endDate = train.arrivalDateTime

        case .carRental:
            guard let car = parseCarRentalDetails(body: body, provider: provider.name) else { return nil }
            details = .carRental(car)
            startDate = car.pickupDateTime
            endDate = car.dropoffDateTime
        }

        guard let bookingDetails = details else { return nil }

        return ParsedBooking(
            category: provider.category,
            provider: provider.name,
            confirmationNumber: confirmationNumber,
            startDate: startDate,
            endDate: endDate,
            details: bookingDetails,
            sourceEmailID: email.id,
            sourceEmailSubject: subject,
            isCancellation: isCancellation
        )
    }

    // MARK: - Provider Identification

    private func identifyProvider(from senderEmail: String) -> ProviderPattern? {
        let lowered = senderEmail.lowercased()
        return providers.first { provider in
            provider.domains.contains { lowered.contains($0) }
        }
    }

    // MARK: - Cancellation Detection

    private func detectCancellation(subject: String, body: String) -> Bool {
        let cancellationKeywords = [
            "cancellation", "cancelled", "canceled", "cancel confirmation",
            "booking cancelled", "reservation cancelled", "flight cancelled",
            "your trip has been cancelled"
        ]
        let combined = (subject + " " + body).lowercased()
        return cancellationKeywords.contains { combined.contains($0) }
    }

    // MARK: - Confirmation Number Extraction

    private func extractConfirmationNumber(from body: String, provider: String) -> String? {
        let patterns = [
            "confirmation[:\\s#]+([A-Z0-9]{5,10})",
            "booking reference[:\\s#]+([A-Z0-9]{5,10})",
            "confirmation number[:\\s#]+([A-Z0-9]{5,10})",
            "record locator[:\\s#]+([A-Z0-9]{5,8})",
            "reservation[:\\s#]+([A-Z0-9]{5,12})",
            "PNR[:\\s#]+([A-Z0-9]{6})"
        ]

        for pattern in patterns {
            if let match = body.range(of: pattern, options: .regularExpression, range: body.startIndex..<body.endIndex) {
                let matched = String(body[match])
                // Extract just the code part
                if let codeRange = matched.range(of: "[A-Z0-9]{5,12}", options: .regularExpression) {
                    return String(matched[codeRange])
                }
            }
        }

        return nil
    }

    // MARK: - Detail Parsers

    /// In production, these would use an LLM to extract structured data from email HTML/text.
    /// These regex-based parsers handle common email formats as a baseline.

    private func parseFlightDetails(body: String, provider: String) -> FlightDetails? {
        // Extract flight number pattern (e.g., "UA 1234", "DL 567")
        let flightNumPattern = "([A-Z]{2})\\s*(\\d{1,4})"
        let flightNumber: String
        let airline = provider

        if let match = body.range(of: flightNumPattern, options: .regularExpression) {
            flightNumber = String(body[match]).replacingOccurrences(of: " ", with: "")
        } else {
            flightNumber = "Unknown"
        }

        // Extract airport codes (3-letter IATA codes)
        let airportPattern = "\\b([A-Z]{3})\\b"
        let airports = extractAllMatches(pattern: airportPattern, from: body)
            .filter { isLikelyAirportCode($0) }
        let departure = airports.first ?? "???"
        let arrival = airports.count > 1 ? airports[1] : "???"

        // Extract dates — simplified; production would use LLM
        let dates = extractDates(from: body)
        let departureDate = dates.first ?? Date()
        let arrivalDate = dates.count > 1 ? dates[1] : departureDate

        // Extract seat
        let seatPattern = "seat[:\\s]+([0-9]{1,2}[A-F])"
        let seat = extractFirstMatch(pattern: seatPattern, from: body.lowercased())?.uppercased()

        return FlightDetails(
            airline: airline,
            flightNumber: flightNumber,
            departureAirport: departure,
            arrivalAirport: arrival,
            departureDateTime: departureDate,
            arrivalDateTime: arrivalDate,
            seatAssignment: seat
        )
    }

    private func parseHotelDetails(body: String) -> HotelDetails? {
        let dates = extractDates(from: body)
        guard dates.count >= 2 else { return nil }

        // Simplified extraction — production uses LLM
        let hotelName = extractAfterKeyword(["hotel", "property", "stay at"], in: body) ?? "Hotel"
        let address = extractAfterKeyword(["address", "located at"], in: body) ?? ""

        return HotelDetails(
            hotelName: hotelName,
            address: address,
            checkIn: dates[0],
            checkOut: dates[1]
        )
    }

    private func parseRentalDetails(body: String) -> RentalDetails? {
        let dates = extractDates(from: body)
        guard dates.count >= 2 else { return nil }

        let propertyName = extractAfterKeyword(["property", "listing", "stay"], in: body) ?? "Rental"
        let address = extractAfterKeyword(["address", "located"], in: body) ?? ""
        let host = extractAfterKeyword(["host", "hosted by"], in: body)

        return RentalDetails(
            propertyName: propertyName,
            address: address,
            checkIn: dates[0],
            checkOut: dates[1],
            hostName: host
        )
    }

    private func parseTrainDetails(body: String) -> TrainDetails? {
        let dates = extractDates(from: body)
        guard let departureDate = dates.first else { return nil }
        let arrivalDate = dates.count > 1 ? dates[1] : departureDate

        let departure = extractAfterKeyword(["departs", "from", "departure"], in: body) ?? "Origin"
        let arrival = extractAfterKeyword(["arrives", "to", "arrival", "destination"], in: body) ?? "Destination"

        let seatPattern = "seat[:\\s]+([0-9]+[A-Z]?)"
        let seat = extractFirstMatch(pattern: seatPattern, from: body.lowercased())
        let carPattern = "car[:\\s]+([0-9]+)"
        let car = extractFirstMatch(pattern: carPattern, from: body.lowercased())

        return TrainDetails(
            route: "\(departure) → \(arrival)",
            departureStation: departure,
            arrivalStation: arrival,
            departureDateTime: departureDate,
            arrivalDateTime: arrivalDate,
            seatAssignment: seat,
            carNumber: car
        )
    }

    private func parseCarRentalDetails(body: String, provider: String) -> CarRentalDetails? {
        let dates = extractDates(from: body)
        guard dates.count >= 2 else { return nil }

        let pickup = extractAfterKeyword(["pick up", "pickup", "pick-up"], in: body) ?? "Pickup Location"
        let dropoff = extractAfterKeyword(["drop off", "dropoff", "drop-off", "return"], in: body) ?? pickup

        return CarRentalDetails(
            company: provider,
            pickupLocation: pickup,
            dropoffLocation: dropoff,
            pickupDateTime: dates[0],
            dropoffDateTime: dates[1]
        )
    }

    // MARK: - Regex Helpers

    private func extractAllMatches(pattern: String, from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    private func extractFirstMatch(pattern: String, from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }

    private func extractAfterKeyword(_ keywords: [String], in text: String) -> String? {
        let lowered = text.lowercased()
        for keyword in keywords {
            guard let range = lowered.range(of: keyword) else { continue }
            let after = text[range.upperBound...]
                .trimmingCharacters(in: .whitespaces.union(.punctuationCharacters))
            // Take the rest of the line
            if let lineEnd = after.firstIndex(of: "\n") {
                let result = String(after[after.startIndex..<lineEnd]).trimmingCharacters(in: .whitespaces)
                if !result.isEmpty { return result }
            } else {
                let result = String(after.prefix(100)).trimmingCharacters(in: .whitespaces)
                if !result.isEmpty { return result }
            }
        }
        return nil
    }

    private func extractDates(from text: String) -> [Date] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector?.matches(in: text, range: range) ?? []
        return matches.compactMap(\.date).sorted()
    }

    private func isLikelyAirportCode(_ code: String) -> Bool {
        let commonNonAirports = Set(["THE", "AND", "FOR", "ARE", "NOT", "YOU", "ALL", "CAN", "HER",
                                      "WAS", "ONE", "OUR", "OUT", "HAS", "HIS", "HOW", "MAN", "NEW"])
        return !commonNonAirports.contains(code)
    }
}
