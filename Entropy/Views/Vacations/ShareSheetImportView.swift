import SwiftUI
import SwiftData

/// View for reviewing a booking parsed from a shared email (Share sheet fallback).
struct ShareSheetImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Trip.startDate) private var trips: [Trip]

    @State private var parsedBooking: ParsedBooking?
    @State private var isParsing = true
    @State private var parseError: String?
    @State private var selectedTrip: Trip?
    @State private var showingNewTrip = false

    let sharedText: String
    let sharedHTML: String?

    private let parser = ShareSheetParser()

    var body: some View {
        Group {
            if isParsing {
                parsingView
            } else if let booking = parsedBooking {
                bookingResultView(booking)
            } else {
                errorView
            }
        }
        .navigationTitle("Import Booking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .task { await parseContent() }
        .sheet(isPresented: $showingNewTrip) {
            NavigationStack {
                AddTripView()
            }
        }
    }

    private var parsingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Parsing email for travel bookings...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func bookingResultView(_ booking: ParsedBooking) -> some View {
        List {
            Section("Detected Booking") {
                LabeledContent("Provider") { Text(booking.provider) }
                LabeledContent("Type") { Text(booking.category.rawValue.capitalized) }
                LabeledContent("Confirmation") {
                    Text(booking.confirmationNumber)
                        .fontDesign(.monospaced)
                }
                LabeledContent("Date") { Text(booking.startDate, style: .date) }
            }

            Section("Add to Trip") {
                if trips.isEmpty {
                    Button("Create New Trip") { showingNewTrip = true }
                        .buttonStyle(.borderedProminent)
                } else {
                    Picker("Trip", selection: $selectedTrip) {
                        Text("Choose a trip").tag(nil as Trip?)
                        ForEach(trips) { trip in
                            Text(trip.name).tag(trip as Trip?)
                        }
                    }

                    if let trip = selectedTrip {
                        Button("Add to \(trip.name)") {
                            let gmailService = GmailScanService()
                            gmailService.commitBooking(booking, to: trip, context: context)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button("Create New Trip") { showingNewTrip = true }
                }
            }

            Section {
                Button("Dismiss", role: .destructive) { dismiss() }
            }
        }
    }

    private var errorView: some View {
        ContentUnavailableView {
            Label("No Booking Found", systemImage: "envelope.badge.shield.half.filled")
        } description: {
            Text(parseError ?? "Could not detect a travel booking in this email. Try sharing a confirmation email from an airline, hotel, or rental provider.")
        } actions: {
            Button("Dismiss") { dismiss() }
                .buttonStyle(.bordered)
        }
    }

    private func parseContent() async {
        let content = parser.extractContent(text: sharedText, html: sharedHTML)
        parsedBooking = await parser.parseSharedContent(content)
        if parsedBooking == nil {
            parseError = "No travel booking detected in the shared content."
        }
        isParsing = false
    }
}
