import Foundation
import Observation

@Observable
@MainActor
final class TripViewModel {
    var trips: [Trip] = []
    var flights: [Flight] = []
    var showCreateTrip = false
    var newTripName = ""
    var selectedFlightIds: Set<UUID> = []

    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        load()
    }

    func load() {
        trips   = (try? persistence.fetchAllTrips()) ?? []
        flights = (try? persistence.fetchAllFlights()) ?? []
    }

    func flightsForTrip(_ trip: Trip) -> [Flight] {
        trip.flightIds.compactMap { id in flights.first { $0.id == id } }
            .sorted { $0.scheduledDeparture < $1.scheduledDeparture }
    }

    func layoverDuration(between a: Flight, and b: Flight) -> TimeInterval? {
        guard a.destinationIata == b.originIata else { return nil }
        let layover = b.effectiveDeparture.timeIntervalSince(a.effectiveArrival)
        return layover > 0 ? layover : nil
    }

    func createTrip() {
        guard !newTripName.isEmpty, !selectedFlightIds.isEmpty else { return }
        let trip = Trip(name: newTripName, flightIds: Array(selectedFlightIds))
        persistence.insert(trip)
        trips.insert(trip, at: 0)
        newTripName = ""
        selectedFlightIds = []
        showCreateTrip = false
        SkyNavHaptic.success()
    }

    func deleteTrip(_ trip: Trip) {
        persistence.delete(trip)
        trips.removeAll { $0.id == trip.id }
    }

    var unassignedFlights: [Flight] {
        let assignedIds = Set(trips.flatMap { $0.flightIds })
        return flights.filter { !assignedIds.contains($0.id) }
    }
}
