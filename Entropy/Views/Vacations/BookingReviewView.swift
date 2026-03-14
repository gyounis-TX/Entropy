import SwiftUI
import SwiftData

struct BookingReviewView: View {
    let booking: ParsedBooking
    let gmailService: GmailScanService

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @State private var selectedTrip: Trip?
    @State private var showingNewTrip = false

    var body: some View {
        List {
            // Booking details
            Section("Booking Details") {
                LabeledContent("Provider") { Text(booking.provider) }
                LabeledContent("Category") { Text(booking.category.rawValue.capitalized) }
                LabeledContent("Confirmation") {
                    Text(booking.confirmationNumber)
                        .fontDesign(.monospaced)
                }
                LabeledContent("Date") {
                    Text(booking.startDate, style: .date)
                }
                if booking.isCancellation {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("This is a cancellation notice")
                            .foregroundStyle(.red)
                    }
                }
            }

            // Parsed details
            detailsSection

            // Email source
            Section("Source Email") {
                Text(booking.sourceEmailSubject)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Actions
            if booking.isCancellation {
                cancellationActions
            } else {
                bookingActions
            }
        }
        .navigationTitle("Review Booking")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNewTrip) {
            NavigationStack {
                AddTripView()
            }
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        switch booking.details {
        case .flight(let d):
            Section("Flight Details") {
                LabeledContent("Flight") { Text("\(d.airline) \(d.flightNumber)") }
                LabeledContent("Route") { Text("\(d.departureAirport) → \(d.arrivalAirport)") }
                LabeledContent("Departure") { Text(d.departureDateTime, style: .date) }
                if let seat = d.seatAssignment {
                    LabeledContent("Seat") { Text(seat) }
                }
            }
        case .hotel(let d):
            Section("Hotel Details") {
                LabeledContent("Hotel") { Text(d.hotelName) }
                if !d.address.isEmpty {
                    LabeledContent("Address") { Text(d.address) }
                }
                LabeledContent("Check-in") { Text(d.checkIn, style: .date) }
                LabeledContent("Check-out") { Text(d.checkOut, style: .date) }
            }
        case .rental(let d):
            Section("Rental Details") {
                LabeledContent("Property") { Text(d.propertyName) }
                if !d.address.isEmpty {
                    LabeledContent("Address") { Text(d.address) }
                }
                LabeledContent("Check-in") { Text(d.checkIn, style: .date) }
                LabeledContent("Check-out") { Text(d.checkOut, style: .date) }
                if let host = d.hostName {
                    LabeledContent("Host") { Text(host) }
                }
            }
        case .train(let d):
            Section("Train Details") {
                LabeledContent("Route") { Text(d.route) }
                LabeledContent("Departure") { Text(d.departureDateTime, style: .date) }
                if let seat = d.seatAssignment {
                    LabeledContent("Seat") { Text(seat) }
                }
                if let car = d.carNumber {
                    LabeledContent("Car") { Text(car) }
                }
            }
        case .carRental(let d):
            Section("Car Rental Details") {
                LabeledContent("Company") { Text(d.company) }
                LabeledContent("Pickup") { Text(d.pickupLocation) }
                LabeledContent("Dropoff") { Text(d.dropoffLocation) }
                LabeledContent("Pickup Date") { Text(d.pickupDateTime, style: .date) }
                LabeledContent("Return Date") { Text(d.dropoffDateTime, style: .date) }
            }
        }
    }

    private var bookingActions: some View {
        Section("Add to Trip") {
            if trips.isEmpty {
                Button("Create New Trip") { showingNewTrip = true }
                    .buttonStyle(.borderedProminent)
            } else {
                Picker("Select Trip", selection: $selectedTrip) {
                    Text("Choose a trip").tag(nil as Trip?)
                    ForEach(trips) { trip in
                        Text(trip.name).tag(trip as Trip?)
                    }
                }

                if let trip = selectedTrip {
                    Button("Add to \(trip.name)") {
                        gmailService.commitBooking(booking, to: trip, context: context)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Create New Trip Instead") { showingNewTrip = true }
            }

            Button("Dismiss", role: .destructive) {
                dismiss()
            }
        }
    }

    private var cancellationActions: some View {
        Section("Actions") {
            Button("Match & Cancel Booking", role: .destructive) {
                try? gmailService.applyCancellation(booking, context: context)
                dismiss()
            }
            Button("Keep for Records") {
                dismiss()
            }
            Button("Dismiss") {
                dismiss()
            }
        }
    }
}
