import Foundation

// MARK: - Flight Data Provider Protocol
// Swap MockFlightDataService for a real implementation (AviationStack, FlightAware, AeroDataBox)
// by conforming to this protocol and changing the injection in SkyNavApp.

protocol FlightDataProvider: AnyObject {
    /// Search for flights by flight number on a given date.
    func searchFlight(number: String, date: Date) async throws -> [FlightSearchResult]

    /// Fetch live status for a tracked flight.
    func fetchFlightStatus(flightNumber: String, date: Date) async throws -> FlightStatusUpdate

    /// Fetch live aircraft position for an in-flight tracked flight.
    func fetchLivePosition(flightNumber: String) async throws -> AircraftPosition?

    /// Fetch departure/arrival board for an airport.
    func fetchAirportBoard(iataCode: String) async throws -> AirportBoard

    /// Fetch airport weather.
    func fetchWeather(iataCode: String) async throws -> AirportWeather
}

// MARK: - Status Update (from polling)

struct FlightStatusUpdate {
    let flightNumber: String
    let status: FlightStatus
    let delayMinutes: Int
    let estimatedDeparture: Date?
    let estimatedArrival: Date?
    let actualDeparture: Date?
    let actualArrival: Date?
    let departureGate: String?
    let arrivalGate: String?
    let departureTerminal: String?
    let arrivalTerminal: String?
    let baggageClaim: String?
    let livePosition: AircraftPosition?
}

// MARK: - Errors

enum FlightDataError: LocalizedError {
    case flightNotFound
    case networkUnavailable
    case rateLimited
    case apiKeyMissing
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .flightNotFound:    return "Flight not found. Check the flight number and date."
        case .networkUnavailable: return "No internet connection."
        case .rateLimited:        return "Too many requests. Try again in a moment."
        case .apiKeyMissing:      return "Flight data API key not configured."
        case .invalidResponse:    return "Received an unexpected response from the server."
        }
    }
}
