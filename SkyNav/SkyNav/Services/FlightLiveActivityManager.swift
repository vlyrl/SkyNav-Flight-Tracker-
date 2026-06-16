import ActivityKit
import Foundation

// Manages starting, updating, and ending Live Activities for tracked flights.

final class FlightLiveActivityManager {
    static let shared = FlightLiveActivityManager()
    private var activities: [UUID: Activity<FlightActivityAttributes>] = [:]
    private init() {}

    func start(for flight: Flight) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              activities[flight.id] == nil else { return }

        let attrs = FlightActivityAttributes(
            flightNumber:       flight.flightNumber,
            airlineName:        flight.airlineName,
            originIata:         flight.originIata,
            originCity:         flight.originCity,
            destinationIata:    flight.destinationIata,
            destinationCity:    flight.destinationCity,
            scheduledDeparture: flight.scheduledDeparture,
            scheduledArrival:   flight.scheduledArrival
        )
        let state = contentState(for: flight)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60))
        if let activity = try? Activity.request(attributes: attrs, content: content) {
            activities[flight.id] = activity
        }
    }

    func update(for flight: Flight) {
        guard let activity = activities[flight.id] else { return }
        let content = ActivityContent(state: contentState(for: flight), staleDate: Date().addingTimeInterval(60))
        Task { await activity.update(content) }
    }

    func end(for flightId: UUID) {
        guard let activity = activities[flightId] else { return }
        Task { await activity.end(nil, dismissalPolicy: .after(Date().addingTimeInterval(30))) }
        activities.removeValue(forKey: flightId)
    }

    private func contentState(for flight: Flight) -> FlightActivityAttributes.ContentState {
        FlightActivityAttributes.ContentState(
            status:             flight.status.rawValue,
            delayMinutes:       flight.delayMinutes,
            estimatedDeparture: flight.estimatedDeparture,
            estimatedArrival:   flight.estimatedArrival,
            departureGate:      flight.departureGate,
            progressFraction:   flight.progressFraction,
            liveAltitudeFt:     flight.liveAltitude,
            liveSpeedKnots:     flight.liveSpeed
        )
    }
}
