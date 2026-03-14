import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var context
    @State private var selectedTab: TripTab = .overview

    enum TripTab: String, CaseIterable {
        case overview = "Overview"
        case itinerary = "Itinerary"
        case flights = "Flights"
        case accommodation = "Stays"
        case reservations = "Reservations"
        case todos = "Todos"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(TripTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)

            Divider()

            // Tab content
            ScrollView {
                switch selectedTab {
                case .overview: overviewTab
                case .itinerary: itineraryTab
                case .flights: flightsTab
                case .accommodation: accommodationTab
                case .reservations: reservationsTab
                case .todos: todosTab
                }
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Status", selection: $trip.status) {
                        ForEach(TripStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Overview

    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Date & status
            GroupBox("Trip Details") {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Dates") {
                        Text(dateRange)
                    }
                    LabeledContent("Status") {
                        Text(trip.status.displayName)
                    }
                    if trip.isUpcoming && trip.daysUntilStart > 0 {
                        LabeledContent("Countdown") {
                            Text("\(trip.daysUntilStart) days")
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }

            // Quick stats
            GroupBox("At a Glance") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard(count: trip.flights.count, label: "Flights", icon: "airplane")
                    statCard(count: trip.accommodations.count, label: "Stays", icon: "bed.double.fill")
                    statCard(count: trip.reservations.count, label: "Reservations", icon: "fork.knife")
                    statCard(count: trip.todoItems.filter { !$0.isCompleted }.count, label: "Open Todos", icon: "checklist")
                }
            }

            // Notes
            GroupBox("Notes") {
                TextEditor(text: $trip.notes)
                    .frame(minHeight: 100)
            }
        }
        .padding()
    }

    private func statCard(count: Int, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Flights

    private var flightsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(trip.flights.sorted(by: { $0.departureDateTime < $1.departureDateTime })) { flight in
                FlightCard(flight: flight)
            }

            Button("Add Flight", systemImage: "plus") {
                let flight = Flight(
                    airline: "", flightNumber: "",
                    departureAirport: "", arrivalAirport: "",
                    departureDateTime: trip.startDate, arrivalDateTime: trip.startDate
                )
                flight.trip = trip
                context.insert(flight)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Accommodation

    private var accommodationTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(trip.accommodations.sorted(by: { $0.checkIn < $1.checkIn })) { acc in
                AccommodationCard(accommodation: acc)
            }

            Button("Add Stay", systemImage: "plus") {
                let acc = Accommodation(
                    hotelName: "", checkIn: trip.startDate, checkOut: trip.endDate
                )
                acc.trip = trip
                context.insert(acc)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Reservations

    private var reservationsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(trip.reservations.sorted(by: { $0.dateTime < $1.dateTime })) { res in
                ReservationCard(reservation: res)
            }

            Button("Add Reservation", systemImage: "plus") {
                let res = Reservation(type: .restaurant, name: "", dateTime: trip.startDate)
                res.trip = trip
                context.insert(res)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Itinerary

    private var itineraryTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            let days = trip.itineraryDays.sorted(by: { $0.date < $1.date })

            if days.isEmpty {
                ContentUnavailableView("No Itinerary Yet",
                    systemImage: "calendar",
                    description: Text("Add days to plan your trip day-by-day.")
                )
            }

            ForEach(days) { day in
                ItineraryDayCard(day: day)
            }

            Button("Add Day", systemImage: "plus") {
                let nextDate = trip.itineraryDays
                    .map(\.date)
                    .max()
                    .map { Calendar.current.date(byAdding: .day, value: 1, to: $0) ?? $0 }
                    ?? trip.startDate
                let day = ItineraryDay(date: nextDate, sortOrder: trip.itineraryDays.count)
                day.trip = trip
                context.insert(day)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Todos

    @State private var generatedCount: Int?
    private let checklistGenerator = TripChecklistGenerator()

    private var todosTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Auto-generate button
            Button {
                let newTodos = checklistGenerator.generateChecklist(for: trip, context: context)
                generatedCount = newTodos.count
            } label: {
                Label("Auto-Generate Checklist", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            if let count = generatedCount {
                Text(count > 0 ? "\(count) items added based on your bookings" : "Checklist is up to date")
                    .font(.caption)
                    .foregroundStyle(count > 0 ? .green : .secondary)
            }

            Divider()

            ForEach(trip.todoItems.sorted(by: { !$0.isCompleted && $1.isCompleted })) { todo in
                TripTodoRow(todo: todo)
            }

            Button("Add Todo", systemImage: "plus") {
                let todo = TripTodo(title: "")
                todo.trip = trip
                context.insert(todo)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var dateRange: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return "\(fmt.string(from: trip.startDate)) – \(fmt.string(from: trip.endDate))"
    }
}

// MARK: - Sub-cards

struct FlightCard: View {
    @Bindable var flight: Flight

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(flight.airline) \(flight.flightNumber)")
                        .font(.headline)
                    Spacer()
                    if flight.isCancelled {
                        Text("CANCELLED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                    }
                }
                HStack {
                    VStack(alignment: .leading) {
                        Text(flight.departureAirport).font(.title2).fontWeight(.bold)
                        Text(flight.departureDateTime, style: .date)
                            .font(.caption)
                        Text(flight.departureDateTime, style: .time)
                            .font(.caption)
                    }
                    Spacer()
                    Image(systemName: "airplane")
                        .foregroundStyle(.blue)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(flight.arrivalAirport).font(.title2).fontWeight(.bold)
                        Text(flight.arrivalDateTime, style: .date)
                            .font(.caption)
                        Text(flight.arrivalDateTime, style: .time)
                            .font(.caption)
                    }
                }
                if !flight.confirmationCode.isEmpty {
                    LabeledContent("Confirmation") {
                        Text(flight.confirmationCode)
                            .fontDesign(.monospaced)
                    }
                    .font(.caption)
                }
                if let seat = flight.seatAssignment {
                    LabeledContent("Seat") { Text(seat) }
                        .font(.caption)
                }
            }
        }
    }
}

struct AccommodationCard: View {
    @Bindable var accommodation: Accommodation

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(accommodation.hotelName.isEmpty ? "New Stay" : accommodation.hotelName)
                    .font(.headline)
                if !accommodation.address.isEmpty {
                    Label(accommodation.address, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    VStack(alignment: .leading) {
                        Text("Check-in").font(.caption2).foregroundStyle(.secondary)
                        Text(accommodation.checkIn, style: .date).font(.caption)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Check-out").font(.caption2).foregroundStyle(.secondary)
                        Text(accommodation.checkOut, style: .date).font(.caption)
                    }
                }
                if !accommodation.confirmationNumber.isEmpty {
                    LabeledContent("Confirmation") {
                        Text(accommodation.confirmationNumber).fontDesign(.monospaced)
                    }
                    .font(.caption)
                }
            }
        }
    }
}

struct ReservationCard: View {
    let reservation: Reservation

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label(reservation.name.isEmpty ? "New Reservation" : reservation.name,
                          systemImage: iconForType(reservation.type))
                        .font(.headline)
                    Spacer()
                    if reservation.isCancelled {
                        Text("CANCELLED").font(.caption).foregroundStyle(.red)
                    }
                }
                Text(reservation.dateTime, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !reservation.location.isEmpty {
                    Label(reservation.location, systemImage: "mappin")
                        .font(.caption)
                }
            }
        }
    }

    private func iconForType(_ type: ReservationType) -> String {
        switch type {
        case .restaurant: return "fork.knife"
        case .tour: return "binoculars.fill"
        case .activity: return "figure.hiking"
        case .carRental: return "car.fill"
        case .train: return "tram.fill"
        case .other: return "star.fill"
        }
    }
}

struct ItineraryDayCard: View {
    @Bindable var day: ItineraryDay

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(day.date, style: .date)
                    .font(.headline)
                ForEach(day.items.sorted(by: { $0.sortOrder < $1.sortOrder })) { item in
                    HStack {
                        Circle()
                            .fill(.blue)
                            .frame(width: 6, height: 6)
                        Text(item.title)
                            .font(.subheadline)
                        Spacer()
                        if let time = item.startTime {
                            Text(time, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if day.items.isEmpty {
                    Text("No activities planned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct TripTodoRow: View {
    @Bindable var todo: TripTodo

    var body: some View {
        HStack {
            Button {
                todo.isCompleted.toggle()
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            TextField("Todo", text: $todo.title)
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)

            Spacer()

            if let due = todo.dueDate {
                Text(due, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
