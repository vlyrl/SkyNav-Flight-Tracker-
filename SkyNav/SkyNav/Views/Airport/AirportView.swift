import SwiftUI

// MARK: - AirportView

struct AirportView: View {
    let iataCode: String

    @State private var viewModel: AirportViewModel
    @State private var boardSegment: BoardSegment = .departures
    @State private var showCelsius: Bool = true
    @State private var rowsAppeared: Bool = false

    enum BoardSegment: String, CaseIterable {
        case departures = "Departures"
        case arrivals = "Arrivals"
    }

    init(iataCode: String, provider: FlightDataProvider = MockFlightDataService()) {
        self.iataCode = iataCode
        _viewModel = State(initialValue: AirportViewModel(iataCode: iataCode, provider: provider))
    }

    var body: some View {
        ZStack {
            SkyNavColor.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.board == nil {
                airportLoadingSkeleton
            } else if let error = viewModel.errorMessage, viewModel.board == nil {
                errorView(message: error)
            } else {
                boardContent
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(viewModel.board?.airport.name ?? iataCode)
                        .font(.skyNavHeadline)
                        .foregroundStyle(SkyNavColor.textPrimary)
                        .lineLimit(1)
                    Text(iataCode)
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.accent)
                }
            }
        }
        .task {
            await viewModel.load()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                rowsAppeared = true
            }
        }
        .refreshable {
            rowsAppeared = false
            await viewModel.refresh()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                rowsAppeared = true
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Main Board Content

    private var boardContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Airport header card
                if let board = viewModel.board {
                    airportHeaderCard(board: board)
                }

                // Ground delays & programs
                AirportDelaysView(iataCode: iataCode)
                    .padding(.horizontal, 20)

                // Segmented control
                boardSegmentPicker
                    .padding(.horizontal, 20)

                // Flight list
                let flights = currentFlights
                if flights.isEmpty {
                    emptyBoardView
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(flights.enumerated()), id: \.element.id) { index, flight in
                            AirportFlightRow(
                                result: flight,
                                boardSegment: boardSegment
                            )
                            .padding(.horizontal, 20)
                            .opacity(rowsAppeared ? 1 : 0)
                            .offset(y: rowsAppeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.75)
                                    .delay(Double(index) * 0.05),
                                value: rowsAppeared
                            )
                        }
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Airport Header Card

    private func airportHeaderCard(board: AirportBoard) -> some View {
        VStack(spacing: 12) {
            // Ground delay banner (if active programs exist)
            let programs = AirportDelayService.activePrograms(for: iataCode)
            if let label = AirportDelayService.badgeLabel(for: programs) {
                let isStop = label.hasPrefix("GROUND")
                HStack(spacing: 10) {
                    Image(systemName: isStop ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text(label)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Spacer()
                    Text("FAA Program Active")
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.textTertiary)
                }
                .foregroundStyle(isStop ? SkyNavColor.statusCancelled : SkyNavColor.statusDelayed)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background((isStop ? SkyNavColor.statusCancelled : SkyNavColor.statusDelayed).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            (isStop ? SkyNavColor.statusCancelled : SkyNavColor.statusDelayed).opacity(0.3),
                            lineWidth: 1
                        )
                )
            }

            // Weather row
            if let weather = board.weather {
                weatherCard(weather: weather)
            }

            // Security wait badge
            if let wait = board.securityWaitMinutes {
                securityBadge(minutes: wait)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Weather Card

    private func weatherCard(weather: AirportWeather) -> some View {
        HStack(spacing: 16) {
            Image(systemName: weatherIcon(for: weather.condition))
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(SkyNavColor.accent)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(weather.condition)
                    .font(.skyNavBody)
                    .foregroundStyle(SkyNavColor.textPrimary)

                HStack(spacing: 8) {
                    Label(String(format: "%.0f km/h %@", weather.windSpeedKmh, weather.windDirection),
                          systemImage: "wind")
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.textSecondary)

                    Text("·")
                        .foregroundStyle(SkyNavColor.textTertiary)

                    Label(String(format: "%.0f km vis", weather.visibilityKm),
                          systemImage: "eye")
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.textSecondary)
                }
            }

            Spacer()

            Button {
                SkyNavHaptic.select()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showCelsius.toggle()
                }
            } label: {
                VStack(spacing: 2) {
                    Text(showCelsius
                        ? String(format: "%.0f°C", weather.temperatureCelsius)
                        : String(format: "%.0f°F", weather.temperatureFahrenheit))
                        .font(.skyNavTitle)
                        .foregroundStyle(SkyNavColor.textPrimary)

                    Text(showCelsius ? "tap for °F" : "tap for °C")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(SkyNavColor.textTertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .skyNavGlassCard()
    }

    // MARK: - Security Badge

    private func securityBadge(minutes: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(securityColor(minutes: minutes))

            VStack(alignment: .leading, spacing: 2) {
                Text("Security Wait")
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textSecondary)
                Text("~\(minutes) min")
                    .font(.skyNavHeadline)
                    .foregroundStyle(securityColor(minutes: minutes))
            }

            Spacer()

            Circle()
                .fill(securityColor(minutes: minutes))
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .fill(securityColor(minutes: minutes).opacity(0.3))
                        .frame(width: 18, height: 18)
                )
        }
        .padding(16)
        .background(securityColor(minutes: minutes).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(securityColor(minutes: minutes).opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Segment Picker

    private var boardSegmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(BoardSegment.allCases, id: \.self) { segment in
                Button {
                    SkyNavHaptic.select()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        boardSegment = segment
                        rowsAppeared = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                            rowsAppeared = true
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: segment == .departures ? "airplane.departure" : "airplane.arrival")
                            .font(.system(size: 12, weight: .semibold))
                        Text(segment.rawValue)
                            .font(.skyNavCaption)
                            .fontWeight(boardSegment == segment ? .semibold : .regular)
                    }
                    .foregroundStyle(boardSegment == segment ? SkyNavColor.textPrimary : SkyNavColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(boardSegment == segment ? SkyNavColor.surfaceRaised : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .modifier(BoardPickerBackgroundModifier())
    }

    // MARK: - Empty Board

    private var emptyBoardView: some View {
        VStack(spacing: 14) {
            Image(systemName: boardSegment == .departures ? "airplane.departure" : "airplane.arrival")
                .font(.system(size: 36))
                .foregroundStyle(SkyNavColor.textTertiary)

            Text("No \(boardSegment.rawValue)")
                .font(.skyNavHeadline)
                .foregroundStyle(SkyNavColor.textSecondary)

            Text("Live board data not available right now.")
                .font(.skyNavBody)
                .foregroundStyle(SkyNavColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .padding(.horizontal, 20)
    }

    // MARK: - Loading Skeleton

    private var airportLoadingSkeleton: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Weather card skeleton
                HStack(spacing: 16) {
                    ShimmerRect(width: 44, height: 44, cornerRadius: 12)
                    VStack(alignment: .leading, spacing: 8) {
                        ShimmerRect(width: 120, height: 16)
                        ShimmerRect(width: 180, height: 12)
                    }
                    Spacer()
                    ShimmerRect(width: 56, height: 32, cornerRadius: 8)
                }
                .padding(16)
                .skyNavCard()
                .padding(.horizontal, 20)

                // Segment picker skeleton
                ShimmerRect(height: 46, cornerRadius: 14)
                    .padding(.horizontal, 20)

                // Row skeletons
                ForEach(0..<6, id: \.self) { _ in
                    AirportFlightRowSkeleton()
                        .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(SkyNavColor.textTertiary)

            VStack(spacing: 8) {
                Text("Couldn't Load Airport")
                    .font(.skyNavTitle)
                    .foregroundStyle(SkyNavColor.textPrimary)
                Text(message)
                    .font(.skyNavBody)
                    .foregroundStyle(SkyNavColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                SkyNavHaptic.medium()
                Task { await viewModel.load() }
            } label: {
                Text("Retry")
                    .font(.skyNavHeadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(SkyNavColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(40)
    }

    // MARK: - Helpers

    private var currentFlights: [FlightSearchResult] {
        guard let board = viewModel.board else { return [] }
        return boardSegment == .departures ? board.departures : board.arrivals
    }

    private func weatherIcon(for condition: String) -> String {
        let lower = condition.lowercased()
        if lower.contains("thunder") { return "cloud.bolt.fill" }
        if lower.contains("snow") { return "snowflake" }
        if lower.contains("rain") || lower.contains("shower") { return "cloud.rain.fill" }
        if lower.contains("cloud") || lower.contains("overcast") { return "cloud.fill" }
        if lower.contains("fog") || lower.contains("mist") { return "cloud.fog.fill" }
        if lower.contains("wind") { return "wind" }
        return "sun.max.fill"
    }

    private func securityColor(minutes: Int) -> Color {
        if minutes < 15 { return SkyNavColor.statusOnTime }
        if minutes < 30 { return SkyNavColor.statusDelayed }
        return SkyNavColor.statusCancelled
    }
}

// MARK: - iOS 26 Glass Modifiers

private struct BoardPickerBackgroundModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
        } else {
            content
                .background(SkyNavColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(SkyNavColor.surfaceBorder, lineWidth: 0.5)
                )
        }
    }
}

// MARK: - AirportFlightRow

struct AirportFlightRow: View {
    let result: FlightSearchResult
    let boardSegment: AirportView.BoardSegment

    var body: some View {
        HStack(spacing: 14) {
            // Time column
            VStack(alignment: .leading, spacing: 2) {
                Text(result.scheduledDeparture, style: .time)
                    .font(.skyNavMono)
                    .foregroundStyle(SkyNavColor.textPrimary)
                if boardSegment == .departures {
                    Text(result.destination.city)
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.textSecondary)
                        .lineLimit(1)
                } else {
                    Text(result.origin.city)
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 90, alignment: .leading)

            Divider()
                .frame(height: 36)
                .background(SkyNavColor.surfaceBorder)

            // IATA code
            Text(boardSegment == .departures ? result.destination.iataCode : result.origin.iataCode)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(SkyNavColor.textPrimary)
                .frame(width: 40)

            // Airline + flight number
            VStack(alignment: .leading, spacing: 2) {
                Text(result.flightNumber)
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textPrimary)
                    .fontWeight(.semibold)
                Text(result.airline.name)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(SkyNavColor.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                StatusPill(status: result.status, showIcon: false)

                if let gate = result.departureGate {
                    Text("Gate \(gate)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(SkyNavColor.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(SkyNavColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(SkyNavColor.surfaceBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - AirportFlightRowSkeleton

struct AirportFlightRowSkeleton: View {
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                ShimmerRect(width: 60, height: 18)
                ShimmerRect(width: 80, height: 12)
            }
            .frame(width: 90, alignment: .leading)

            Divider().frame(height: 36)

            ShimmerRect(width: 36, height: 20)

            VStack(alignment: .leading, spacing: 6) {
                ShimmerRect(width: 50, height: 14)
                ShimmerRect(width: 80, height: 11)
            }

            Spacer()

            ShimmerRect(width: 60, height: 22, cornerRadius: 11)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(SkyNavColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(SkyNavColor.surfaceBorder, lineWidth: 0.5)
        )
    }
}
