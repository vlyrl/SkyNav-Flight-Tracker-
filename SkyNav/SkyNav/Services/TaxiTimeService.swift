import Foundation

// MARK: - TaxiTimeService
// Provides estimated taxi-out and taxi-in times (in minutes) for major airports.
// Source: FAA published average taxi times (approximated).

enum TaxiTimeService {
    struct TaxiTimes {
        let out: Int   // minutes from gate push-back to wheels-up
        let inbound: Int  // minutes from wheels-down to gate arrival
    }

    static let taxiTimes: [String: (out: Int, inbound: Int)] = [
        "JFK": (out: 22, inbound: 12), "LAX": (out: 18, inbound: 10), "ORD": (out: 20, inbound: 11),
        "ATL": (out: 16, inbound: 9),  "DFW": (out: 19, inbound: 10), "DEN": (out: 14, inbound: 8),
        "SFO": (out: 17, inbound: 9),  "SEA": (out: 15, inbound: 8),  "MIA": (out: 13, inbound: 7),
        "BOS": (out: 18, inbound: 10), "EWR": (out: 21, inbound: 12), "LGA": (out: 20, inbound: 11),
        "IAD": (out: 15, inbound: 8),  "IAH": (out: 17, inbound: 9),  "PHX": (out: 13, inbound: 7),
        "MSP": (out: 14, inbound: 8),  "DTW": (out: 15, inbound: 8),  "PHL": (out: 19, inbound: 10),
        "CLT": (out: 14, inbound: 8),  "LHR": (out: 25, inbound: 15), "CDG": (out: 22, inbound: 13),
        "FRA": (out: 20, inbound: 11), "AMS": (out: 18, inbound: 10), "DXB": (out: 16, inbound: 9),
        "NRT": (out: 18, inbound: 10), "HND": (out: 15, inbound: 8),  "SIN": (out: 14, inbound: 8),
        "HKG": (out: 16, inbound: 9),  "SYD": (out: 15, inbound: 8),  "YYZ": (out: 17, inbound: 9),
    ]

    /// Returns taxi times for the given IATA code, or defaults (12 out / 7 in) if unknown.
    static func times(for iata: String) -> (out: Int, inbound: Int) {
        taxiTimes[iata.uppercased()] ?? (out: 12, inbound: 7)
    }
}
