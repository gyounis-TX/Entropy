import Foundation

/// Parses Gmail messages into structured ParsedBooking objects.
/// Uses pattern matching and heuristics to extract booking data from email content.
/// In production, this would integrate with an LLM for more robust parsing.
final class BookingParser: Sendable {

    // MARK: - Provider Detection

    private struct ProviderPattern {
        let domains: [String]
        let category: BookingCategory
        let name: String
        /// True when this sender also issues hotel and/or car-rental confirmations,
        /// so the sender domain alone can't determine the booking category. Airline
        /// loyalty travel portals — notably United MileagePlus (MileagePlus Hotels,
        /// powered by Rocketmiles, and MileagePlus car rentals) — send flight, hotel,
        /// and car emails from the same domains. For these the category is resolved
        /// from the email content instead of the domain.
        let isMultiService: Bool
        /// Optional per-category display names for multi-service providers, e.g. a
        /// United hotel booking should be attributed to "United MileagePlus Hotels"
        /// rather than "United Airlines".
        let categoryNames: [BookingCategory: String]

        init(domains: [String], category: BookingCategory, name: String,
             isMultiService: Bool = false, categoryNames: [BookingCategory: String] = [:]) {
            self.domains = domains
            self.category = category
            self.name = name
            self.isMultiService = isMultiService
            self.categoryNames = categoryNames
        }
    }

    private let providers: [ProviderPattern] = [
        // Airlines
        ProviderPattern(
            domains: ["united.com", "mileageplus.com", "rocketmiles.com"],
            category: .flight,
            name: "United Airlines",
            isMultiService: true,
            categoryNames: [
                .hotel: "United MileagePlus Hotels",
                .carRental: "United MileagePlus Car Rentals"
            ]
        ),
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

        // Resolve the true booking category. For most senders this is the provider's
        // domain-based category, but multi-service loyalty portals (e.g. United
        // MileagePlus) send flight, hotel, and car emails from the same domain, so we
        // inspect the content to catalog those hotel/car bookings correctly.
        let category = resolveCategory(provider: provider, subject: subject, body: body)
        let providerName = provider.categoryNames[category] ?? provider.name

        // Extract confirmation number
        let confirmationNumber = extractConfirmationNumber(from: body, provider: providerName) ?? "Unknown"

        // Parse based on the resolved category
        let details: BookingDetails?
        let startDate: Date
        let endDate: Date?
        var additionalLegs: [FlightDetails] = []
        var returnOptions: [FlightDetails] = []

        switch category {
        case .flight:
            guard let itinerary = parseFlightItinerary(body: body, provider: providerName) else { return nil }
            details = .flight(itinerary.outbound)
            additionalLegs = itinerary.additionalLegs
            returnOptions = itinerary.returnOptions
            startDate = itinerary.outbound.departureDateTime
            // Span only the auto-committed legs; a chosen return widens the trip later.
            endDate = ([itinerary.outbound] + itinerary.additionalLegs)
                .map(\.arrivalDateTime).max() ?? itinerary.outbound.arrivalDateTime

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
            guard let car = parseCarRentalDetails(body: body, provider: providerName) else { return nil }
            details = .carRental(car)
            startDate = car.pickupDateTime
            endDate = car.dropoffDateTime
        }

        guard let bookingDetails = details else { return nil }

        return ParsedBooking(
            category: category,
            provider: providerName,
            confirmationNumber: confirmationNumber,
            startDate: startDate,
            endDate: endDate,
            details: bookingDetails,
            sourceEmailID: email.id,
            sourceEmailSubject: subject,
            isCancellation: isCancellation,
            additionalLegs: additionalLegs,
            returnOptions: returnOptions
        )
    }

    // MARK: - Provider Identification

    private func identifyProvider(from senderEmail: String) -> ProviderPattern? {
        let lowered = senderEmail.lowercased()
        return providers.first { provider in
            provider.domains.contains { lowered.contains($0) }
        }
    }

    // MARK: - Category Resolution

    /// Content signals that a booking is a hotel stay. Chosen to be hotel-distinct
    /// so they don't fire on flight emails (which often include "check in for your
    /// flight"); ambiguous terms are disambiguated by comparing against flight signals.
    private let hotelSignals = [
        "check-out", "check out", "checkout", "nights", "night stay",
        "room type", "guest room", "hotel reservation", "your stay",
        "property", "hotel"
    ]

    /// Content signals that a booking is a rental car.
    private let carSignals = [
        "car rental", "rental car", "pick-up location", "pickup location",
        "drop-off", "drop off", "dropoff", "vehicle", "car class",
        "rental car company", "rental location"
    ]

    /// Content signals that a booking is a flight, used to keep genuine flight
    /// emails from being reclassified when they happen to contain a stray hotel/car
    /// term (e.g. "online check-in").
    private let flightSignals = [
        "flight", "departure", "boarding", "gate", "e-ticket", "eticket",
        "nonstop", "layover", "airport", "flight number", "seat"
    ]

    /// Resolves the true booking category. For single-service senders this is just
    /// the provider's domain-based category. For multi-service senders (airline
    /// loyalty portals such as United MileagePlus) the domain can't distinguish a
    /// flight from a hotel or car booking, so we score the content and override the
    /// default only when hotel or car signals clearly dominate.
    private func resolveCategory(provider: ProviderPattern, subject: String, body: String) -> BookingCategory {
        guard provider.isMultiService else { return provider.category }

        let haystack = (subject + "\n" + body).lowercased()
        let score: ([String]) -> Int = { signals in
            signals.reduce(0) { $0 + (haystack.contains($1) ? 1 : 0) }
        }

        let hotelScore = score(hotelSignals)
        let carScore = score(carSignals)
        let flightScore = score(flightSignals)

        // Require a clear signal (>= 2) that also beats the flight signal before
        // overriding, so a normal flight itinerary is never mis-cataloged.
        if carScore >= 2 && carScore > flightScore && carScore >= hotelScore {
            return .carRental
        }
        if hotelScore >= 2 && hotelScore > flightScore && hotelScore > carScore {
            return .hotel
        }
        return provider.category
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
        // Case-insensitive patterns to match both upper and lowercase confirmation codes
        let patterns = [
            "confirmation[:\\s#]+([A-Za-z0-9]{5,10})",
            "booking reference[:\\s#]+([A-Za-z0-9]{5,10})",
            "confirmation number[:\\s#]+([A-Za-z0-9]{5,10})",
            "record locator[:\\s#]+([A-Za-z0-9]{5,8})",
            "reservation[:\\s#]+([A-Za-z0-9]{5,12})",
            "PNR[:\\s#]+([A-Za-z0-9]{6})"
        ]

        for pattern in patterns {
            if let match = body.range(of: pattern, options: [.regularExpression, .caseInsensitive], range: body.startIndex..<body.endIndex) {
                let matched = String(body[match])
                // Extract only the portion after the colon/separator to avoid matching keyword text
                let afterSeparator: String
                if let separatorRange = matched.range(of: "[:\\s#]+", options: .regularExpression) {
                    afterSeparator = String(matched[separatorRange.upperBound...])
                } else {
                    afterSeparator = matched
                }
                if let codeRange = afterSeparator.range(of: "[A-Za-z0-9]{5,12}", options: .regularExpression) {
                    return String(afterSeparator[codeRange]).uppercased()
                }
            }
        }

        return nil
    }

    // MARK: - Flight Itinerary Parsing

    /// The legs extracted from a flight email, split into what's committed
    /// automatically and what the traveler still has to choose between.
    private struct FlightItinerary {
        /// Primary outbound leg — always committed.
        let outbound: FlightDetails
        /// Other confirmed legs (multi-city forward segments, or a lone return) —
        /// committed automatically alongside the outbound.
        let additionalLegs: [FlightDetails]
        /// Alternative return flights (2+ candidates on the reverse route) that the
        /// traveler must pick between. Empty when there's no ambiguity.
        let returnOptions: [FlightDetails]
    }

    /// Parses a flight email into an itinerary. For a genuine multi-leg email it
    /// segments each leg individually; for a simple single-leg email it falls back to
    /// the single-flight heuristic so existing behavior is preserved.
    ///
    /// Classification: the earliest leg is the outbound. Legs flying the reverse route
    /// (back to the outbound's origin) are return candidates — a single one is treated
    /// as confirmed, but two or more become options the traveler chooses among (e.g.
    /// booking a return date you haven't committed to yet). Any remaining legs are
    /// treated as additional confirmed forward segments.
    private func parseFlightItinerary(body: String, provider: String) -> FlightItinerary? {
        let legs = extractFlightLegs(body: body, provider: provider)

        // Fewer than two structured legs → keep the proven single-flight path.
        guard legs.count >= 2 else {
            guard let single = parseFlightDetails(body: body, provider: provider) else { return nil }
            return FlightItinerary(outbound: single, additionalLegs: [], returnOptions: [])
        }

        let sorted = legs.sorted { $0.departureDateTime < $1.departureDateTime }
        let outbound = sorted[0]

        var additional: [FlightDetails] = []
        var returns: [FlightDetails] = []
        for leg in sorted.dropFirst() {
            let isReverseOfOutbound = leg.departureAirport == outbound.arrivalAirport
                && leg.arrivalAirport == outbound.departureAirport
            if isReverseOfOutbound {
                returns.append(leg)
            } else {
                additional.append(leg)
            }
        }

        // A single return isn't a real choice — commit it like any other leg.
        if returns.count == 1 {
            additional.append(returns.removeFirst())
        }

        additional.sort { $0.departureDateTime < $1.departureDateTime }
        returns.sort { $0.departureDateTime < $1.departureDateTime }
        return FlightItinerary(outbound: outbound, additionalLegs: additional, returnOptions: returns)
    }

    /// Extracts one `FlightDetails` per leg from a structured itinerary email.
    ///
    /// Legs are located by pairing consecutive airport codes in order of appearance
    /// (leg 1 = codes 0→1, leg 2 = codes 2→3, …). Each leg's flight number, dates, and
    /// seat are extracted from the text window between that leg's origin code and the
    /// next leg's origin code, which localizes extraction and avoids the single-flight
    /// parser's habit of globally grabbing "the first two dates in the whole email."
    /// Returns `[]` when the email isn't structured enough to segment (caller falls
    /// back to the single-leg heuristic).
    private func extractFlightLegs(body: String, provider: String) -> [FlightDetails] {
        let codes = airportCodeRanges(in: body)
        guard codes.count >= 2 else { return [] }

        var legs: [FlightDetails] = []
        var index = 0
        while index + 1 < codes.count {
            let dep = codes[index]
            let arr = codes[index + 1]
            let windowEnd = index + 2 < codes.count ? codes[index + 2].range.lowerBound : body.endIndex
            let window = String(body[dep.range.lowerBound..<windowEnd])

            let dates = extractDates(from: window)
            // Require a date to treat this as a real leg; skip malformed pairs.
            guard let departureDate = dates.first else { index += 2; continue }
            let arrivalDate = dates.count > 1 ? dates[1] : departureDate

            let flightNumber = extractFlightNumber(from: window) ?? "Unknown"
            let seat = extractFirstMatch(pattern: "seat[:\\s]+([0-9]{1,2}[a-f])", from: window.lowercased())?.uppercased()

            legs.append(FlightDetails(
                airline: provider,
                flightNumber: flightNumber,
                departureAirport: dep.code,
                arrivalAirport: arr.code,
                departureDateTime: departureDate,
                arrivalDateTime: arrivalDate,
                seatAssignment: seat
            ))
            index += 2
        }
        return legs
    }

    /// Finds likely IATA airport codes and their positions, in order of appearance.
    private func airportCodeRanges(in text: String) -> [(code: String, range: Range<String.Index>)] {
        guard let regex = try? NSRegularExpression(pattern: "\\b([A-Z]{3})\\b") else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        var result: [(code: String, range: Range<String.Index>)] = []
        for match in regex.matches(in: text, range: nsRange) {
            guard let range = Range(match.range(at: 1), in: text) else { continue }
            let code = String(text[range])
            if isLikelyAirportCode(code) {
                result.append((code, range))
            }
        }
        return result
    }

    /// Extracts a flight number like "UA 1234" / "DL567", normalized without spaces.
    private func extractFlightNumber(from text: String) -> String? {
        guard let match = text.range(of: "([A-Z]{2})\\s*(\\d{1,4})", options: .regularExpression) else {
            return nil
        }
        return String(text[match]).replacingOccurrences(of: " ", with: "")
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
        let seatPattern = "seat[:\\s]+([0-9]{1,2}[a-f])"
        let seat = extractFirstMatch(pattern: seatPattern, from: body.lowercased())?.uppercased()

        // Require at least one extracted date to avoid returning junk data
        if dates.isEmpty && flightNumber == "Unknown" {
            return nil
        }

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

        let seatPattern = "seat[:\\s]+([0-9]+[a-zA-Z]?)"
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
        for keyword in keywords {
            guard let range = text.range(of: keyword, options: .caseInsensitive) else { continue }
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
