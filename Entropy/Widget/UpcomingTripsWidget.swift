import WidgetKit
import SwiftUI

// MARK: - Upcoming Trips Widget

/// Shows the next upcoming trip with a countdown.
struct UpcomingTripsWidget: Widget {
    let kind: String = "UpcomingTripsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpcomingTripsProvider()) { entry in
            UpcomingTripsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Upcoming Trip")
        .description("See your next trip at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct UpcomingTripEntry: TimelineEntry {
    let date: Date
    let tripName: String?
    let tripStart: Date?
    let tripEnd: Date?
    let daysUntil: Int?
    let flightCount: Int
    let hotelName: String?
}

struct UpcomingTripsProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingTripEntry {
        UpcomingTripEntry(date: Date(), tripName: "Italy Summer 2026",
                          tripStart: Date().addingTimeInterval(86400 * 30),
                          tripEnd: Date().addingTimeInterval(86400 * 37),
                          daysUntil: 30, flightCount: 2, hotelName: "Hotel Roma")
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingTripEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingTripEntry>) -> Void) {
        // In production: read from shared SwiftData container
        let entry = UpcomingTripEntry(date: Date(), tripName: nil,
                                       tripStart: nil, tripEnd: nil,
                                       daysUntil: nil, flightCount: 0, hotelName: nil)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }
}

struct UpcomingTripsWidgetView: View {
    let entry: UpcomingTripEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        if let tripName = entry.tripName, let days = entry.daysUntil {
            tripView(name: tripName, daysUntil: days)
        } else {
            noTripView
        }
    }

    private func tripView(name: String, daysUntil: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "airplane.departure")
                    .foregroundStyle(.blue)
                Spacer()
                Text("\(daysUntil)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                Text("days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(name)
                .font(.headline)
                .lineLimit(2)

            if let start = entry.tripStart {
                Text(start, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if family == .systemMedium {
                Spacer()
                HStack(spacing: 12) {
                    if entry.flightCount > 0 {
                        Label("\(entry.flightCount) flights", systemImage: "airplane")
                            .font(.caption2)
                    }
                    if let hotel = entry.hotelName {
                        Label(hotel, systemImage: "bed.double.fill")
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(4)
    }

    private var noTripView: some View {
        VStack(spacing: 8) {
            Image(systemName: "airplane")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No upcoming trips")
                .font(.caption)
                .foregroundStyle(.secondary)

            Link(destination: URL(string: "entropy://new-trip")!) {
                Text("Plan one")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }
}
