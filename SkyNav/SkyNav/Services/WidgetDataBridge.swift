import Foundation

// Writes a compact flight summary to the shared App Group container so the
// widget extension can read it without needing direct SwiftData access.

final class WidgetDataBridge {
    static let shared = WidgetDataBridge()
    private init() {}

    private var containerURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.skynav.shared")
            .map { $0.appendingPathComponent("widget_flights.json") }
    }

    func write(flights: [Flight]) {
        let summaries = flights.map { f in
            WidgetFlightSummary(
                flightNumber:       f.flightNumber,
                airlineName:        f.airlineName,
                originIata:         f.originIata,
                originCity:         f.originCity,
                destinationIata:    f.destinationIata,
                destinationCity:    f.destinationCity,
                scheduledDeparture: f.scheduledDeparture,
                scheduledArrival:   f.scheduledArrival,
                statusRaw:          f.statusRaw,
                delayMinutes:       f.delayMinutes,
                departureGate:      f.departureGate,
                progressFraction:   f.progressFraction
            )
        }
        guard let url = containerURL,
              let data = try? JSONEncoder().encode(summaries) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// Local struct that mirrors WidgetFlightData in the widget target.
// Must stay in sync with WidgetFlightData (same fields, same coding keys).
private struct WidgetFlightSummary: Codable {
    let flightNumber: String
    let airlineName: String
    let originIata: String
    let originCity: String
    let destinationIata: String
    let destinationCity: String
    let scheduledDeparture: Date
    let scheduledArrival: Date
    let statusRaw: String
    let delayMinutes: Int
    let departureGate: String?
    let progressFraction: Double
}
