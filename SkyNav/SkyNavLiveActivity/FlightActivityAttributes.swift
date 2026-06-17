import ActivityKit
import SwiftUI

// MARK: - Live Activity Attributes

struct FlightActivityAttributes: ActivityAttributes {
    public typealias FlightActivityStatus = ContentState

    // Static (set at launch, does not change)
    let flightNumber: String
    let airlineName: String
    let originIata: String
    let originCity: String
    let destinationIata: String
    let destinationCity: String
    let scheduledDeparture: Date
    let scheduledArrival: Date

    // Dynamic (updated via Activity.update)
    public struct ContentState: Codable, Hashable {
        var status: String
        var delayMinutes: Int
        var estimatedDeparture: Date?
        var estimatedArrival: Date?
        var departureGate: String?
        var progressFraction: Double
        var liveAltitudeFt: Double?
        var liveSpeedKnots: Double?
    }
}

// MARK: - Live Activity Widget

struct FlightLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlightActivityAttributes.self) { context in
            // Lock screen / notification view
            FlightLockScreenActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.originIata)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(context.attributes.originCity)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.attributes.destinationIata)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(context.attributes.destinationCity)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.attributes.flightNumber)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        FlightProgressCapsule(progress: context.state.progressFraction)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if let alt = context.state.liveAltitudeFt {
                            Label("\(Int(alt).formatted()) ft", systemImage: "arrow.up.right")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let spd = context.state.liveSpeedKnots {
                            Label("\(Int(spd * 1.15)) mph", systemImage: "speedometer")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let eta = context.state.estimatedArrival {
                            Text(eta, style: .timer)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: "#4A9EFF"))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            } compactLeading: {
                Image(systemName: "airplane")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#4A9EFF"))
            } compactTrailing: {
                Text(context.attributes.destinationIata)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "airplane")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#4A9EFF"))
            }
        }
        .supplementalActivityFamilies([.small, .medium])
    }
}

// MARK: - Lock Screen View

struct FlightLockScreenActivityView: View {
    let context: ActivityViewContext<FlightActivityAttributes>

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(context.attributes.flightNumber)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(context.state.status)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusColor)
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.originIata)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if let dep = context.state.estimatedDeparture ?? context.state.estimatedDeparture {
                        Text(dep, style: .time)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                FlightProgressCapsule(progress: context.state.progressFraction)
                    .frame(maxWidth: 120)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.attributes.destinationIata)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if let arr = context.state.estimatedArrival {
                        Text(arr, style: .time)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if context.state.delayMinutes > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 11))
                    Text("Delayed \(context.state.delayMinutes)m")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color(hex: "#FFFFFF"))
            }
        }
        .padding(16)
        .background(.black.opacity(0.8))
    }

    var statusColor: Color {
        switch context.state.status {
        case "inFlight", "departed": return Color(hex: "#64D2FF")
        case "delayed":              return Color(hex: "#FFFFFF")
        case "cancelled":            return Color(hex: "#FF453A")
        case "boarding":             return Color(hex: "#4A9EFF")
        case "arrived", "landed":    return Color(hex: "#8E8E93")
        default:                     return .secondary
        }
    }
}

// MARK: - Progress Capsule

struct FlightProgressCapsule: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))
                    .frame(height: 4)
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#4A9EFF"), Color(hex: "#30D158")],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: max(8, geo.size.width * progress), height: 4)
                Image(systemName: "airplane")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "#4A9EFF"))
                    .offset(x: max(0, geo.size.width * progress - 8), y: -9)
            }
            .frame(height: 20)
        }
        .frame(height: 20)
    }
}

// MARK: - Live Activity Manager

final class FlightLiveActivityManager {
    static let shared = FlightLiveActivityManager()
    private var activities: [UUID: Activity<FlightActivityAttributes>] = [:]
    private init() {}

    func start(for flight: Flight) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

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
        let state = FlightActivityAttributes.ContentState(
            status:           flight.status.rawValue,
            delayMinutes:     flight.delayMinutes,
            estimatedDeparture: flight.estimatedDeparture,
            estimatedArrival: flight.estimatedArrival,
            departureGate:    flight.departureGate,
            progressFraction: flight.progressFraction,
            liveAltitudeFt:   flight.liveAltitude,
            liveSpeedKnots:   flight.liveSpeed
        )
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60))
        let activity = try? Activity.request(attributes: attrs, content: content)
        if let activity { activities[flight.id] = activity }
    }

    func update(for flight: Flight) {
        guard let activity = activities[flight.id] else { return }
        let state = FlightActivityAttributes.ContentState(
            status:           flight.status.rawValue,
            delayMinutes:     flight.delayMinutes,
            estimatedDeparture: flight.estimatedDeparture,
            estimatedArrival: flight.estimatedArrival,
            departureGate:    flight.departureGate,
            progressFraction: flight.progressFraction,
            liveAltitudeFt:   flight.liveAltitude,
            liveSpeedKnots:   flight.liveSpeed
        )
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60))
        Task { await activity.update(content) }
    }

    func end(for flightId: UUID) {
        guard let activity = activities[flightId] else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .after(Date().addingTimeInterval(30)))
        }
        activities.removeValue(forKey: flightId)
    }
}

// Required for Color(hex:) in this extension target
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
