import Foundation
import AuthenticationServices
import SwiftData

/// Manages Gmail OAuth2 connection and periodic scanning for travel-related emails.
@MainActor @Observable
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

    /// Initiates Google OAuth2 sign-in flow for Gmail read-only access
    /// using ASWebAuthenticationSession.
    @MainActor
    @discardableResult
    func connect(clientID: String) async throws -> (access: String, refresh: String) {
        guard let authURL = buildAuthURL(clientID: clientID) else {
            throw GmailError.invalidURL
        }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callback: .customScheme("com.entropy.app")
            ) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: GmailError.notConnected)
                }
            }
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        // Extract the authorization code from the callback URL
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw GmailError.networkError("No authorization code in callback")
        }

        // Exchange the code for tokens
        let tokens = try await exchangeCodeForTokens(code: code, clientID: clientID)
        setTokens(access: tokens.accessToken, refresh: tokens.refreshToken)
        return (tokens.accessToken, tokens.refreshToken)
    }

    /// Exchanges an authorization code for access and refresh tokens.
    private func exchangeCodeForTokens(code: String, clientID: String) async throws -> TokenResponse {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw GmailError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code=\(code)",
            "client_id=\(clientID)",
            "redirect_uri=com.entropy.app:/oauth2callback",
            "grant_type=authorization_code"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GmailError.networkError("Token exchange failed")
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    /// Refreshes an expired access token using the refresh token.
    func refreshAccessToken(clientID: String) async throws {
        guard let refreshToken else {
            throw GmailError.tokenExpired
        }

        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw GmailError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "refresh_token=\(refreshToken)",
            "client_id=\(clientID)",
            "grant_type=refresh_token"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GmailError.tokenExpired
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        self.accessToken = tokenResponse.accessToken
    }

    /// Stores tokens after successful OAuth2 flow.
    func setTokens(access: String, refresh: String) {
        self.accessToken = access
        self.refreshToken = refresh
        self.isConnected = true
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
    func checkForCancellations() async throws -> [ParsedBooking] {
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

        // Check accommodations — mark the accommodation's notes, not the entire trip
        let accDescriptor = FetchDescriptor<Accommodation>(
            predicate: #Predicate { $0.confirmationNumber == confirmNum }
        )
        if let acc = try context.fetch(accDescriptor).first {
            acc.notes = "[CANCELLED] \(acc.notes)"
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
        // Build URL using URLComponents for safe encoding
        var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
        var query = gmailSearchQuery
        if let lastScan = lastScanDate {
            // Gmail after: expects YYYY/MM/DD format
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd"
            query += " after:\(formatter.string(from: lastScan))"
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: "50")
        ]

        guard let url = components.url else {
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

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if httpResponse.statusCode == 401 {
                throw GmailError.tokenExpired
            }
            throw GmailError.networkError("HTTP \(httpResponse.statusCode) fetching message \(id)")
        }

        return try JSONDecoder().decode(GmailMessage.self, from: data)
    }

    private func buildAuthURL(clientID: String) -> URL? {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: "com.entropy.app:/oauth2callback"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.gmailReadOnlyScope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components?.url
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
        // Recursively search for text content in MIME parts
        if let parts = payload?.parts {
            if let text = findTextInParts(parts) {
                return text
            }
        }
        // Single-part message
        if let encoded = payload?.body?.data {
            return decodeBase64URL(encoded)
        }
        return snippet
    }

    private func findTextInParts(_ parts: [GmailPart]) -> String? {
        // Prefer text/plain, fall back to text/html
        for part in parts {
            if part.mimeType == "text/plain", let encoded = part.body?.data {
                return decodeBase64URL(encoded)
            }
            // Recurse into nested parts
            if let nested = part.parts, let text = findTextInParts(nested) {
                return text
            }
        }
        for part in parts {
            if part.mimeType == "text/html", let encoded = part.body?.data {
                return decodeBase64URL(encoded)
            }
            if let nested = part.parts, let text = findTextInParts(nested) {
                return text
            }
        }
        return nil
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

// MARK: - Token Response

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int?
    let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.accessToken = try container.decode(String.self, forKey: .accessToken)
        // refresh_token may not be present on token refresh (only on initial exchange)
        self.refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken) ?? ""
        self.expiresIn = try container.decodeIfPresent(Int.self, forKey: .expiresIn)
        self.tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType)
    }
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
