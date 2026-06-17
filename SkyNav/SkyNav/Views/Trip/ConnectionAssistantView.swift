import SwiftUI

// MARK: - Connection Risk

enum ConnectionRisk {
    case comfortable   // connection time > MCT + 30 min
    case tight         // connection time between MCT and MCT + 30 min
    case atRisk        // connection time < MCT, or first flight delayed enough to miss

    var label: String {
        switch self {
        case .comfortable: return "COMFORTABLE"
        case .tight:       return "TIGHT"
        case .atRisk:      return "AT RISK"
        }
    }

    var color: Color {
        switch self {
        case .comfortable: return SkyNavColor.statusOnTime
        case .tight:       return Color(hex: "#FF9F0A")   // amber
        case .atRisk:      return SkyNavColor.statusCancelled
        }
    }

    var icon: String {
        switch self {
        case .comfortable: return "checkmark.circle.fill"
        case .tight:       return "clock.badge.exclamationmark"
        case .atRisk:      return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - ConnectionAssistantView
// Shows connection time and risk for a layover between two consecutive flights.

struct ConnectionAssistantView: View {
    let arriving: Flight    // first leg, arriving at layover airport
    let departing: Flight   // second leg, departing from layover airport

    // MARK: Computed

    private var layoverAirport: String { arriving.destinationIata }

    /// Effective arrival of first leg (accounting for delay).
    private var effectiveArrival: Date { arriving.effectiveArrival }

    /// Effective departure of second leg.
    private var effectiveDeparture: Date { departing.effectiveDeparture }

    /// Connection time in minutes.
    private var connectionMinutes: Int {
        Int(effectiveDeparture.timeIntervalSince(effectiveArrival) / 60)
    }

    /// Minimum connection time (MCT) for the layover airport.
    private var mct: Int { minimumConnectionTime(at: layoverAirport) }

    private var risk: ConnectionRisk {
        if connectionMinutes < mct { return .atRisk }
        if connectionMinutes < mct + 30 { return .tight }
        return .comfortable
    }

    private var connectionString: String {
        let total = max(0, connectionMinutes)
        let h = total / 60
        let m = total % 60
        if h > 0 { return "\(h)h \(m)m at \(layoverAirport)" }
        return "\(m)m at \(layoverAirport)"
    }

    /// Mock gate-walk tip shown when connection is tight or at risk.
    private var gateTip: String? {
        guard risk != .comfortable else { return nil }
        // Mock: derive a plausible gate number from flight number hash
        let gateNumber = (departing.flightNumber.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 30) + 1
        let terminal = ["A", "B", "C", "D"][abs(departing.flightNumber.hashValue) % 4]
        let walkMin = gateNumber % 10 + 3
        return "Head straight to Gate \(terminal)\(gateNumber) — ~\(walkMin) min walk"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.merge")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SkyNavColor.textTertiary)

                Text("Connection")
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textTertiary)
                    .tracking(0.5)

                Spacer()

                // Risk badge
                HStack(spacing: 5) {
                    Image(systemName: risk.icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(risk.label)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundStyle(risk.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(risk.color.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(risk.color.opacity(0.3), lineWidth: 1))
            }

            // Connection time
            Text(connectionString)
                .font(.skyNavHeadline)
                .foregroundStyle(SkyNavColor.textPrimary)

            // MCT note
            Text("Minimum connection: \(mct)m")
                .font(.skyNavCaption)
                .foregroundStyle(SkyNavColor.textSecondary)

            // Gate tip
            if let tip = gateTip {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 12))
                        .foregroundStyle(risk.color)
                    Text(tip)
                        .font(.skyNavCaption)
                        .foregroundStyle(risk.color)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(risk.color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(risk.color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Minimum Connection Times

    private func minimumConnectionTime(at airport: String) -> Int {
        let mcts: [String: Int] = [
            "JFK": 60, "LHR": 90, "CDG": 75, "FRA": 60, "AMS": 50,
            "ORD": 45, "ATL": 40, "LAX": 50, "DFW": 45, "DXB": 60,
            "NRT": 60, "HKG": 60, "SIN": 60, "SYD": 45, "YYZ": 60,
            "MIA": 45, "BOS": 45, "EWR": 60, "LGA": 60, "IAD": 45,
        ]
        return mcts[airport.uppercased()] ?? 45
    }
}
