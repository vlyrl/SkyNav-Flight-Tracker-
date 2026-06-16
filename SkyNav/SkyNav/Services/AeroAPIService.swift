import Foundation
import CoreLocation

// MARK: - FlightAware AeroAPI v4 Service
// API key is loaded at init from Config.plist (gitignored).
// Key is never stored in Swift source — only in the bundle plist.

final class AeroAPIService: FlightDataProvider {

    private let apiKey: String
    private let baseURL = URL(string: "https://aeroapi.flightaware.com/aeroapi")!
    private let session = URLSession.shared

    private let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static var isConfigured: Bool {
        guard
            let plistURL = Bundle.main.url(forResource: "Config", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: plistURL),
            let key = dict["FlightAwareAPIKey"] as? String,
            !key.isEmpty,
            key != "YOUR_FLIGHTAWARE_AEROAPI_KEY_HERE"
        else { return false }
        return true
    }

    init() throws {
        guard
            let plistURL = Bundle.main.url(forResource: "Config", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: plistURL),
            let key = dict["FlightAwareAPIKey"] as? String,
            !key.isEmpty,
            key != "YOUR_FLIGHTAWARE_AEROAPI_KEY_HERE"
        else {
            throw FlightDataError.apiKeyMissing
        }
        self.apiKey = key
    }

    // MARK: - FlightDataProvider

    func searchFlight(number: String, date: Date) async throws -> [FlightSearchResult] {
        let ident = normalize(number)
        let (start, end) = dayWindow(for: date)
        let response: AeroFlightsResponse = try await get(
            "/flights/\(ident)",
            params: ["start": fmt(start), "end": fmt(end), "max_pages": "1"]
        )
        return response.flights.compactMap { toSearchResult($0) }
    }

    func fetchFlightStatus(flightNumber: String, date: Date) async throws -> FlightStatusUpdate {
        let ident = normalize(flightNumber)
        let (start, end) = dayWindow(for: date)
        let response: AeroFlightsResponse = try await get(
            "/flights/\(ident)",
            params: ["start": fmt(start), "end": fmt(end), "max_pages": "1"]
        )
        guard let flight = response.flights.first(where: {
            let iata = $0.identIata?.uppercased() ?? ""
            let icao = $0.identIcao?.uppercased() ?? ""
            let raw  = $0.ident?.uppercased() ?? ""
            return iata == ident || icao == ident || raw == ident
        }) ?? response.flights.first else {
            throw FlightDataError.flightNotFound
        }
        return toStatusUpdate(flight)
    }

    func fetchLivePosition(flightNumber: String) async throws -> AircraftPosition? {
        let update = try await fetchFlightStatus(flightNumber: flightNumber, date: Date())
        return update.livePosition
    }

    func fetchAirportBoard(iataCode: String) async throws -> AirportBoard {
        let code = iataCode.uppercased()
        let now  = Date()
        let params: [String: String] = [
            "start": fmt(now.addingTimeInterval(-3600)),
            "end":   fmt(now.addingTimeInterval(5 * 3600)),
            "max_pages": "1"
        ]
        async let depFetch: AeroDeparturesResponse = get("/airports/\(code)/flights/departures", params: params)
        async let arrFetch: AeroArrivalsResponse   = get("/airports/\(code)/flights/arrivals",   params: params)

        let (deps, arrs) = try await (depFetch, arrFetch)

        let airport = Self.knownAirports[code] ?? Airport(
            iataCode: code, icaoCode: code, name: code,
            city: "", country: "",
            latitude: 0, longitude: 0,
            timezoneIdentifier: TimeZone.current.identifier
        )

        return AirportBoard(
            airport: airport,
            departures: deps.departures.compactMap { toSearchResult($0) },
            arrivals:   arrs.arrivals.compactMap   { toSearchResult($0) },
            weather: nil,
            securityWaitMinutes: nil
        )
    }

    func fetchWeather(iataCode: String) async throws -> AirportWeather {
        let response: AeroWeatherResponse = try await get(
            "/airports/\(iataCode.uppercased())/weather/observations",
            params: [:]
        )
        guard let cond = response.conditions?.first else {
            throw FlightDataError.invalidResponse
        }
        return AirportWeather(
            condition:          cond.conditions ?? cond.cloudCondition ?? cond.flightCategory ?? "Unknown",
            temperatureCelsius: cond.tempAir ?? 20,
            windSpeedKmh:       Double(cond.windSpeed ?? 0) * 1.852,
            windDirection:      compassPoint(cond.windDirection ?? 0),
            visibilityKm:       (cond.visibility ?? 10) * 1.60934
        )
    }

    // MARK: - Networking

    private func get<T: Decodable>(_ path: String, params: [String: String]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path),
                                       resolvingAgainstBaseURL: false)!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw FlightDataError.invalidResponse }

        var req = URLRequest(url: url)
        req.setValue(apiKey, forHTTPHeaderField: "x-apikey")
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw FlightDataError.networkUnavailable
        }

        guard let http = resp as? HTTPURLResponse else { throw FlightDataError.invalidResponse }

        switch http.statusCode {
        case 200...299: break
        case 401, 403:  throw FlightDataError.apiKeyMissing
        case 404:       throw FlightDataError.flightNotFound
        case 429:       throw FlightDataError.rateLimited
        default:        throw FlightDataError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw FlightDataError.invalidResponse
        }
    }

    // MARK: - AeroFlight → Domain model mapping

    private func toSearchResult(_ f: AeroFlight) -> FlightSearchResult? {
        guard
            let ident  = f.identIata ?? f.ident,
            let depStr = f.scheduledOut,
            let arrStr = f.scheduledIn,
            let dep    = parseDate(depStr),
            let arr    = parseDate(arrStr)
        else { return nil }

        let airline = makeAirline(f, ident: ident)
        let origin  = makeAirport(f.origin)
        let dest    = makeAirport(f.destination)

        return FlightSearchResult(
            id: UUID(),
            flightNumber: ident,
            airline: airline,
            origin: origin,
            destination: dest,
            scheduledDeparture: dep,
            scheduledArrival: arr,
            status: mapStatus(f),
            aircraft: f.aircraftType.map {
                Aircraft(registration: f.registration ?? "", type: aircraftName($0), iataCode: $0)
            },
            departureGate: f.gateOrigin,
            arrivalGate: f.gateDestination
        )
    }

    private func toStatusUpdate(_ f: AeroFlight) -> FlightStatusUpdate {
        let delaySeconds = f.departureDelay ?? 0
        let estimatedDep: Date?
        if let s = f.estimatedOut { estimatedDep = parseDate(s) }
        else if delaySeconds > 0, let base = f.scheduledOut.flatMap({ parseDate($0) }) {
            estimatedDep = base.addingTimeInterval(Double(delaySeconds))
        } else { estimatedDep = nil }

        let position: AircraftPosition? = f.lastPosition.flatMap { pos in
            guard let lat = pos.latitude, let lon = pos.longitude else { return nil }
            return AircraftPosition(
                latitude:  lat,
                longitude: lon,
                altitude:  Double((pos.altitude ?? 0) * 100),
                speed:     Double(pos.groundspeed ?? 0),
                heading:   Double(pos.heading ?? 0),
                timestamp: pos.timestamp.flatMap { parseDate($0) } ?? Date()
            )
        }

        return FlightStatusUpdate(
            flightNumber:       f.identIata ?? f.ident ?? f.flightNumber ?? "?",
            status:             mapStatus(f),
            delayMinutes:       max(0, delaySeconds / 60),
            estimatedDeparture: estimatedDep,
            estimatedArrival:   f.estimatedIn.flatMap { parseDate($0) },
            actualDeparture:    f.actualOut.flatMap { parseDate($0) },
            actualArrival:      f.actualIn.flatMap { parseDate($0) },
            departureGate:      f.gateOrigin,
            arrivalGate:        f.gateDestination,
            departureTerminal:  f.terminalOrigin,
            arrivalTerminal:    f.terminalDestination,
            baggageClaim:       f.baggageClaim,
            livePosition:       position
        )
    }

    private func mapStatus(_ f: AeroFlight) -> FlightStatus {
        if f.cancelled == true { return .cancelled }
        if f.diverted  == true { return .diverted  }

        let s = (f.status ?? "").lowercased()
        if s.contains("en route") || s.contains("in flight") { return .inFlight }
        if s.contains("landed")   { return .landed   }
        if s.contains("arrived")  { return .arrived  }
        if s.contains("cancelled") { return .cancelled }
        if s.contains("diverted") { return .diverted }
        if s.contains("boarding") { return .boarding }
        if s.contains("departed") || s.contains("taxiing") { return .departed }
        if s.contains("delay")    { return .delayed  }
        if s.contains("scheduled") { return .scheduled }

        if f.actualIn  != nil { return .arrived   }
        if f.actualOut != nil { return .inFlight  }
        if (f.departureDelay ?? 0) > 0 { return .delayed }
        return .scheduled
    }

    private func makeAirline(_ f: AeroFlight, ident: String) -> Airline {
        let iata = f.operatorIata ?? String(ident.prefix(2))
        return Airline(
            iataCode: iata,
            icaoCode: f.operatorIcao ?? iata,
            name:     f.operatorName ?? iata,
            callsign: nil
        )
    }

    private func makeAirport(_ a: AeroAirport?) -> Airport {
        let iata = a?.codeIata ?? a?.code ?? "???"
        if let known = Self.knownAirports[iata] { return known }
        return Airport(
            iataCode: iata,
            icaoCode: a?.code ?? iata,
            name:     a?.name ?? iata,
            city:     a?.city ?? "",
            country:  a?.country ?? "",
            latitude: 0,
            longitude: 0,
            timezoneIdentifier: a?.timezone ?? TimeZone.current.identifier
        )
    }

    // MARK: - Date helpers

    private func parseDate(_ s: String) -> Date? {
        isoFull.date(from: s) ?? isoBasic.date(from: s)
    }

    private func fmt(_ date: Date) -> String {
        isoBasic.string(from: date)
    }

    private func dayWindow(for date: Date) -> (Date, Date) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let dayStart = cal.startOfDay(for: date)
        return (dayStart.addingTimeInterval(-6 * 3600), dayStart.addingTimeInterval(30 * 3600))
    }

    private func normalize(_ raw: String) -> String {
        raw.uppercased().replacingOccurrences(of: " ", with: "")
    }

    private func compassPoint(_ degrees: Int) -> String {
        let dirs = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
        return dirs[Int((Double(degrees) / 22.5).rounded()) % 16]
    }

    private func aircraftName(_ icao: String) -> String {
        let table: [String: String] = [
            "B737":"Boeing 737-700","B738":"Boeing 737-800","B739":"Boeing 737-900",
            "B744":"Boeing 747-400","B748":"Boeing 747-8",
            "B752":"Boeing 757-200","B753":"Boeing 757-300",
            "B762":"Boeing 767-200","B763":"Boeing 767-300","B764":"Boeing 767-400",
            "B772":"Boeing 777-200","B77W":"Boeing 777-300ER",
            "B788":"Boeing 787-8","B789":"Boeing 787-9","B78X":"Boeing 787-10",
            "A319":"Airbus A319","A320":"Airbus A320","A321":"Airbus A321",
            "A332":"Airbus A330-200","A333":"Airbus A330-300",
            "A343":"Airbus A340-300","A346":"Airbus A340-600",
            "A359":"Airbus A350-900","A35K":"Airbus A350-1000","A388":"Airbus A380-800",
            "E170":"Embraer E170","E175":"Embraer E175","E190":"Embraer E190","E195":"Embraer E195",
            "CRJ2":"CRJ-200","CRJ7":"CRJ-700","CRJ9":"CRJ-900",
            "DH8D":"Dash 8 Q400","AT76":"ATR 72-600",
        ]
        return table[icao] ?? icao
    }

    // MARK: - Static airport reference data
    // Provides accurate lat/lon and timezone for ~55 major airports.
    // AeroAPI returns airport codes and timezone strings but not coordinates.

    static let knownAirports: [String: Airport] = {
        let rows: [(String, String, String, String, String, Double, Double, String)] = [
            // IATA, ICAO, Name, City, Country, lat, lon, tz
            ("ATL","KATL","Hartsfield-Jackson Atlanta Intl","Atlanta","United States",33.6407,-84.4277,"America/New_York"),
            ("LAX","KLAX","Los Angeles International","Los Angeles","United States",33.9425,-118.4081,"America/Los_Angeles"),
            ("ORD","KORD","O'Hare International","Chicago","United States",41.9742,-87.9073,"America/Chicago"),
            ("DFW","KDFW","Dallas/Fort Worth International","Dallas","United States",32.8998,-97.0403,"America/Chicago"),
            ("DEN","KDEN","Denver International","Denver","United States",39.8561,-104.6737,"America/Denver"),
            ("JFK","KJFK","John F. Kennedy International","New York","United States",40.6413,-73.7781,"America/New_York"),
            ("SFO","KSFO","San Francisco International","San Francisco","United States",37.6213,-122.3790,"America/Los_Angeles"),
            ("SEA","KSEA","Seattle-Tacoma International","Seattle","United States",47.4502,-122.3088,"America/Los_Angeles"),
            ("LAS","KLAS","Harry Reid International","Las Vegas","United States",36.0840,-115.1537,"America/Los_Angeles"),
            ("MCO","KMCO","Orlando International","Orlando","United States",28.4312,-81.3081,"America/New_York"),
            ("MIA","KMIA","Miami International","Miami","United States",25.7959,-80.2870,"America/New_York"),
            ("CLT","KCLT","Charlotte Douglas International","Charlotte","United States",35.2140,-80.9431,"America/New_York"),
            ("EWR","KEWR","Newark Liberty International","Newark","United States",40.6895,-74.1745,"America/New_York"),
            ("PHX","KPHX","Phoenix Sky Harbor International","Phoenix","United States",33.4373,-112.0078,"America/Phoenix"),
            ("IAH","KIAH","George Bush Intercontinental","Houston","United States",29.9902,-95.3368,"America/Chicago"),
            ("BOS","KBOS","Logan International","Boston","United States",42.3656,-71.0096,"America/New_York"),
            ("MSP","KMSP","Minneapolis-Saint Paul International","Minneapolis","United States",44.8848,-93.2223,"America/Chicago"),
            ("DTW","KDTW","Detroit Metropolitan Wayne County","Detroit","United States",42.2162,-83.3554,"America/Detroit"),
            ("SLC","KSLC","Salt Lake City International","Salt Lake City","United States",40.7884,-111.9778,"America/Denver"),
            ("PHL","KPHL","Philadelphia International","Philadelphia","United States",39.8719,-75.2411,"America/New_York"),
            ("LGA","KLGA","LaGuardia Airport","New York","United States",40.7772,-73.8726,"America/New_York"),
            ("BWI","KBWI","Baltimore/Washington International","Baltimore","United States",39.1754,-76.6682,"America/New_York"),
            ("IAD","KIAD","Dulles International","Washington DC","United States",38.9531,-77.4565,"America/New_York"),
            ("DCA","KDCA","Reagan National Airport","Washington DC","United States",38.8521,-77.0377,"America/New_York"),
            ("MDW","KMDW","Chicago Midway International","Chicago","United States",41.7868,-87.7522,"America/Chicago"),
            ("SAN","KSAN","San Diego International","San Diego","United States",32.7336,-117.1897,"America/Los_Angeles"),
            ("TPA","KTPA","Tampa International","Tampa","United States",27.9755,-82.5332,"America/New_York"),
            ("PDX","KPDX","Portland International","Portland","United States",45.5898,-122.5951,"America/Los_Angeles"),
            ("HNL","PHNL","Daniel K. Inouye International","Honolulu","United States",21.3245,-157.9251,"Pacific/Honolulu"),
            ("ANC","PANC","Ted Stevens Anchorage International","Anchorage","United States",61.1743,-149.9963,"America/Anchorage"),
            ("LHR","EGLL","London Heathrow","London","United Kingdom",51.4700,-0.4543,"Europe/London"),
            ("LGW","EGKK","London Gatwick","London","United Kingdom",51.1537,-0.1821,"Europe/London"),
            ("CDG","LFPG","Charles de Gaulle","Paris","France",49.0097,2.5479,"Europe/Paris"),
            ("FRA","EDDF","Frankfurt Airport","Frankfurt","Germany",50.0379,8.5622,"Europe/Berlin"),
            ("AMS","EHAM","Amsterdam Schiphol","Amsterdam","Netherlands",52.3086,4.7639,"Europe/Amsterdam"),
            ("MAD","LEMD","Adolfo Suárez Madrid-Barajas","Madrid","Spain",40.4936,-3.5668,"Europe/Madrid"),
            ("BCN","LEBL","Barcelona El Prat","Barcelona","Spain",41.2974,2.0833,"Europe/Madrid"),
            ("FCO","LIRF","Leonardo da Vinci International","Rome","Italy",41.8003,12.2389,"Europe/Rome"),
            ("MUC","EDDM","Munich Airport","Munich","Germany",48.3538,11.7861,"Europe/Berlin"),
            ("ZRH","LSZH","Zurich Airport","Zurich","Switzerland",47.4647,8.5492,"Europe/Zurich"),
            ("DXB","OMDB","Dubai International","Dubai","United Arab Emirates",25.2528,55.3644,"Asia/Dubai"),
            ("DOH","OTHH","Hamad International","Doha","Qatar",25.2609,51.6138,"Asia/Qatar"),
            ("SIN","WSSS","Singapore Changi","Singapore","Singapore",1.3644,103.9915,"Asia/Singapore"),
            ("HKG","VHHH","Hong Kong International","Hong Kong","China",22.3080,113.9185,"Asia/Hong_Kong"),
            ("NRT","RJAA","Narita International","Tokyo","Japan",35.7647,140.3864,"Asia/Tokyo"),
            ("HND","RJTT","Tokyo Haneda","Tokyo","Japan",35.5494,139.7798,"Asia/Tokyo"),
            ("ICN","RKSI","Incheon International","Seoul","South Korea",37.4602,126.4407,"Asia/Seoul"),
            ("PEK","ZBAA","Beijing Capital International","Beijing","China",40.0799,116.6031,"Asia/Shanghai"),
            ("PVG","ZSPD","Shanghai Pudong International","Shanghai","China",31.1434,121.8052,"Asia/Shanghai"),
            ("SYD","YSSY","Sydney Kingsford Smith","Sydney","Australia",-33.9461,151.1772,"Australia/Sydney"),
            ("MEL","YMML","Melbourne Airport","Melbourne","Australia",-37.6690,144.8410,"Australia/Melbourne"),
            ("YYZ","CYYZ","Toronto Pearson International","Toronto","Canada",43.6777,-79.6248,"America/Toronto"),
            ("YVR","CYVR","Vancouver International","Vancouver","Canada",49.1947,-123.1799,"America/Vancouver"),
            ("GRU","SBGR","São Paulo Guarulhos International","São Paulo","Brazil",-23.4356,-46.4731,"America/Sao_Paulo"),
            ("MEX","MMMX","Benito Juárez International","Mexico City","Mexico",19.4363,-99.0721,"America/Mexico_City"),
        ]
        var d: [String: Airport] = [:]
        for r in rows {
            d[r.0] = Airport(iataCode: r.0, icaoCode: r.1, name: r.2, city: r.3,
                             country: r.4, latitude: r.5, longitude: r.6,
                             timezoneIdentifier: r.7)
        }
        return d
    }()
}
