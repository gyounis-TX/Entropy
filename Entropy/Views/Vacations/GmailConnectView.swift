import SwiftUI

struct GmailConnectView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(GmailScanService.self) private var gmailService
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var scanResults: [ParsedBooking] = []
    @State private var suggestedTrips: [SuggestedTrip] = []

    var body: some View {
        List {
            if !appState.isGmailConnected {
                connectSection
            } else {
                statusSection
                if !scanResults.isEmpty {
                    detectedBookingsSection
                }
                if !suggestedTrips.isEmpty {
                    suggestedTripsSection
                }
                disconnectSection
            }
        }
        .navigationTitle("Gmail Scanning")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: - Connect

    private var connectSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Auto-Detect Travel Bookings")
                    .font(.headline)

                Text("Connect your Gmail account to automatically detect flights, hotels, Airbnb stays, train tickets, car rentals, and cancellations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    Task { await connectGmail() }
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("Sign in with Google")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting)

                if isConnecting {
                    ProgressView("Connecting...")
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text("Read-only access — Entropy never modifies or deletes your emails.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section("Scanning Status") {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Gmail Connected")
                Spacer()
                if gmailService.isScanning {
                    ProgressView()
                }
            }

            if let lastScan = gmailService.lastScanDate {
                LabeledContent("Last Scan") {
                    Text(lastScan, style: .relative)
                }
            }

            Button("Scan Now", systemImage: "arrow.clockwise") {
                Task { await performScan() }
            }
            .disabled(gmailService.isScanning)
        }
    }

    // MARK: - Detected Bookings

    private var detectedBookingsSection: some View {
        Section("Detected Bookings (\(scanResults.count))") {
            ForEach(scanResults) { booking in
                NavigationLink {
                    BookingReviewView(booking: booking, gmailService: gmailService)
                } label: {
                    HStack {
                        Image(systemName: iconForCategory(booking.category))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text(booking.provider)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(booking.sourceEmailSubject)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if booking.isCancellation {
                            Text("CANCELLED")
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .fontWeight(.bold)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Suggested Trips

    private var suggestedTripsSection: some View {
        Section("Suggested Trips") {
            ForEach(suggestedTrips) { suggestion in
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.suggestedName)
                        .font(.headline)
                    Text("\(suggestion.bookings.count) bookings detected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(formatted(suggestion.startDate)) – \(formatted(suggestion.endDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Disconnect

    private var disconnectSection: some View {
        Section {
            Button("Disconnect Gmail", role: .destructive) {
                gmailService.disconnect()
                appState.isGmailConnected = false
                VaultSecurityService.shared.clearGmailTokens()
                scanResults = []
                suggestedTrips = []
            }
        }
    }

    // MARK: - Actions

    private func connectGmail() async {
        isConnecting = true
        errorMessage = nil
        defer { isConnecting = false }

        // In production, this opens the Google OAuth2 flow via ASWebAuthenticationSession.
        // For now, set a placeholder state.
        errorMessage = "OAuth flow requires a configured Google Cloud project. Set up your client ID in the app configuration."
    }

    private func performScan() async {
        do {
            scanResults = try await gmailService.scanForBookings()
            suggestedTrips = gmailService.suggestTrips()
            appState.gmailScanStatus = .found(scanResults.count)
        } catch {
            appState.gmailScanStatus = .error(error.localizedDescription)
        }
    }

    private func iconForCategory(_ category: BookingCategory) -> String {
        switch category {
        case .flight: return "airplane"
        case .hotel: return "bed.double.fill"
        case .shortTermRental: return "house.fill"
        case .train: return "tram.fill"
        case .carRental: return "car.fill"
        }
    }

    private func formatted(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: date)
    }
}
