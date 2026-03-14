import SwiftUI
import SwiftData
import UIKit

struct TripListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Trip.startDate, order: .forward) private var trips: [Trip]
    @State private var showingAddTrip = false
    @State private var showingGmailConnect = false
    @State private var searchText = ""

    private var upcomingTrips: [Trip] {
        trips.filter(\.isUpcoming)
    }

    private var pastTrips: [Trip] {
        trips.filter(\.isPast)
    }

    private var filteredTrips: [Trip] {
        if searchText.isEmpty { return trips }
        return trips.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if trips.isEmpty {
                emptyState
            } else {
                tripList
            }
        }
        .navigationTitle("Trips")
        .searchable(text: $searchText, prompt: "Search trips")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Trip", systemImage: "plus") {
                        showingAddTrip = true
                    }
                    Button("Connect Gmail", systemImage: "envelope.badge") {
                        showingGmailConnect = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                if appState.isGmailConnected {
                    gmailStatusBadge
                }
            }
        }
        .sheet(isPresented: $showingAddTrip) {
            NavigationStack {
                AddTripView()
            }
        }
        .sheet(isPresented: $showingGmailConnect) {
            NavigationStack {
                GmailConnectView()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Trips", systemImage: "airplane.departure")
        } description: {
            Text("Plan your next adventure. Create a trip manually or connect Gmail to auto-detect bookings.")
        } actions: {
            Button("Create Trip") { showingAddTrip = true }
                .buttonStyle(.borderedProminent)
            Button("Connect Gmail") { showingGmailConnect = true }
                .buttonStyle(.bordered)
        }
    }

    private var tripList: some View {
        List {
            if !upcomingTrips.isEmpty {
                Section("Upcoming") {
                    ForEach(upcomingTrips) { trip in
                        NavigationLink(value: trip) {
                            TripRowView(trip: trip)
                        }
                    }
                    .onDelete { offsets in
                        deleteTrips(at: offsets, from: upcomingTrips)
                    }
                }
            }

            if !pastTrips.isEmpty {
                Section("Past") {
                    ForEach(pastTrips) { trip in
                        NavigationLink(value: trip) {
                            TripRowView(trip: trip)
                        }
                    }
                    .onDelete { offsets in
                        deleteTrips(at: offsets, from: pastTrips)
                    }
                }
            }
        }
        .navigationDestination(for: Trip.self) { trip in
            TripDetailView(trip: trip)
        }
    }

    @ViewBuilder
    private var gmailStatusBadge: some View {
        switch appState.gmailScanStatus {
        case .scanning:
            Label("Scanning", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .found(let count):
            Label("\(count) new", systemImage: "envelope.open.fill")
                .font(.caption)
                .foregroundStyle(.blue)
        default:
            Label("Gmail", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    private func deleteTrips(at offsets: IndexSet, from source: [Trip]) {
        for index in offsets {
            context.delete(source[index])
        }
    }
}

struct TripRowView: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            if let imageData = trip.coverImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.blue.gradient)
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "airplane")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(.headline)

                Text(tripDateRange)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    statusBadge
                    if trip.isUpcoming && trip.daysUntilStart > 0 {
                        Text("\(trip.daysUntilStart) days away")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var tripDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: trip.startDate)) – \(formatter.string(from: trip.endDate))"
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (text, color): (String, Color) = switch trip.status {
        case .planning: ("Planning", .orange)
        case .booked: ("Booked", .green)
        case .inProgress: ("In Progress", .blue)
        case .completed: ("Completed", .secondary)
        case .cancelled: ("Cancelled", .red)
        }

        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
