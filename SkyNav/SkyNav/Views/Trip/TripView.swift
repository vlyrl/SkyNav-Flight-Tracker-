import SwiftUI

// MARK: - TripView

struct TripView: View {
    @State private var viewModel: TripViewModel
    @State private var showNewTrip: Bool = false
    @State private var expandedTripIds: Set<UUID> = []
    @State private var appeared: Bool = false

    init(viewModel: TripViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SkyNavColor.background.ignoresSafeArea()

                if viewModel.trips.isEmpty {
                    emptyState
                } else {
                    tripList
                }

                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        newTripFAB
                            .padding(.trailing, 24)
                            .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        SkyNavHaptic.light()
                        showNewTrip = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(SkyNavColor.accent)
                    }
                }
            }
            .sheet(isPresented: $showNewTrip) {
                NewTripSheet(viewModel: viewModel)
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Trip List

    private var tripList: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: []) {
                ForEach(viewModel.trips) { trip in
                    TripSection(
                        trip: trip,
                        flights: viewModel.flightsForTrip(trip),
                        viewModel: viewModel,
                        isExpanded: expandedTripIds.contains(trip.id),
                        onToggle: {
                            SkyNavHaptic.light()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                if expandedTripIds.contains(trip.id) {
                                    expandedTripIds.remove(trip.id)
                                } else {
                                    expandedTripIds.insert(trip.id)
                                }
                            }
                        },
                        onDelete: {
                            SkyNavHaptic.medium()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                viewModel.deleteTrip(trip)
                            }
                        }
                    )
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .onAppear {
            // Auto-expand first trip
            if let first = viewModel.trips.first {
                expandedTripIds.insert(first.id)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "map")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(SkyNavColor.textTertiary)

            VStack(spacing: 10) {
                Text("No Trips Yet")
                    .font(.skyNavTitle)
                    .foregroundStyle(SkyNavColor.textPrimary)

                Text("Group your flights into trips\nto see layovers, date ranges,\nand the full itinerary at a glance.")
                    .font(.skyNavBody)
                    .foregroundStyle(SkyNavColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                SkyNavHaptic.medium()
                showNewTrip = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Create a Trip")
                        .font(.skyNavHeadline)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(SkyNavColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: SkyNavColor.accent.opacity(0.35), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
        }
        .padding(40)
    }

    // MARK: - FAB

    private var newTripFAB: some View {
        Button {
            SkyNavHaptic.medium()
            showNewTrip = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("New Trip")
                    .font(.skyNavHeadline)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [SkyNavColor.accent, SkyNavColor.accentDim],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: SkyNavColor.accent.opacity(0.45), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - TripSection

struct TripSection: View {
    let trip: Trip
    let flights: [Flight]
    let viewModel: TripViewModel
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    private var dateRange: String {
        guard !flights.isEmpty else { return "No flights" }
        let sorted = flights.sorted { $0.scheduledDeparture < $1.scheduledDeparture }
        guard let first = sorted.first, let last = sorted.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        if Calendar.current.isDate(first.scheduledDeparture, equalTo: last.scheduledArrival, toGranularity: .day) {
            return formatter.string(from: first.scheduledDeparture)
        }
        return "\(formatter.string(from: first.scheduledDeparture)) – \(formatter.string(from: last.scheduledArrival))"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.name)
                            .font(.skyNavHeadline)
                            .foregroundStyle(SkyNavColor.textPrimary)

                        HStack(spacing: 6) {
                            Text(dateRange)
                                .font(.skyNavCaption)
                                .foregroundStyle(SkyNavColor.textSecondary)

                            Text("·")
                                .foregroundStyle(SkyNavColor.textTertiary)

                            Text("\(flights.count) flight\(flights.count == 1 ? "" : "s")")
                                .font(.skyNavCaption)
                                .foregroundStyle(SkyNavColor.textTertiary)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SkyNavColor.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable content
            if isExpanded {
                Divider()
                    .background(SkyNavColor.surfaceBorder)
                    .padding(.horizontal, 16)

                if flights.isEmpty {
                    Text("No flights in this trip")
                        .font(.skyNavBody)
                        .foregroundStyle(SkyNavColor.textTertiary)
                        .padding(24)
                } else {
                    TripTimeline(flights: flights, viewModel: viewModel)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
        }
        .background(SkyNavColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(SkyNavColor.surfaceBorder, lineWidth: 0.5)
        )
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Trip", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }
}

// MARK: - TripTimeline

struct TripTimeline: View {
    let flights: [Flight]
    let viewModel: TripViewModel

    private var sortedFlights: [Flight] {
        flights.sorted { $0.scheduledDeparture < $1.scheduledDeparture }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(sortedFlights.enumerated()), id: \.element.id) { index, flight in
                TripFlightCard(flight: flight)

                if index < sortedFlights.count - 1 {
                    let nextFlight = sortedFlights[index + 1]
                    if let layoverDuration = viewModel.layoverDuration(between: flight, and: nextFlight) {
                        let now = Date()
                        let isActive = flight.effectiveArrival <= now && now <= nextFlight.effectiveDeparture
                        LayoverCard(
                            layoverAirport: flight.destinationIata,
                            duration: layoverDuration,
                            isActive: isActive
                        )
                        .padding(.vertical, 4)

                        // Connection risk analysis
                        ConnectionAssistantView(arriving: flight, departing: nextFlight)
                            .padding(.bottom, 4)
                    }
                }
            }
        }
    }
}

// MARK: - TripFlightCard

struct TripFlightCard: View {
    let flight: Flight

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator stripe
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(flight.status.color)
                .frame(width: 3)
                .frame(height: 52)

            // Route
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(flight.originIata)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(SkyNavColor.textPrimary)
                    Text(flight.effectiveDeparture, style: .time)
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.textSecondary)
                }

                Spacer()

                VStack(spacing: 3) {
                    Image(systemName: "airplane")
                        .font(.system(size: 12))
                        .foregroundStyle(SkyNavColor.textTertiary)
                    Text(flight.flightNumber)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(SkyNavColor.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(flight.destinationIata)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(SkyNavColor.textPrimary)
                    Text(flight.effectiveArrival, style: .time)
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.textSecondary)
                }
            }

            StatusPill(status: flight.status, showIcon: false)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(
            flight.status.isActive
                ? SkyNavGradient.activeCard
                : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - NewTripSheet

struct NewTripSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: TripViewModel

    @State private var nameError: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                SkyNavColor.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Name field
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TRIP NAME")
                                .font(.skyNavCaption)
                                .foregroundStyle(SkyNavColor.textTertiary)
                                .padding(.leading, 4)

                            HStack {
                                Image(systemName: "tag")
                                    .font(.system(size: 15))
                                    .foregroundStyle(SkyNavColor.textSecondary)

                                TextField("e.g. Europe Summer Trip", text: $viewModel.newTripName)
                                    .font(.skyNavBody)
                                    .foregroundStyle(SkyNavColor.textPrimary)
                                    .autocorrectionDisabled()
                                    .onChange(of: viewModel.newTripName) { _, _ in
                                        if nameError && !viewModel.newTripName.isEmpty {
                                            nameError = false
                                        }
                                    }
                            }
                            .padding(14)
                            .background(SkyNavColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        nameError ? SkyNavColor.statusCancelled : SkyNavColor.surfaceBorder,
                                        lineWidth: nameError ? 1 : 0.5
                                    )
                            )

                            if nameError {
                                Text("Please enter a trip name")
                                    .font(.skyNavCaption)
                                    .foregroundStyle(SkyNavColor.statusCancelled)
                                    .padding(.leading, 4)
                            }
                        }

                        // Flight selector
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SELECT FLIGHTS")
                                .font(.skyNavCaption)
                                .foregroundStyle(SkyNavColor.textTertiary)
                                .padding(.leading, 4)

                            if viewModel.flights.isEmpty {
                                Text("No flights available. Add some flights first.")
                                    .font(.skyNavBody)
                                    .foregroundStyle(SkyNavColor.textTertiary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(24)
                                    .background(SkyNavColor.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(viewModel.flights.sorted(by: { $0.scheduledDeparture < $1.scheduledDeparture })) { flight in
                                        TripFlightSelectorRow(
                                            flight: flight,
                                            isSelected: viewModel.selectedFlightIds.contains(flight.id)
                                        ) {
                                            SkyNavHaptic.select()
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                if viewModel.selectedFlightIds.contains(flight.id) {
                                                    viewModel.selectedFlightIds.remove(flight.id)
                                                } else {
                                                    viewModel.selectedFlightIds.insert(flight.id)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Create button
                        Button {
                            guard !viewModel.newTripName.trimmingCharacters(in: .whitespaces).isEmpty else {
                                SkyNavHaptic.error()
                                withAnimation { nameError = true }
                                return
                            }
                            viewModel.newTripName = viewModel.newTripName.trimmingCharacters(in: .whitespaces)
                            viewModel.createTrip()
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Create Trip")
                                    .font(.skyNavHeadline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                LinearGradient(
                                    colors: [SkyNavColor.accent, SkyNavColor.accentDim],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: SkyNavColor.accent.opacity(0.35), radius: 10, y: 5)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        SkyNavHaptic.light()
                        viewModel.newTripName = ""
                        viewModel.selectedFlightIds = []
                        dismiss()
                    }
                    .foregroundStyle(SkyNavColor.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            // Reset state if dismissed without creating
            if viewModel.showCreateTrip {
                viewModel.newTripName = ""
                viewModel.selectedFlightIds = []
            }
        }
    }
}

// MARK: - TripFlightSelectorRow

struct TripFlightSelectorRow: View {
    let flight: Flight
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? SkyNavColor.accent : SkyNavColor.surfaceRaised)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            isSelected ? SkyNavColor.accent : SkyNavColor.surfaceBorder,
                            lineWidth: 1
                        )
                )

                // Route
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(flight.flightNumber)
                            .font(.skyNavCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(SkyNavColor.textPrimary)

                        Text("\(flight.originIata) → \(flight.destinationIata)")
                            .font(.skyNavCaption)
                            .foregroundStyle(SkyNavColor.textSecondary)
                    }
                    Text(flight.scheduledDeparture, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(SkyNavColor.textTertiary)
                }

                Spacer()

                StatusPill(status: flight.status, showIcon: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                isSelected
                    ? SkyNavColor.accent.opacity(0.08)
                    : SkyNavColor.surface
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? SkyNavColor.accent.opacity(0.35) : SkyNavColor.surfaceBorder,
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
