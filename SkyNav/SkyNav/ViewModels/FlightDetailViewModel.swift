import Foundation
import Observation

@Observable
@MainActor
final class FlightDetailViewModel {
    var flight: Flight
    var airportBoard: AirportBoard?
    var isRefreshing = false
    var errorMessage: String?
    var showFullMap = false

    private let provider: FlightDataProvider
    private let persistence: PersistenceController
    private let pollingService: FlightPollingService
    private var onDelete: (() -> Void)?

    init(flight: Flight, provider: FlightDataProvider, persistence: PersistenceController = .shared, onDelete: (() -> Void)? = nil) {
        self.flight = flight
        self.provider = provider
        self.persistence = persistence
        self.onDelete = onDelete
        self.pollingService = FlightPollingService(provider: provider)
        setupPolling()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            async let statusUpdate = provider.fetchFlightStatus(flightNumber: flight.flightNumber, date: flight.scheduledDeparture)
            async let board = provider.fetchAirportBoard(iataCode: flight.originIata)
            let (update, fetchedBoard) = try await (statusUpdate, board)
            applyUpdate(update)
            airportBoard = fetchedBoard
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleNotifications() {
        flight.notificationsEnabled.toggle()
        persistence.save()
        if flight.notificationsEnabled {
            NotificationService.shared.scheduleTimeToLeave(for: flight)
        } else {
            NotificationService.shared.cancelAll(for: flight.id)
        }
    }

    func deleteAndDismiss() {
        pollingService.stopAll()
        NotificationService.shared.cancelAll(for: flight.id)
        persistence.delete(flight)
        onDelete?()
    }

    var flightSummaryText: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return """
        \(flight.flightNumber) · \(flight.airlineName)
        \(flight.originCity) (\(flight.originIata)) → \(flight.destinationCity) (\(flight.destinationIata))
        Departs: \(df.string(from: flight.effectiveDeparture))
        Arrives: \(df.string(from: flight.effectiveArrival))
        Status: \(flight.status.displayName)
        """
    }

    // MARK: - Private

    private func setupPolling() {
        pollingService.onStatusUpdate = { [weak self] _, update in
            self?.applyUpdate(update)
        }
        pollingService.startPolling(
            flightId: flight.id,
            flightNumber: flight.flightNumber,
            scheduledDeparture: flight.scheduledDeparture,
            status: flight.status
        )
    }

    private func applyUpdate(_ update: FlightStatusUpdate) {
        flight.statusRaw          = update.status.rawValue
        flight.delayMinutes       = update.delayMinutes
        flight.estimatedDeparture = update.estimatedDeparture
        flight.estimatedArrival   = update.estimatedArrival
        flight.actualDeparture    = update.actualDeparture
        flight.actualArrival      = update.actualArrival
        flight.departureGate      = update.departureGate
        flight.arrivalGate        = update.arrivalGate
        flight.departureTerminal  = update.departureTerminal
        flight.arrivalTerminal    = update.arrivalTerminal
        flight.baggageClaim       = update.baggageClaim
        if let pos = update.livePosition { flight.updateLivePosition(pos) }
        persistence.save()
    }
}
