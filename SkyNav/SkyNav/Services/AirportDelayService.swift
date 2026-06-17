import Foundation

// MARK: - Ground Delay Program Models
// Mirrors the structure of FAA ASDI/NASSTATUS data.

struct GroundDelay: Identifiable {
    let id = UUID()
    let airport: String
    let program: String   // "Ground Stop", "Ground Delay", "Airspace Flow"
    let reason: String    // "Weather", "Volume", "Equipment"
    let avgDelay: Int     // minutes (0 for Ground Stops)
    let scope: String     // "Nationwide", "Regional", "Local"
}

// MARK: - AirportDelayService

enum AirportDelayService {
    // Airports that frequently appear in FAA NASSTATUS programs.
    // Mock data mirrors real seasonal/weather patterns at these hubs.
    private static let delayProne: Set<String> = ["JFK", "EWR", "ORD", "SFO", "LGA", "BOS", "PHL", "ATL"]

    /// Returns active ground delay programs for the given airport.
    /// Returns an empty array when no programs are active.
    static func activePrograms(for iata: String) -> [GroundDelay] {
        guard delayProne.contains(iata.uppercased()) else { return [] }

        // Deterministic mock seeded by airport + current hour so UI stays stable.
        // In production this would call the FAA SWIM / NASSTATUS API.
        let seed = (iata.unicodeScalars.reduce(0) { $0 + Int($1.value) }
                    + Calendar.current.component(.hour, from: Date()))
        let variant = seed % 4

        switch variant {
        case 0:
            return [
                GroundDelay(airport: iata, program: "Ground Delay",
                            reason: "Weather", avgDelay: 45, scope: "Regional")
            ]
        case 1:
            return [
                GroundDelay(airport: iata, program: "Ground Stop",
                            reason: "Weather", avgDelay: 0, scope: "Nationwide")
            ]
        case 2:
            return [
                GroundDelay(airport: iata, program: "Ground Delay",
                            reason: "Volume", avgDelay: 20, scope: "Local"),
                GroundDelay(airport: iata, program: "Airspace Flow",
                            reason: "Weather", avgDelay: 15, scope: "Regional")
            ]
        default:
            // No active programs (variant == 3)
            return []
        }
    }

    /// Returns the most severe single program badge label, or nil if clear.
    static func badgeLabel(for programs: [GroundDelay]) -> String? {
        guard !programs.isEmpty else { return nil }
        if programs.contains(where: { $0.program == "Ground Stop" }) {
            return "GROUND STOP"
        }
        if let worst = programs.max(by: { $0.avgDelay < $1.avgDelay }) {
            return "DELAY \(worst.avgDelay)m"
        }
        return nil
    }
}
