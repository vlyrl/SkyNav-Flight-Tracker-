import ActivityKit
import Foundation

// Shared between main app (for Activity.request/update) and widget extension (for rendering).
// Included in both targets via project.yml sources.

public struct FlightActivityAttributes: ActivityAttributes {
    public typealias FlightActivityStatus = ContentState

    public let flightNumber: String
    public let airlineName: String
    public let originIata: String
    public let originCity: String
    public let destinationIata: String
    public let destinationCity: String
    public let scheduledDeparture: Date
    public let scheduledArrival: Date

    public struct ContentState: Codable, Hashable {
        public var status: String
        public var delayMinutes: Int
        public var estimatedDeparture: Date?
        public var estimatedArrival: Date?
        public var departureGate: String?
        public var progressFraction: Double
        public var liveAltitudeFt: Double?
        public var liveSpeedKnots: Double?
    }

    public init(
        flightNumber: String, airlineName: String,
        originIata: String, originCity: String,
        destinationIata: String, destinationCity: String,
        scheduledDeparture: Date, scheduledArrival: Date
    ) {
        self.flightNumber = flightNumber
        self.airlineName = airlineName
        self.originIata = originIata
        self.originCity = originCity
        self.destinationIata = destinationIata
        self.destinationCity = destinationCity
        self.scheduledDeparture = scheduledDeparture
        self.scheduledArrival = scheduledArrival
    }
}
