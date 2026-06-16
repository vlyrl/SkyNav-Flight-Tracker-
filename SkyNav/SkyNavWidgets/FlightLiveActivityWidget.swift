import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity Widget (Dynamic Island + Lock Screen)

struct FlightLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlightActivityAttributes.self) { context in
            FlightLockScreenActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
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
                Text(statusDisplay)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusColor)
            }
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.originIata)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if let dep = context.state.estimatedDeparture {
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
                    Image(systemName: "clock.badge.exclamationmark").font(.system(size: 11))
                    Text("Delayed \(context.state.delayMinutes)m")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color(hex: "#FF9F0A"))
            }
        }
        .padding(16)
        .background(.black.opacity(0.85))
    }

    private var statusDisplay: String {
        switch context.state.status {
        case "inFlight":  return "In Flight"
        case "departed":  return "Departed"
        case "boarding":  return "Boarding"
        case "delayed":   return "Delayed"
        case "cancelled": return "Cancelled"
        case "arrived":   return "Arrived"
        default:          return context.state.status.capitalized
        }
    }

    private var statusColor: Color {
        switch context.state.status {
        case "inFlight", "departed": return Color(hex: "#64D2FF")
        case "delayed":              return Color(hex: "#FF9F0A")
        case "cancelled":            return Color(hex: "#FF453A")
        case "boarding":             return Color(hex: "#30D158")
        default:                     return .secondary
        }
    }
}

// MARK: - Progress Capsule (shared between lock screen and Dynamic Island)

struct FlightProgressCapsule: View {
    let progress: Double
    @State private var animatedProgress: Double = 0

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
                    .frame(width: max(8, geo.size.width * animatedProgress), height: 4)
                Image(systemName: "airplane")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "#4A9EFF"))
                    .offset(x: max(0, geo.size.width * animatedProgress - 8), y: -9)
            }
            .frame(height: 20)
        }
        .frame(height: 20)
        .onAppear { withAnimation(.spring(response: 0.8)) { animatedProgress = progress } }
        .onChange(of: progress) { _, new in
            withAnimation(.spring(response: 0.6)) { animatedProgress = new }
        }
    }
}

// Color(hex:) is defined in SkyNavWidgets.swift — do not redeclare here.
