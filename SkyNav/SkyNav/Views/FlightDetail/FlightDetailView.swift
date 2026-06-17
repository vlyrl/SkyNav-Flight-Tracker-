import SwiftUI
import MapKit

// MARK: - Flight Detail View

struct FlightDetailView: View {
    @Bindable var viewModel: FlightDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showFullScreenMap = false
    @State private var notificationsEnabled: Bool

    init(viewModel: FlightDetailViewModel) {
        self.viewModel = viewModel
        _notificationsEnabled = State(initialValue: viewModel.flight.notificationsEnabled)
    }

    // MARK: Computed helpers

    private var flight: Flight { viewModel.flight }

    private var originTZ: TimeZone {
        TimeZone(identifier: flight.originTimezone) ?? .current
    }

    private var destinationTZ: TimeZone {
        TimeZone(identifier: flight.destinationTimezone) ?? .current
    }

    private var distanceMiles: Int {
        let origin = CLLocation(latitude: flight.originLatitude, longitude: flight.originLongitude)
        let dest   = CLLocation(latitude: flight.destinationLatitude, longitude: flight.destinationLongitude)
        return Int(origin.distance(from: dest) * 0.000621371)
    }

    private var durationString: String {
        let total = Int(flight.flightDuration / 60)
        let hours = total / 60
        let minutes = total % 60
        return "\(hours)h \(minutes)m"
    }

    private var shareText: String {
        """
        \(flight.flightNumber) · \(flight.airlineName)
        \(flight.originIata) → \(flight.destinationIata)
        Departure: \(formattedDate(flight.effectiveDeparture, tz: originTZ))
        Arrival:   \(formattedDate(flight.effectiveArrival, tz: destinationTZ))
        Status: \(flight.status.displayName)\(flight.delayMinutes > 0 ? " (+\(flight.delayMinutes)m)" : "")
        """
    }

    private func formattedDate(_ date: Date, tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .short
        f.timeZone = tz
        return f.string(from: date)
    }

    private func formattedTime(_ date: Date, tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        f.timeZone  = tz
        return f.string(from: date)
    }

    // MARK: Arrival Forecast helpers

    /// ±5-min tailwind adjustment seeded deterministically by flight number.
    private var tailwindMinutes: Int {
        let seed = flight.flightNumber.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return (seed % 11) - 5   // range: -5 … +5
    }

    private var forecastedArrival: Date {
        flight.scheduledArrival
            .addingTimeInterval(Double(flight.delayMinutes) * 60)
            .addingTimeInterval(Double(tailwindMinutes) * 60)
    }

    /// Net offset from scheduled arrival in whole minutes (delay + tailwind).
    private var forecastDiffMinutes: Int {
        Int(forecastedArrival.timeIntervalSince(flight.scheduledArrival) / 60)
    }

    private var showMap: Bool {
        flight.status == .inFlight || flight.status == .departed
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // Global background
            SkyNavColor.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    contentStack
                }
            }
            .refreshable {
                await viewModel.refresh()
            }

            // Refresh overlay
            if viewModel.isRefreshing {
                refreshOverlay
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(SkyNavColor.accent)
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showFullScreenMap) {
            fullScreenMapSheet
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Gradient background fills behind the header content
            SkyNavGradient.hero
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 16) {
                // Airline name + flight number
                HStack(spacing: 10) {
                    AirlineLogoView(iataCode: flight.airlineIata, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(flight.flightNumber)
                            .font(.skyNavHeadline)
                            .foregroundStyle(SkyNavColor.textPrimary)
                        Text(flight.airlineName)
                            .font(.skyNavCaption)
                            .foregroundStyle(SkyNavColor.textSecondary)
                    }
                    Spacer()
                    StatusPill(status: flight.status)
                }

                // Origin → Destination city names
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(flight.originIata)
                            .font(.skyNavDisplay)
                            .foregroundStyle(SkyNavColor.textPrimary)
                        Text(flight.originCity)
                            .font(.skyNavCaption)
                            .foregroundStyle(SkyNavColor.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(SkyNavColor.textTertiary)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(flight.destinationIata)
                            .font(.skyNavDisplay)
                            .foregroundStyle(SkyNavColor.textPrimary)
                        Text(flight.destinationCity)
                            .font(.skyNavCaption)
                            .foregroundStyle(SkyNavColor.textSecondary)
                            .lineLimit(1)
                    }
                }

                // Flight progress bar (active or completed flights)
                if flight.status.isActive || flight.status.isCompleted {
                    FlightProgressBar(
                        originIata: flight.originIata,
                        destinationIata: flight.destinationIata,
                        progress: flight.progressFraction,
                        heading: flight.livePosition?.heading
                    )
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Content Stack

    private var contentStack: some View {
        VStack(spacing: 20) {
            // Prominent banners for problem statuses
            if flight.status == .cancelled {
                statusBanner(
                    icon: "xmark.circle.fill",
                    message: "This flight has been cancelled.",
                    color: SkyNavColor.statusCancelled
                )
            } else if flight.status == .diverted {
                statusBanner(
                    icon: "arrow.triangle.turn.up.right.circle.fill",
                    message: "This flight has been diverted.",
                    color: SkyNavColor.statusDelayed
                )
            }

            timesSection
            if showMap { mapSection }
            aircraftPhotoSection
            flightInfoSection
            if viewModel.airportBoard != nil { airportSection }
            notificationsSection
            deleteSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }

    // MARK: - Status Banner

    private func statusBanner(icon: String, message: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
            Text(message)
                .font(.skyNavHeadline)
                .foregroundStyle(color)
            Spacer()
        }
        .padding(16)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Times Section

    private var timesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Times", icon: "clock")

            HStack(alignment: .top, spacing: 0) {
                // Departure block
                VStack(alignment: .leading, spacing: 8) {
                    TimeDisplay(
                        date: flight.effectiveDeparture,
                        timezone: originTZ,
                        label: "Departure",
                        showDelay: flight.delayMinutes > 0,
                        delayMinutes: flight.delayMinutes
                    )

                    timeMetaRow(
                        gate: flight.departureGate,
                        terminal: flight.departureTerminal,
                        prefix: "Gate", gateIcon: "door.right.hand.open"
                    )
                }

                Spacer()

                // Divider
                Rectangle()
                    .fill(SkyNavColor.surfaceBorder)
                    .frame(width: 1, height: 80)

                Spacer()

                // Arrival block
                VStack(alignment: .trailing, spacing: 8) {
                    TimeDisplay(
                        date: flight.effectiveArrival,
                        timezone: destinationTZ,
                        label: "Arrival",
                        showDelay: flight.delayMinutes > 0,
                        delayMinutes: flight.delayMinutes
                    )

                    timeMetaRow(
                        gate: flight.arrivalGate,
                        terminal: flight.arrivalTerminal,
                        prefix: "Gate", gateIcon: "door.right.hand.open",
                        alignment: .trailing
                    )
                }
            }

            // On-time / delay badge
            delayBadge

            // Arrival forecast pill
            forecastPill
        }
        .padding(16)
        .skyNavCard(gradient: SkyNavGradient.activeCard)
    }

    // MARK: - Arrival Forecast Pill

    @ViewBuilder
    private var forecastPill: some View {
        let diff = forecastDiffMinutes
        if flight.status == .cancelled || flight.status == .diverted { EmptyView() }
        else if abs(diff) > 5 {
            let sign = diff > 0 ? "+" : ""
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                Text("Est. \(formattedTime(forecastedArrival, tz: destinationTZ)) (\(sign)\(diff)m)")
                    .font(.skyNavCaption)
            }
            .foregroundStyle(SkyNavColor.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(SkyNavColor.accent.opacity(0.12))
            .clipShape(Capsule())
        } else {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("On time")
                    .font(.skyNavCaption)
            }
            .foregroundStyle(SkyNavColor.statusOnTime)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(SkyNavColor.statusOnTime.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    private func timeMetaRow(
        gate: String?,
        terminal: String?,
        prefix: String,
        gateIcon: String,
        alignment: HorizontalAlignment = .leading
    ) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            if let gate {
                Label(gate, systemImage: gateIcon)
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.accent)
            }
            if let terminal {
                Label(terminal, systemImage: "building.2")
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var delayBadge: some View {
        if flight.delayMinutes > 0 {
            HStack(spacing: 6) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 12, weight: .semibold))
                Text("+\(flight.delayMinutes)m delay")
                    .font(.skyNavCaption)
            }
            .foregroundStyle(SkyNavColor.statusDelayed)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(SkyNavColor.statusDelayed.opacity(0.12))
            .clipShape(Capsule())
        } else if flight.status != .cancelled && flight.status != .diverted {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("On Time")
                    .font(.skyNavCaption)
            }
            .foregroundStyle(SkyNavColor.statusOnTime)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(SkyNavColor.statusOnTime.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    // MARK: - Map Section

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Live Map", icon: "map")

            FlightMapView(flight: flight)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Button {
                        SkyNavHaptic.light()
                        showFullScreenMap = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SkyNavColor.textPrimary)
                            .padding(8)
                            .modifier(MapButtonBackgroundModifier())
                            .padding(10)
                    }
                }
                .onTapGesture {
                    SkyNavHaptic.light()
                    showFullScreenMap = true
                }
        }
    }

    private var fullScreenMapSheet: some View {
        ZStack(alignment: .topTrailing) {
            SkyNavColor.background.ignoresSafeArea()
            FlightMapView(flight: flight)
                .ignoresSafeArea()

            Button {
                showFullScreenMap = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SkyNavColor.textPrimary)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding([.top, .trailing], 20)
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }

    // MARK: - Aircraft Photo Section

    private var aircraftPhotoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Aircraft", icon: "airplane")

            AircraftPhotoView(
                registration: flight.aircraftRegistration,
                aircraftType: flight.aircraftType
            )
        }
    }

    // MARK: - Flight Info Section

    private var flightInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Flight Info", icon: "info.circle")

            VStack(spacing: 0) {
                if let gate = flight.departureGate {
                    FlightStatusRow(label: "Departure Gate", value: gate,
                                   icon: "door.right.hand.open", highlight: true)
                    rowDivider
                }
                if let terminal = flight.departureTerminal {
                    FlightStatusRow(label: "Departure Terminal", value: terminal,
                                   icon: "building.2")
                    rowDivider
                }
                if let gate = flight.arrivalGate {
                    FlightStatusRow(label: "Arrival Gate", value: gate,
                                   icon: "door.right.hand.open", highlight: true)
                    rowDivider
                }
                if let terminal = flight.arrivalTerminal {
                    FlightStatusRow(label: "Arrival Terminal", value: terminal,
                                   icon: "building.2")
                    rowDivider
                }
                if let baggage = flight.baggageClaim {
                    FlightStatusRow(label: "Baggage Claim", value: baggage,
                                   icon: "suitcase.rolling")
                    rowDivider
                }
                if let type = flight.aircraftType {
                    FlightStatusRow(label: "Aircraft", value: type, icon: "airplane")
                    rowDivider
                }
                FlightStatusRow(label: "Duration", value: durationString, icon: "clock")
                rowDivider
                taxiTimesRow
                rowDivider
                FlightStatusRow(label: "Distance",
                               value: "\(distanceMiles.formatted()) mi",
                               icon: "location")
            }
            .padding(.horizontal, 16)
            .skyNavCard()
        }
    }

    private var taxiTimesRow: some View {
        let out = TaxiTimeService.times(for: flight.originIata).out
        let inn = TaxiTimeService.times(for: flight.destinationIata).inbound
        return FlightStatusRow(
            label: "Taxi Times",
            value: "Out ~\(out) min · In ~\(inn) min",
            icon:  "road.lanes"
        )
    }

    private var rowDivider: some View {
        Divider()
            .background(SkyNavColor.surfaceBorder)
            .padding(.leading, 32)
    }

    // MARK: - Airport Section

    @ViewBuilder
    private var airportSection: some View {
        if let board = viewModel.airportBoard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Destination Airport", icon: "building.2")

                VStack(spacing: 12) {
                    if let weather = board.weather {
                        weatherCard(weather: weather)
                    }
                    if let waitMins = board.securityWaitMinutes {
                        securityCard(waitMinutes: waitMins)
                    }
                }
            }
        }
    }

    private func weatherCard(weather: AirportWeather) -> some View {
        HStack(spacing: 16) {
            Image(systemName: weatherIcon(for: weather.condition))
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(SkyNavColor.accent)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(weather.condition)
                    .font(.skyNavHeadline)
                    .foregroundStyle(SkyNavColor.textPrimary)
                HStack(spacing: 6) {
                    Text("\(Int(weather.temperatureFahrenheit))°F")
                        .font(.skyNavBody)
                        .foregroundStyle(SkyNavColor.textSecondary)
                    Text("·")
                        .foregroundStyle(SkyNavColor.textTertiary)
                    Text("Wind \(Int(weather.windSpeedKmh)) km/h \(weather.windDirection)")
                        .font(.skyNavBody)
                        .foregroundStyle(SkyNavColor.textSecondary)
                }
                Text("Visibility \(String(format: "%.1f", weather.visibilityKm)) km")
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textTertiary)
            }

            Spacer()

            Text("\(Int(weather.temperatureCelsius))°C")
                .font(.skyNavMonoLarge)
                .foregroundStyle(SkyNavColor.textPrimary)
        }
        .padding(16)
        .skyNavCard()
    }

    private func securityCard(waitMinutes: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(securityColor(waitMinutes))
                .frame(width: 28)

            Text("Security Wait")
                .font(.skyNavBody)
                .foregroundStyle(SkyNavColor.textSecondary)

            Spacer()

            Text("~\(waitMinutes) min")
                .font(.skyNavHeadline)
                .foregroundStyle(securityColor(waitMinutes))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(securityColor(waitMinutes).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(16)
        .skyNavCard()
    }

    private func securityColor(_ minutes: Int) -> Color {
        switch minutes {
        case ..<15:  return SkyNavColor.statusOnTime
        case 15..<30: return SkyNavColor.statusDelayed
        default:      return SkyNavColor.statusCancelled
        }
    }

    private func weatherIcon(for condition: String) -> String {
        let lower = condition.lowercased()
        if lower.contains("thunder") { return "cloud.bolt.rain.fill" }
        if lower.contains("snow")    { return "cloud.snow.fill" }
        if lower.contains("rain") || lower.contains("shower") { return "cloud.rain.fill" }
        if lower.contains("cloud")   { return "cloud.fill" }
        if lower.contains("fog") || lower.contains("mist") { return "cloud.fog.fill" }
        if lower.contains("wind")    { return "wind" }
        return "sun.max.fill"
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Notifications", icon: "bell")

            Toggle(isOn: $notificationsEnabled) {
                HStack(spacing: 10) {
                    Image(systemName: notificationsEnabled ? "bell.fill" : "bell.slash")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(notificationsEnabled ? SkyNavColor.accent : SkyNavColor.textTertiary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Flight Alerts")
                            .font(.skyNavBody)
                            .foregroundStyle(SkyNavColor.textPrimary)
                        Text("Gate changes, delays, boarding & landing")
                            .font(.skyNavCaption)
                            .foregroundStyle(SkyNavColor.textSecondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: SkyNavColor.accent))
            .padding(16)
            .skyNavCard()
            .onChange(of: notificationsEnabled) { _, _ in