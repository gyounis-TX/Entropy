import Foundation
import AuthenticationServices
import SwiftData

/// Manages Gmail OAuth2 connection and periodic scanning for travel-related emails.
@Observable
final class GmailScanService {
    private(set) var isConnected = false
    private(set) var isScanning = false
    private(set) var lastScanDate: Date?
    private(set) var pendingBookings: [ParsedBooking] = []

    private var accessToken: String?
    private var refreshToken: String?
    private let bookingParser = BookingParser()
    private let tripGrouper = TripGroupingService()

    // Gmail API read-only scope
    static let gmailReadOnlyScope = "https://www.googleapis.com/auth/gmail.readonly"

    // Known travel provider domains for Gmail query filtering
    static let travelProviderDomains: [String] = [
        // Airlines
        "united.com", "delta.com", "aa.com", "americanairlines.com",
        "southwest.com", "jetblue.com", "spirit.com", "alaskaair.com",
        "hawaiianairlines.com", "frontier.com",
        // International airlines
        "britishairways.com", "lufthansa.com", "airfrance.com", "emirates.com",
        "cathaypacific.com", "singaporeair.com", "qantas.com",
        // Hotels
        "marriott.com", "hilton.com", "hyatt.com", "ihg.com",
        "booking.com", "hotels.com", "expedia.com", "priceline.com",
        // Short-term rentals
        "airbnb.com", "vrbo.com", "vacasa.com",
        // Trains
        "amtrak.com", "thetrainline.com", "eurostar.com",
        // Car rentals
        "hertz.com", "enterprise.com", "avis.com", "budget.com", "turo.com",
        "nationalcar.com"
    ]

    static let subjectKeywords = [
        "confirmation", "itinerary", "booking", "reservation",
        "e-ticket", "receipt", "cancellation", "cancelled", "canceled"
    ]

    /// Build the Gmail search query to find travel emails.
    var gmailSearchQuery: String {
        let fromClause = Self.travelProviderDomains
            .map { "from:\($0)" }
            .joined(separator: " OR ")
        let subjectClause = Self.subjectKeywords
            .map { "subject:\($0)" }
            .joined(separator: " OR ")
        return "(\(fromClause)) (\(subjectClause))"
    }

    // MARK: - OAuth2 Connection

    /// Initiates Google OAuth2 sign-in flow for Gmail read-only access.
    /// In production, this would use ASWebAuthenticationSession or GoogleSignIn SDK.
    func connect(clientID: String, presentingWindow: Any? = nil) async throws {
        // Build OAuth2 authorization URL
        let authURL = buildAuthURL(clientID: clientID)

        // In a real implementation:
        // 1. Present ASWebAuthenticationSession with authURL
        // 2. Handle the callback to extract the authorization code
        // 3. Exchange the code for access + refresh tokens
        // 4. Store tokens securely in Keychain

        // Placeholder for OAuth flow — actual implementation requires
        // ASWebAuthenticationSession which needs a UI context
        _ = authURL
        throw GmailError.notImplemented("OAuth flow requires UI presentation context")
    }

    /// Stores tokens after successful OAuth2 flow.
    func setTokens(access: String, refresh: String) {
        self.accessToken = access
        self.refreshToken = refresh
        self.isConnected = true
        // In production: store in Keychain via VaultSecurityService
    }

    func disconnect() {
        accessToken = nil
        refreshToken = nil
        isConnected = false
        pendingBookings = []
    }

    // MARK: - Email Scanning

    /// Scans Gmail for new travel-related emails since the last scan.
    func scanForBookings() async throws -> [ParsedBooking] {
        guard isConnected, let token = accessToken else {
            throw GmailError.notConnected
        }

        isScanning = true
        defer { isScanning = false }

        // 1. Query Gmail API for matching emails
        let emails = try await fetchTravelEmails(token: token)

        // 2. Parse each email into structured booking data
        var newBookings: [ParsedBooking] = []
        for email in emails {
            if let booking = try? await bookingParser.parse(email: email) {
                newBookings.append(booking)
            }
        }

        // 3. Filter out already-processed emails
        let existingIDs = Set(pendingBookings.map(\.sourceEmailID))
        let freshBookings = newBookings.filter { !existingIDs.contains($0.sourceEmailID) }

        pendingBookings.append(contentsOf: freshBookings)
        lastScanDate = Date()

        return freshBookings
    }

    /// Checks for cancellation emails and matches them to existing bookings.
    func checkForCancellations(existingBookings: [ParsedBooking]) async throws -> [ParsedBooking] {
        let allBookings = try await scanForBookings()
        return allBookings.filter { $0.isCancellation }
    }

    /// Suggests trip groupings from pending bookings.
    func suggestTrips() -> [SuggestedTrip] {
        tripGrouper.groupBookings(pendingBookings)
    }

    /// Commits a parsed booking into SwiftData as a real Flight/Accommodation/Reservation.
    func commitBooking(_ booking: ParsedBooking, to trip: Trip, context: ModelContext) {
        switch booking.details {
        case .flight(let details):
            let flight = Flight(
                airline: details.airline,
                flightNumber: details.flightNumber,
                departureAirport: details.departureAirport,
                arrivalAirport: details.arrivalAirport,
                departureDateTime: details.departureDateTime,
                arrivalDateTime: details.arrivalDateTime,
                confirmationCode: booking.confirmationNumber
            )
            flight.seatAssignment = details.seatAssignment
            flight.sourceEmail = booking.sourceEmailID
            flight.trip = trip
            context.insert(flight)

        case .hotel(let details):
            let acc = Accommodation(
                hotelName: details.hotelName,
                address: details.address,
                checkIn: details.checkIn,
                checkOut: details.checkOut,
                confirmationNumber: booking.confirmationNumber
            )
            acc.sourceEmail = booking.sourceEmailID
            acc.trip = trip
            context.insert(acc)

        case .rental(let details):
            let acc = Accommodation(
                hotelName: details.propertyName,
                address: details.address,
                checkIn: details.checkIn,
                checkOut: details.checkOut,
                confirmationNumber: booking.confirmationNumber
            )
            acc.notes = details.hostName.map { "Host: \($0)" } ?? ""
            acc.sourceEmail = booking.sourceEmailID
            acc.trip = trip
            context.insert(acc)

        case .train(let details):
            let reservation = Reservation(
                type: .train,
                name: "\(details.departureStation) → \(details.arrivalStation)",
                location: details.route,
                dateTime: details.departureDateTime
            )
            reservation.endDateTime = details.arrivalDateTime
            reservation.confirmationNumber = booking.confirmationNumber
            reservation.sourceEmail = booking.sourceEmailID
            reservation.trip = trip
            context.insert(reservation)

        case .carRental(let details):
            let reservation = Reservation(
                type: .carRental,
                name: details.company,
                location: details.pickupLocation,
                dateTime: details.pickupDateTime
            )
            reservation.endDateTime = details.dropoffDateTime
            reservation.confirmationNumber = booking.confirmationNumber
            reservation.sourceEmail = booking.sourceEmailID
            reservation.trip = trip
            context.insert(reservation)
        }

        // Remove from pending
        pendingBookings.removeAll { $0.id == booking.id }
        trip.updatedAt = Date()
        try? context.save()
    }

    /// Marks an existing booking as cancelled by matching confirmation number.
    func applyCancellation(_ cancellation: ParsedBooking, context: ModelContext) throws {
        let confirmNum = cancellation.confirmationNumber

        // Check flights
        let flightDescriptor = FetchDescriptor<Flight>(
            predicate: #Predicate { $0.confirmationCode == confirmNum }
        )
        if let flight = try context.fetch(flightDescriptor).first {
            flight.isCancelled = true
            try context.save()
            return
        }

        // Check accommodations
        let accDescriptor = FetchDescriptor<Accommodation>(
            predicate: #Predicate { $0.confirmationNumber == confirmNum }
        )
        if let acc = try context.fetch(accDescriptor).first {
            acc.trip?.status = .cancelled
            try context.save()
            return
        }

        // Check reservations
        let resDescriptor = FetchDescriptor<Reservation>(
            predicate: #Predicate { $0.confirmationNumber == confirmNum }
        )
        if let res = try context.fetch(resDescriptor).first {
            res.isCancelled = true
            try context.save()
            return
        }

        throw GmailError.bookingNotFound(confirmNum)
    }

    // MARK: - Gmail API

    private func fetchTravelEmails(token: String) async throws -> [GmailMessage] {
        let query = gmailSearchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let afterDate = lastScanDate.map { ISO8601DateFormatter().string(from: $0) }

        var urlString = "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=\(query)"
        if let after = afterDate {
            urlString += "%20after:\(after)"
        }
        urlString += "&maxResults=50"

        guard let url = URL(string: urlString) else {
            throw GmailError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 401 {
            throw GmailError.tokenExpired
        }

        guard httpResponse.statusCode == 200 else {
            throw GmailError.networkError("HTTP \(httpResponse.statusCode)")
        }

        let listResponse = try JSONDecoder().decode(GmailListResponse.self, from: data)

        // Fetch full message content for each message ID
        var messages: [GmailMessage] = []
        for messageRef in (listResponse.messages ?? []) {
            if let fullMessage = try? await fetchFullMessage(id: messageRef.id, token: token) {
                messages.append(fullMessage)
            }
        }

        return messages
    }

    private func fetchFullMessage(id: String, token: String) async throws -> GmailMessage {
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?format=full") else {
            throw GmailError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(GmailMessage.self, from: data)
    }

    private func buildAuthURL(clientID: String) -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: "com.entropy.app:/oauth2callback"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.gmailReadOnlyScope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url!
    }
}

// MARK: - Gmail API Response Types

struct GmailListResponse: Codable {
    let messages: [GmailMessageRef]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

struct GmailMessageRef: Codable {
    let id: String
    let threadId: String
}

struct GmailMessage: Codable {
    let id: String
    let threadId: String
    let snippet: String?
    let payload: GmailPayload?

    var subject: String? {
        payload?.headers?.first(where: { $0.name.lowercased() == "subject" })?.value
    }

    var from: String? {
        payload?.headers?.first(where: { $0.name.lowercased() == "from" })?.value
    }

    var bodyText: String? {
        // Try to get plain text body, fall back to HTML
        if let parts = payload?.parts {
            let textPart = parts.first(where: { $0.mimeType == "text/plain" })
            if let encoded = textPart?.body?.data {
                return decodeBase64URL(encoded)
            }
            let htmlPart = parts.first(where: { $0.mimeType == "text/html" })
            if let encoded = htmlPart?.body?.data {
                return decodeBase64URL(encoded)
            }
        }
        // Single-part message
        if let encoded = payload?.body?.data {
            return decodeBase64URL(encoded)
        }
        return snippet
    }

    private func decodeBase64URL(_ input: String) -> String? {
        var base64 = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct GmailPayload: Codable {
    let mimeType: String?
    let headers: [GmailHeader]?
    let body: GmailBody?
    let parts: [GmailPart]?
}

struct GmailHeader: Codable {
    let name: String
    let value: String
}

struct GmailBody: Codable {
    let data: String?
    let size: Int?
}

struct GmailPart: Codable {
    let mimeType: String?
    let body: GmailBody?
    let parts: [GmailPart]?
}

// MARK: - Errors

enum GmailError: Error, LocalizedError {
    case notConnected
    case tokenExpired
    case invalidURL
    case networkError(String)
    case bookingNotFound(String)
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Gmail is not connected. Please sign in."
        case .tokenExpired: return "Gmail session expired. Please reconnect."
        case .invalidURL: return "Invalid Gmail API URL."
        case .networkError(let msg): return "Network error: \(msg)"
        case .bookingNotFound(let conf): return "No booking found with confirmation \(conf)"
        case .notImplemented(let msg): return msg
        }
    }
}
