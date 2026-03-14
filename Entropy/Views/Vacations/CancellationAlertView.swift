import SwiftUI
import SwiftData

struct CancellationAlertView: View {
    let booking: ParsedBooking
    let gmailService: GmailScanService

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)

            Text("Booking Cancelled")
                .font(.title2)
                .fontWeight(.bold)

            Text(cancellationSummary)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Provider") { Text(booking.provider) }
                    LabeledContent("Confirmation #") {
                        Text(booking.confirmationNumber)
                            .fontDesign(.monospaced)
                    }
                    LabeledContent("Date") {
                        Text(booking.startDate, style: .date)
                    }
                }
            }

            VStack(spacing: 12) {
                Button {
                    try? gmailService.applyCancellation(booking, context: context)
                    dismiss()
                } label: {
                    Text("Remove from Trip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button {
                    dismiss()
                } label: {
                    Text("Keep for Records")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button("Dismiss", role: .cancel) {
                    dismiss()
                }
            }
        }
        .padding(24)
    }

    private var cancellationSummary: String {
        switch booking.details {
        case .flight(let d):
            return "Your \(d.airline) flight \(d.flightNumber) (\(d.departureAirport) → \(d.arrivalAirport)) has been cancelled."
        case .hotel(let d):
            return "Your reservation at \(d.hotelName) has been cancelled."
        case .rental(let d):
            return "Your stay at \(d.propertyName) has been cancelled."
        case .train(let d):
            return "Your train \(d.route) has been cancelled."
        case .carRental(let d):
            return "Your \(d.company) rental has been cancelled."
        }
    }
}
