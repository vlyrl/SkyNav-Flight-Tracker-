import Foundation
import CoreLocation

// MARK: - Mock Flight Data Service
// Realistic mock data. Replace with a real FlightDataProvider implementation.

final class MockFlightDataService: FlightDataProvider {

    // MARK: - Static Reference Data

    static let airlines: [String: Airline] = [
        "AA": Airline(iataCode: "AA", icaoCode: "AAL", name: "American Airlines", callsign: "AMERICAN"),
        "UA": Airline(iataCode: "UA", icaoCode: "UAL", name: "United Airlines", callsign: "UNITED"),
        "DL": Airline(iataCode: "DL", icaoCode: "DAL", name: "Delta Air Lines", callsign: "DELTA"),
        "SW": Airline(iataCode: "SW", icaoCode: "WN",  name: "Southwest Airlines", callsign: "SOUTHWEST"),
        "B6": Airline(iataCode: "B6", icaoCode: "JBU", name: "JetBlue Airways", callsign: "JETBLUE"),
        "AS": Airline(iataCode: "AS", icaoCode: "ASA", name: "Alaska Airlines", callsign: "ALASKA"),
        "BA": Airline(iataCode: "BA", icaoCode: "BAW", name: "British Airways", callsign: "SPEEDBIRD"),
        "LH": Airline(iataCode: "LH", icaoCode: "DLH", name: "Lufthansa", callsign: "LUFTHANSA"),
        "AF": Airline(iataCode: "AF", icaoCode: "AFR", name: "Air France", callsign: "AIRFRANS"),
        "EK": Airline(iataCode: "EK", icaoCode: "UAE", name: "Emirates", callsign: "EMIRATES"),
    ]

    static let airports: [String: Airport] = [
        "JFK": Airport(iataCode: "JFK", icaoCode: "KJFK", name: "John F. Kennedy International",
                       city: "New York", country: "United States",
                       latitude: 40.6413, longitude: -73.7781, timezoneIdentifier: "America/New_York"),
        "LAX": Airport(iataCode: "LAX", icaoCode: "KLAX", name: "Los Angeles International",
                       city: "Los Angeles", country: "United States",
                       latitude: 33.9425, longitude: -118.4081, timezoneIdentifier: "America/Los_Angeles"),
        "ORD": Airport(iataCode: "ORD", icaoCode: "KORD", name: "O'Hare International",
                       city: "Chicago", country: "United States",
                       latitude: 41.9742, longitude: -87.9073, timezoneIdentifier: "America/Chicago"),
        "ATL": Airport(iataCode: "ATL", icaoCode: "KATL", name: "Hartsfield-Jackson Atlanta International",
                       city: "Atlanta", country: "United States",
                       latitude: 33.6407, longitude: -84.4277, timezoneIdentifier: "America/New_York"),
        "SFO": Airport(iataCode: "SFO", icaoCode: "KSFO", name: "San Francisco International",
                       city: "San Francisco", country: "United States",
                       latitude: 37.6213, longitude: -122.379, timezoneIdentifier: "America/Los_Angeles"),
        "BOS": Airport(iataCode: "BOS", icaoCode: "KBOS", name: "Logan International",
                       city: "Boston", country: "United States",
                       latitude: 42.3656, longitude: -71.0096, timezoneIdentifier: "America/New_York"),
        "MIA": Airport(iataCode: "MIA", icaoCode: "KMIA", name: "Miami International",
                       city: "Miami", country: "United States",
                       latitude: 25.7959, longitude: -80.2870, timezoneIdentifier: "America/New_York"),
        "DEN": Airport(iataCode: "DEN", icaoCode: "KDEN", name: "Denver International",
                       city: "Denver", country: "United States",
                       latitude: 39.8561, longitude: -104.6737, timezoneIdentifier: "America/Denver"),
        "SEA": Airport(iataCode: "SEA", icaoCode: "KSEA", name: "Seattle-Tacoma International",
                       city: "Seattle", country: "United States",
                       latitude: 47.4502, longitude: -122.3088, timezoneIdentifier: "America/Los_Angeles"),
        "LHR": Airport(iataCode: "LHR", icaoCode: "EGLL", name: "London Heathrow",
                       city: "London", country: "United Kingdom",
                       latitude: 51.4700, longitude: -0.4543, timezoneIdentifier: "Europe/London"),
        "CDG": Airport(iataCode: "CDG", icaoCode: "LFPG", name: "Charles de Gaulle",
                       city: "Paris", country: "France",
                       latitude: 49.0097, longitude: 2.5479, timezoneIdentifier: "Europe/Paris"),
        "FRA": Airport(iataCode: "FRA", icaoCode: "EDDF", name: "Frankfurt Airport",
                       city: "Frankfurt", country: "Germany",
                       latitude: 50.0379, longitude: 8.5622, timezoneIdentifier: "Europe/Berlin"),
        "DXB": Airport(iataCode: "DXB", icaoCode: "OMDB", name: "Dubai International",
                       city: "Dubai", country: "United Arab Emirates",
                       latitude: 25.2528, longitude: 55.3644, timezoneIdentifier: "Asia/Dubai"),
    ]

    // MARK: - Mock Flight Templates

    private let flightTemplates: [(String, String, String, String, Int, Int, String?)] = [
        // (flightNum, airlineIata, originIata, destIata, durationMins, delaySecs, gate)
        ("AA100",  "AA", "JFK", "LAX", 335, 0,    "B22"),
        ("AA101",  "AA", "LAX", "JFK", 310, 1200, "C14"),
        ("UA238",  "UA", "ORD", "SFO", 285, 0,    "F7"),
        ("DL451",  "DL", "ATL", "BOS", 155, 600,  "A12"),
        ("B6112",  "B6", "JFK", "MIA", 180, 0,    "T5-4"),
        ("AS200",  "AS", "SEA", "LAX", 165, 0,    "N6"),
        ("BA178",  "BA", "JFK", "LHR", 425, 0,    "7"),
        ("BA179",  "BA", "LHR", "JFK", 445, 900,  "22"),
        ("LH400",  "LH", "FRA", "JFK", 510, 0,    "A50"),
        ("AF23",   "AF", "CDG", "JFK", 490, 1800, "2E-K44"),
        ("EK201",  "EK", "DXB", "JFK", 830, 0,    "A11"),
        ("UA100",  "UA", "JFK", "ORD", 140, 0,    "C32"),
    ]

    // MARK: - FlightDataProvider

    func searchFlight(number: String, date: Date) async throws -> [FlightSearchResult] {
        try await Task.sleep(nanoseconds: 400_000_000)

        let upper = number.uppercased().replacingOccurrences(of: " ", with: "")
        let matching = flightTemplates.filter { $0.0.hasPrefix(upper) || upper.isEmpty }

        return matching.compactMap { template in
            makeSearchResult(from: template, date: date)
        }
    }

    func fetchFlightStatus(flightNumber: String, date: Date) async throws -> FlightStatusUpdate {
        try await Task.sleep(nanoseconds: 300_000_000)

        guard let template = flightTemplates.first(where: {
            $0.0.uppercased() == flightNumber.uppercased()
        }) else {
            throw FlightDataError.flightNotFound
        }

        let now = Date()
        let departureCal = Calendar.current
        var comps = departureCal.dateComponents([.year, .month, .day], from: date)
        comps.hour = 10; comps.minute = 0
        let scheduledDep = departureCal.date(from: comps) ?? date
        let scheduledArr = scheduledDep.addingTimeInterval(Double(template.4) * 60)
        let delaySeconds = Double(template.5)
        let estimatedDep = delaySeconds > 0 ? scheduledDep.addingTimeInterval(delaySeconds) : nil

        let status = mockStatus(for: scheduledDep, delay: delaySeconds)

        var livePos: AircraftPosition? = nil
        if status == .inFlight || status == .departed {
            let progress = max(0, min(1,
                now.timeIntervalSince(estimatedDep ?? scheduledDep) /
                (scheduledArr.timeIntervalSince(scheduledDep))
            ))
            let origin = Self.airports[template.2]!
            let dest   = Self.airports[template.3]!
            livePos = AircraftPosition(
                latitude:  origin.latitude  + (dest.latitude  - origin.latitude)  * progress,
                longitude: origin.longitude + (dest.longitude - origin.longitude) * progress,
                altitude:  35000,
                speed:     490,
                heading:   bearing(from: origin.coordinate, to: dest.coordinate),
                timestamp: now
            )
        }

        return FlightStatusUpdate(
            flightNumber:      template.0,
            status:            status,
            delayMinutes:      Int(delaySeconds / 60),
            estimatedDeparture: estimatedDep,
            estimatedArrival:  estimatedDep.map { $0.addingTimeInterval(Double(template.4) * 60) },
            actualDeparture:   status.isActive || status.isCompleted ? (estimatedDep ?? scheduledDep).addingTimeInterval(-120) : nil,
            actualArrival:     status.isCompleted ? scheduledArr : nil,
            departureGate:     template.6,
            arrivalGate:       nil,
            departureTerminal: nil,
            arrivalTerminal:   nil,
            baggageClaim:      status.isCompleted ? "Carousel \(Int.random(in: 1...8))" : nil,
            livePosition:      livePos
        )
    }

    func fetchLivePosition(flightNumber: String) async throws -> AircraftPosition? {
        let update = try await fetchFlightStatus(flightNumber: flightNumber, date: Date())
        return update.livePosition
    }

    func fetchAirportBoard(iataCode: String) async throws -> AirportBoard {
        try await Task.sleep(nanoseconds: 500_000_000)

        guard let airport = Self.airports[iataCode.uppercased()] else {
            throw FlightDataError.flightNotFound
        }

        let departures = flightTemplates
            .filter { $0.2 == iataCode.uppercased() }
            .prefix(8)
            .compactMap { makeSearchResult(from: $0, date: Date()) }

        let arrivals = flightTemplates
            .filter { $0.3 == iataCode.uppercased() }
            .prefix(8)
            .compactMap { makeSearchResult(from: $0, date: Date()) }

        return AirportBoard(
            airport: airport,
            departures: Array(departures),
            arrivals: Array(arrivals),
            weather: mockWeather(for: iataCode),
            securityWaitMinutes: Int.random(in: 5...45)
        )
    }

    func fetchWeather(iataCode: String) async throws -> AirportWeather {
        try await Task.sleep(nanoseconds: 200_000_000)
        return mockWeather(for: iataCode) ?? AirportWeather(
            condition: "Clear",
            temperatureCelsius: 22,
            windSpeedKmh: 15,
            windDirection: "NW",
            visibilityKm: 10
        )
    }

    // MARK: - Helpers

    private func makeSearchResult(
        from t: (String, String, String, String, Int, Int, String?),
        date: Date
    ) -> FlightSearchResult? {
        guard let airline  = Self.airlines[t.1],
              let origin   = Self.airports[t.2],
              let dest     = Self.airports[t.3] else { return nil }

        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        let hourSeed = abs(t.0.hash) % 14 + 6
        comps.hour = hourSeed; comps.minute = (abs(t.0.hash) % 4) * 15
        let dep = cal.date(from: comps) ?? date
        let arr = dep.addingTimeInterval(Double(t.4) * 60)
        let delay = Double(t.5)
        let estimatedDep = delay > 0 ? dep.addingTimeInterval(delay) : nil

        return FlightSearchResult(
            id: UUID(),
            flightNumber: t.0,
            airline: airline,
            origin: origin,
            destination: dest,
            scheduledDeparture: dep,
            scheduledArrival: arr,
            status: mockStatus(for: estimatedDep ?? dep, delay: delay),
            aircraft: Aircraft(registration: "N\(Int.random(in: 100...999))AA", type: "Boeing 737-800", iataCode: "738"),
            departureGate: t.6,
            arrivalGate: nil
        )
    }

    private func mockStatus(for scheduledDep: Date, delay: Double) -> FlightStatus {
        let now = Date()
        let dep = scheduledDep.addingTimeInterval(delay)
        let diff = now.timeIntervalSince(dep)

        if delay > 0 && diff < 0 { return .delayed }
        if diff < -3600 { return .scheduled }
        if diff < -600  { return .boarding }
        if diff < 0     { return .boarding }
        if diff < 300   { return .departed }
        if diff < Double(3600 * 6) { return .inFlight }
        return .arrived
    }

    private func mockWeather(for iataCode: String) -> AirportWeather? {
        let data: [String: (String, Double, Double, String, Double)] = [
            "JFK": ("Partly Cloudy", 18, 20, "SW", 10),
            "LAX": ("Sunny", 24, 12, "W", 16),
            "ORD": ("Overcast", 12, 28, "N", 8),
            "ATL": ("Thunderstorms", 22, 18, "SE", 6),
            "SFO": ("Foggy", 16, 14, "NW", 5),
            "LHR": ("Rainy", 10, 22, "SW", 7),
            "CDG": ("Cloudy", 14, 16, "W", 9),
            "DXB": ("Sunny", 38, 8, "NE", 20),
        ]
        guard let d = data[iataCode] else { return nil }
        return AirportWeather(condition: d.0, temperatureCelsius: d.1,
                              windSpeedKmh: d.2, windDirection: d.3, visibilityKm: d.4)
    }

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude  * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}
