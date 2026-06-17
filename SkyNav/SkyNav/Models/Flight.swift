import Foundation
import CoreLocation
import SwiftData

// MARK: - Core Types

struct Airline: Codable, Hashable, Identifiable {
    var id: String { iataCode }
    let iataCode: String
    let icaoCode: String
    let name: String
    let callsign: String?
}

struct Airport: Codable, Hashable, Identifiable {
    var id: String { iataCode }
    let iataCode: String
    let icaoCode: String
    let name: String
    let city: String
    let country: String
    let latitude: Double
    let longitude: Double
    let timezoneIdentifier: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var timezone: TimeZone {
        TimeZone(identifier: timezoneIdentifier) ?? .current
    }
}

struct Aircraft: Codable, Hashable {
    let registration: String
    let type: String
    let iataCode: String
}

struct AircraftPosition: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let speed: Double
    let heading: Double
    let timestamp: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Flight Status

enum FlightStatus: String, Codable, CaseIterable {
    case scheduled
    case delayed
    case boarding
    case departed
    case inFlight
    case landed
    case arrived
    case cancelled
    case diverted

    var delayMinutes: Int? { nil }

    var displayName: String {
        switch self {
        case .scheduled:  return "Scheduled"
        case .delayed:    return "Delayed"
        case .boarding:   return "Boarding"
        case .departed:   return "Departed"
        case .inFlight:   return "In Flight"
        case .landed:     return "Landed"
        case .arrived:    return "Arrived"
        case .cancelled:  return "Cancelled"
        case .diverted:   return "Diverted"
        }
    }

    var isActive: Bool {
        switch self {
        case .boarding, .departed, .inFlight: return true
        default: return false
        }
    }

    var isCompleted: Bool {
        switch self {
        case .arrived, .landed: return true
        default: return false
        }
    }
}

// MARK: - Flight (SwiftData Model)

@Model
final class Flight {
    @Attribute(.unique) var id: UUID
    var flightNumber: String
    var airlineIata: String
    var airlineName: String
    var airlineIcao: String

    var originIata: String
    var originName: String
    var originCity: String
    var originCountry: String
    var originLatitude: Double
    var originLongitude: Double
    var originTimezone: String

    var destinationIata: String
    var destinationName: String
    var destinationCity: String
    var destinationCountry: String
    var destinationLatitude: Double
    var destinationLongitude: Double
    var destinationTimezone: String

    var scheduledDeparture: Date
    var scheduledArrival: Date
    var estimatedDeparture: Date?
    var estimatedArrival: Date?
    var actualDeparture: Date?
    var actualArrival: Date?

    var statusRaw: String
    var delayMinutes: Int

    var departureGate: String?
    var arrivalGate: String?
    var departureTerminal: String?
    var arrivalTerminal: String?
    var baggageClaim: String?

    var aircraftRegistration: String?
    var aircraftType: String?
    var aircraftIata: String?

    var liveLatitude: Double?
    var liveLongitude: Double?
    var liveAltitude: Double?
    var liveSpeed: Double?
    var liveHeading: Double?
    var liveTimestamp: Date?

    var tripId: UUID?
    var addedAt: Date
    var notificationsEnabled: Bool
    var calendarEventID: String?

    init(
        id: UUID = UUID(),
        flightNumber: String,
        airline: Airline,
        origin: Airport,
        destination: Airport,
        scheduledDeparture: Date,
        scheduledArrival: Date,
        status: FlightStatus = .scheduled,
        delayMinutes: Int = 0,
        addedAt: Date = Date(),
        notificationsEnabled: Bool = true
    ) {
        self.id = id
        self.flightNumber = flightNumber
        self.airlineIata = airline.iataCode
        self.airlineName = airline.name
        self.airlineIcao = airline.icaoCode
        self.originIata = origin.iataCode
        self.originName = origin.name
        self.originCity = origin.city
        self.originCountry = origin.country
        self.originLatitude = origin.latitude
        self.originLongitude = origin.longitude
        self.originTimezone = origin.timezoneIdentifier
        self.destinationIata = destination.iataCode
        self.destinationName = destination.name
        self.destinationCity = destination.city
        self.destinationCountry = destination.country
        self.destinationLatitude = destination.latitude
        self.destinationLongitude = destination.longitude
        self.destinationTimezone = destination.timezoneIdentifier
        self.scheduledDeparture = scheduledDeparture
        self.scheduledArrival = scheduledArrival
        self.statusRaw = status.rawValue
        self.delayMinutes = delayMinutes
        self.addedAt = addedAt
        self.notificationsEnabled = notificationsEnabled
    }

    // MARK: Computed

    var status: FlightStatus {
        get { FlightStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }

    var airline: Airline {
        Airline(iataCode: airlineIata, icaoCode: airlineIcao, name: airlineName, callsign: nil)
    }

    var origin: Airport {
        Airport(iataCode: originIata, icaoCode: originIata, name: originName, city: originCity,
                country: originCountry, latitude: originLatitude, longitude: originLongitude,
                timezoneIdentifier: originTimezone)
    }

    var destination: Airport {
        Airport(iataCode: destinationIata, icaoCode: destinationIata, name: destinationName,
                city: destinationCity, country: destinationCountry, latitude: destinationLatitude,
                longitude: destinationLongitude, timezoneIdentifier: destinationTimezone)
    }

    var livePosition: AircraftPosition? {
        guard let lat = liveLatitude, let lon = liveLongitude,
              let alt = liveAltitude, let spd = liveSpeed,
              let hdg = liveHeading, let ts = liveTimestamp else { return nil }
        return AircraftPosition(latitude: lat, longitude: lon, altitude: alt,
                                speed: spd, heading: hdg, timestamp: ts)
    }

    var effectiveDeparture: Date {
        estimatedDeparture ?? scheduledDeparture
    }

    var effectiveArrival: Date {
        estimatedArrival ?? scheduledArrival
    }

    var flightDuration: TimeInterval {
        effectiveArrival.timeIntervalSince(effectiveDeparture)
    }

    var progressFraction: Double {
        guard status == .inFlight || status == .departed else {
            return status.isCompleted ? 1.0 : 0.0
        }
        let now = Date()
        let elapsed = now.timeIntervalSince(actualDeparture ?? effectiveDeparture)
        return min(max(elapsed / flightDuration, 0), 1)
    }

    var isUpcoming: Bool {
        effectiveDeparture > Date()
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(scheduledDeparture)
    }

    func updateLivePosition(_ position: AircraftPosition) {
        liveLatitude = position.latitude
        liveLongitude = position.longitude
        liveAltitude = position.altitude
        liveSpeed = position.speed
        liveHeading = position.heading
        liveTimestamp = position.timestamp
    }
}

// MARK: - Trip (SwiftData Model)

@Model
final class Trip {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var flightIds: [UUID]

    init(id: UUID = UUID(), name: String, flightIds: [UUID] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.flightIds = flightIds
        self.createdAt = createdAt
    }
}

// MARK: - Flight Search Result (transient, not persisted)

struct FlightSearchResult: Identifiable, Hashable {
    let id: UUID
    let flightNumber: String
    let airline: Airline
    let origin: Airport
    let destination: Airport
    let scheduledDeparture: Date
    let scheduledArrival: Date
    let status: FlightStatus
    let aircraft: Aircraft?
    let departureGate: String?
    let arrivalGate: String?

    func toFlight() -> Flight {
        Flight(
            flightNumber: flightNumber,
            airline: airline,
            origin: origin,
            destination: destination,
            scheduledDeparture: scheduledDeparture,
            scheduledArrival: scheduledArrival,
            status: status
        )
    }
}

// MARK: - Airport Live Data (transient)

struct AirportBoard: Identifiable {
    let id = UUID()
    let airport: Airport
    let departures: [FlightSearchResult]
    let arrivals: [FlightSearchResult]
    let weather: AirportWeather?
    let securityWaitMinutes: Int?
}

struct AirportWeather: Codable {
    let condition: String
    let temperatureCelsius: Double
    let windSpeedKmh: Double
    let windDirection: String
    let visibilityKm: Double

    var temperatureFahrenheit: Double { temperatureCelsius * 9 / 5 + 32 }
}

// MARK: - Notification Types

enum FlightNotificationType: String, CaseIterable {
    case gateChange
    case delay
    case cancellation
    case boarding
    case timeToLeave
    case landed
}
