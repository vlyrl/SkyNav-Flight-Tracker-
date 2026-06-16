import Foundation

// MARK: - AeroAPI v4 Codable Response Types
// All field names and nesting match the live AeroAPI v4 JSON schema.

// MARK: Airport node (embedded in flight objects)

struct AeroAirport: Codable {
    let code: String?       // ICAO (e.g. "KJFK")
    let codeIata: String?   // IATA (e.g. "JFK")
    let timezone: String?
    let name: String?
    let city: String?
    let country: String?

    enum CodingKeys: String, CodingKey {
        case code
        case codeIata  = "code_iata"
        case timezone, name, city, country
    }
}

// MARK: Live position embedded in flight

struct AeroPosition: Codable {
    // AeroAPI returns altitude in hundreds of feet (FL350 = 350). Multiply by 100 for feet.
    let altitude: Int?
    let groundspeed: Int?   // knots
    let heading: Int?
    let latitude: Double?
    let longitude: Double?
    let timestamp: String?
    let updateType: String? // "P" = position, "D" = derived

    enum CodingKeys: String, CodingKey {
        case altitude, groundspeed, heading, latitude, longitude, timestamp
        case updateType = "update_type"
    }
}

// MARK: Flight (used in flight search, status, and airport board results)

struct AeroFlight: Codable {
    let ident: String?
    let identIcao: String?
    let identIata: String?
    let operatorName: String?   // "operator" is a Swift keyword — mapped via CodingKeys
    let operatorIcao: String?
    let operatorIata: String?
    let flightNumber: String?
    let registration: String?
    let aircraftType: String?   // ICAO aircraft type (e.g. "B738")

    // Scheduled times (ISO8601 UTC strings)
    let scheduledOut: String?   // Scheduled gate departure
    let scheduledIn: String?    // Scheduled gate arrival
    let estimatedOut: String?
    let estimatedIn: String?
    let actualOut: String?
    let actualIn: String?

    let departureDelay: Int?    // seconds
    let arrivalDelay: Int?      // seconds
    let progressPercent: Int?   // 0–100, nil when not airborne

    let status: String?         // Human-readable status string from AeroAPI
    let gateOrigin: String?
    let gateDestination: String?
    let terminalOrigin: String?
    let terminalDestination: String?
    let baggageClaim: String?
    let cancelled: Bool?
    let diverted: Bool?

    let origin: AeroAirport?
    let destination: AeroAirport?
    let lastPosition: AeroPosition?

    enum CodingKeys: String, CodingKey {
        case ident
        case identIcao        = "ident_icao"
        case identIata        = "ident_iata"
        case operatorName     = "operator"
        case operatorIcao     = "operator_icao"
        case operatorIata     = "operator_iata"
        case flightNumber     = "flight_number"
        case registration
        case aircraftType     = "aircraft_type"
        case scheduledOut     = "scheduled_out"
        case scheduledIn      = "scheduled_in"
        case estimatedOut     = "estimated_out"
        case estimatedIn      = "estimated_in"
        case actualOut        = "actual_out"
        case actualIn         = "actual_in"
        case departureDelay   = "departure_delay"
        case arrivalDelay     = "arrival_delay"
        case progressPercent  = "progress_percent"
        case status
        case gateOrigin       = "gate_origin"
        case gateDestination  = "gate_destination"
        case terminalOrigin   = "terminal_origin"
        case terminalDestination = "terminal_destination"
        case baggageClaim     = "baggage_claim"
        case cancelled, diverted, origin, destination
        case lastPosition     = "last_position"
    }
}

// MARK: - Response Envelopes

struct AeroFlightsResponse: Codable {
    let flights: [AeroFlight]
    let numPages: Int?

    enum CodingKeys: String, CodingKey {
        case flights
        case numPages = "num_pages"
    }
}

struct AeroDeparturesResponse: Codable {
    let departures: [AeroFlight]
    let numPages: Int?

    enum CodingKeys: String, CodingKey {
        case departures
        case numPages = "num_pages"
    }
}

struct AeroArrivalsResponse: Codable {
    let arrivals: [AeroFlight]
    let numPages: Int?

    enum CodingKeys: String, CodingKey {
        case arrivals
        case numPages = "num_pages"
    }
}

// MARK: - Weather

struct AeroWeatherCondition: Codable {
    let tempAir: Double?        // Celsius
    let windSpeed: Int?         // knots
    let windSpeedGust: Int?
    let windDirection: Int?     // degrees
    let visibility: Double?     // statute miles
    let conditions: String?
    let cloudCondition: String?
    let flightCategory: String? // VFR, IFR, MVFR, LIFR

    enum CodingKeys: String, CodingKey {
        case tempAir        = "temp_air"
        case windSpeed      = "wind_speed"
        case windSpeedGust  = "wind_speed_gust"
        case windDirection  = "wind_direction"
        case visibility, conditions
        case cloudCondition  = "cloud_condition"
        case flightCategory  = "flight_category"
    }
}

struct AeroWeatherResponse: Codable {
    let conditions: [AeroWeatherCondition]?
    let rawData: String?

    enum CodingKeys: String, CodingKey {
        case conditions
        case rawData = "raw_data"
    }
}
