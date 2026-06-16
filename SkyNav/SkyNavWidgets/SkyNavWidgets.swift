import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared App Group Data Bridge
// The main app writes flight summaries to a shared App Group container.
// The widget reads from there — no direct SwiftData access from extension.

struct WidgetFlightData: Codable {
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

    var status: String { statusRaw }

    static func load() -> [WidgetFlightData] {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.skynav.shared"),
              let data = try? Data(contentsOf: container.appendingPathComponent("widget_flights.json")),
              let decoded = try? JSONDecoder().decode([WidgetFlightData].self, from: data)
        else { return [] }
        return decoded
    }

    static func nextFlight(from flights: [WidgetFlightData]) -> WidgetFlightData? {
        let now = Date()
        return flights
            .filter { $0.scheduledDeparture > now || ["boarding", "departed", "inFlight"].contains($0.statusRaw) }
            .sorted { $0.scheduledDeparture < $1.scheduledDeparture }
            .first
    }
}

// MARK: - Timeline Provider

struct FlightWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlightWidgetEntry {
        FlightWidgetEntry(date: Date(), flight: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (FlightWidgetEntry) -> Void) {
        let flights = WidgetFlightData.load()
        let entry = FlightWidgetEntry(date: Date(), flight: WidgetFlightData.nextFlight(from: flights) ?? .placeholder)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FlightWidgetEntry>) -> Void) {
        let flights = WidgetFlightData.load()
        let flight  = WidgetFlightData.nextFlight(from: flights)
        let entry   = FlightWidgetEntry(date: Date(), flight: flight ?? .placeholder)
        let refresh = Date().addingTimeInterval(flight?.scheduledDeparture.timeIntervalSinceNow ?? 3600 > 7200 ? 1800 : 60)
        let timeline = Timeline(entries: [entry], policy: .after(refresh))
        completion(timeline)
    }
}

struct FlightWidgetEntry: TimelineEntry {
    let date: Date
    let flight: WidgetFlightData
}

extension WidgetFlightData {
    static let placeholder = WidgetFlightData(
        flightNumber: "AA100", airlineName: "American Airlines",
        originIata: "JFK", originCity: "New York",
        destinationIata: "LAX", destinationCity: "Los Angeles",
        scheduledDeparture: Date().addingTimeInterval(3600 * 2),
        scheduledArrival:   Date().addingTimeInterval(3600 * 7),
        statusRaw: "scheduled", delayMinutes: 0, departureGate: "B22",
        progressFraction: 0
    )

    var statusColor: Color {
        switch statusRaw {
        case "delayed":           return Color(hex: "#FF9F0A")
        case "boarding":          return Color(hex: "#30D158")
        case "inFlight","departed": return Color(hex: "#64D2FF")
        case "cancelled":         return Color(hex: "#FF453A")
        case "arrived","landed":  return Color(hex: "#8E8E93")
        default:                  return Color(hex: "#8E8E93")
        }
    }

    var statusDisplay: String {
        switch statusRaw {
        case "scheduled": return "Scheduled"
        case "delayed":   return "Delayed \(delayMinutes)m"
        case "boarding":  return "Boarding"
        case "departed":  return "Departed"
        case "inFlight":  return "In Flight"
        case "landed":    return "Landed"
        case "arrived":   return "Arrived"
        case "cancelled": return "Cancelled"
        default:          return statusRaw.capitalized
        }
    }
}

// MARK: - Small Widget View

struct SmallFlightWidgetView: View {
    let entry: FlightWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "airplane")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "#4A9EFF"))
                Text(entry.flight.flightNumber)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.flight.originIata)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(entry.flight.scheduledDeparture, style: .time)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.flight.destinationIata)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(entry.flight.scheduledArrival, style: .time)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(entry.flight.statusDisplay)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(entry.flight.statusColor)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(entry.flight.statusColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(hex: "#12121A"))
        .containerBackground(Color(hex: "#12121A"), for: .widget)
    }
}

// MARK: - Medium Widget View

struct MediumFlightWidgetView: View {
    let entry: FlightWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "#4A9EFF"))
                    Text(entry.flight.flightNumber)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(entry.flight.airlineName)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.flight.originIata)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(entry.flight.originCity)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(entry.flight.scheduledDeparture, style: .time)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Image(systemName: "airplane")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "#4A9EFF"))
                        Rectangle()
                            .fill(Color(hex: "#252535"))
                            .frame(height: 1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(entry.flight.destinationIata)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(entry.flight.destinationCity)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(entry.flight.scheduledArrival, style: .time)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
                Spacer()
                HStack {
                    Text(entry.flight.statusDisplay)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(entry.flight.statusColor)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(entry.flight.statusColor.opacity(0.15))
                        .clipShape(Capsule())
                    Spacer()
                    if let gate = entry.flight.departureGate {
                        Text("Gate \(gate)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#12121A"))
        .containerBackground(Color(hex: "#12121A"), for: .widget)
    }
}

// MARK: - Widget Bundle

struct SkyNavFlightWidget: Widget {
    let kind = "SkyNavFlightWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlightWidgetProvider()) { entry in
            Group {
                SmallFlightWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Next Flight")
        .description("See your next upcoming flight at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct SkyNavWidgetBundle: WidgetBundle {
    var body: some Widget {
        SkyNavFlightWidget()
        FlightLiveActivityWidget()
    }
}

// Color(hex:) needed in widget extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
