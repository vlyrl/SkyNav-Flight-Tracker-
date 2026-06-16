import Foundation
import SwiftData
import Observation

enum FlightFilterMode: String, CaseIterable {
    case all = "All"
    case upcoming = "Upcoming"
    case past = "Past"
}

@Observable
@MainActor
final class HomeViewModel {
    var flights: [Flight] = []
    var showAddFlight = false
    var selectedFlight: Flight?
    var filterMode: FlightFilterMode = .upcoming
    var isRefreshing = false
    var errorMessage: String?

    let provider: FlightDataProvider
    private let persistence: PersistenceController
    private let pollingService: FlightPollingService
    private let notificationService: NotificationService

    init(
        persistence: PersistenceController = .shared,
        provider: FlightDataProvider
    ) {
        self.provider = provider
        self.persistence = persistence
        self.pollingService = FlightPollingService(provider: provider)
        self.notificationService = .shared
        setupPollingCallback()
        loadFlights()
    }

    func makeDetailViewModel(for flight: Flight) -> FlightDetailViewModel {
        FlightDetailViewModel(
            flight: flight,
            provider: provider,
            persistence: persistence,
            onDelete: { [weak self] in
                self?.selectedFlight = nil
                self?.loadFlights()
            }
        )
    }

    func makeAddFlightViewModel() -> AddFlightViewModel {
        let vm = AddFlightViewModel(provider: provider)
        vm.onFlightAdded = { [weak self] flight in self?.addFlight(flight) }
        return vm
    }

    // MARK: - Computed

    var filteredFlights: [Flight] {
        switch filterMode {
        case .all:      return flights.sorted { $0.scheduledDeparture < $1.scheduledDeparture }
        case .upcoming: return upcomingFlights
        case .past:     return pastFlights
        }
    }

    var upcomingFlights: [Flight] {
        flights.filter { $0.isUpcoming || $0.status.isActive }
            .sorted { $0.scheduledDeparture < $1.scheduledDeparture }
    }

    var pastFlights: [Flight] {
        flights.filter { $0.status.isCompleted && !$0.isUpcoming }
            .sorted { $0.scheduledDeparture > $1.scheduledDeparture }
    }

    var activeFlight: Flight? {
        flights.first { $0.status.isActive }
    }

    // MARK: - Actions

    func loadFlights() {
        flights = (try? persistence.fetchAllFlights()) ?? []
        startPollingActive()
        WidgetDataBridge.shared.write(flights: flights)
    }

    func refresh() async {
        isRefreshing = true
        loadFlights()
        try? await Task.sleep(nanoseconds: 500_000_000)
        isRefreshing = false
    }

    func addFlight(_ flight: Flight) {
        persistence.insert(flight)
        flights.append(flight)
        if flight.notificationsEnabled {
            notificationService.scheduleTimeToLeave(for: flight)
        }
        startPolling(for: flight)
        WidgetDataBridge.shared.write(flights: flights)
        SkyNavHaptic.success()
    }

    func deleteFlight(_ flight: Flight) {
        pollingService.stopPolling(flightId: flight.id)
        notificationService.cancelAll(for: flight.id)
        persistence.delete(flight)
        flights.removeAll { $0.id == flight.id }
        WidgetDataBridge.shared.write(flights: flights)
        SkyNavHaptic.medium()
    }

    // MARK: - Polling

    private func startPollingActive() {
        flights.filter { $0.isUpcoming || $0.status.isActive }.forEach { startPolling(for: $0) }
    }

    private func startPolling(for flight: Flight) {
        pollingService.startPolling(
            flightId: flight.id,
            flightNumber: flight.flightNumber,
            scheduledDeparture: flight.scheduledDeparture,
            status: flight.status
        )
    }

    private func setupPollingCallback() {
        pollingService.onStatusUpdate = { [weak self] flightId, update in
            guard let self, let flight = self.flights.first(where: { $0.id == flightId }) else { return }
            self.applyUpdate(update, to: flight)
        }
    }

    private func applyUpdate(_ update: FlightStatusUpdate, to flight: Flight) {
        let oldStatus = flight.status
        let oldGate   = flight.departureGate
        let oldDelay  = flight.delayMinutes

        flight.statusRaw           = update.status.rawValue
        flight.delayMinutes        = update.delayMinutes
        flight.estimatedDeparture  = update.estimatedDeparture
        flight.estimatedArrival    = update.estimatedArrival
        flight.actualDeparture     = update.actualDeparture
        flight.actualArrival       = update.actualArrival
        flight.departureGate       = update.departureGate
        flight.arrivalGate         = update.arrivalGate
        flight.departureTerminal   = update.departureTerminal
        flight.arrivalTerminal     = update.arrivalTerminal
        flight.baggageClaim        = update.baggageClaim
        if let pos = update.livePosition { flight.updateLivePosition(pos) }
        persistence.save()

        guard flight.notificationsEnabled else { return }
        if update.status == .cancelled && oldStatus != .cancelled {
            notificationService.sendCancellation(for: flight)
        } else if update.status == .boarding && oldStatus != .boarding {
            notificationService.sendBoarding(for: flight)
        } else if let gate = update.departureGate, gate != oldGate, oldGate != nil {
            notificationService.sendGateChange(for: flight, newGate: gate)
        } else if update.delayMinutes > oldDelay && update.delayMinutes > 0 {
            notificationService.sendDelay(for: flight, delayMinutes: update.delayMinutes)
        } else if (update.status == .landed || update.status == .arrived) && !oldStatus.isCompleted {
            notificationService.sendLanded(for: flight)
        }
    }
}
