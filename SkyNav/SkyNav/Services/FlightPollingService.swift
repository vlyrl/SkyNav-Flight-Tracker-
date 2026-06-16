import Foundation
import Combine

// Polls live flight status for active and upcoming flights.
// Automatically adjusts polling frequency based on flight phase.

@Observable
final class FlightPollingService {
    private let provider: FlightDataProvider
    private var tasks: [UUID: Task<Void, Never>] = [:]

    var onStatusUpdate: ((UUID, FlightStatusUpdate) -> Void)?

    init(provider: FlightDataProvider) {
        self.provider = provider
    }

    func startPolling(flightId: UUID, flightNumber: String, scheduledDeparture: Date, status: FlightStatus) {
        guard tasks[flightId] == nil else { return }

        tasks[flightId] = Task {
            while !Task.isCancelled {
                do {
                    let update = try await provider.fetchFlightStatus(
                        flightNumber: flightNumber,
                        date: scheduledDeparture
                    )
                    if !Task.isCancelled {
                        onStatusUpdate?(flightId, update)
                    }
                } catch {
                    // Silently continue polling on transient errors
                }

                let interval = pollingInterval(for: scheduledDeparture)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopPolling(flightId: UUID) {
        tasks[flightId]?.cancel()
        tasks.removeValue(forKey: flightId)
    }

    func stopAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    // Aggressive polling close to departure/arrival, relaxed otherwise
    private func pollingInterval(for scheduledDeparture: Date) -> Double {
        let now = Date()
        let secondsUntilDep = scheduledDeparture.timeIntervalSince(now)

        switch secondsUntilDep {
        case ..<(-3600): return 60    // past arrival window
        case ..<0:       return 20    // in-flight
        case ..<1800:    return 30    // within 30 min of departure
        case ..<7200:    return 60    // within 2 hours
        default:         return 300   // more than 2 hours away
        }
    }
}
