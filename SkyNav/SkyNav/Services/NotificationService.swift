import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        return granted
    }

    func scheduleTimeToLeave(for flight: Flight, minutesBefore: Int = 120) {
        let content = UNMutableNotificationContent()
        content.title = "Time to leave for \(flight.originIata)"
        content.body = "\(flight.flightNumber) departs at \(formatted(flight.effectiveDeparture, timezone: flight.origin.timezone)). Head to the airport now."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let fireDate = flight.effectiveDeparture.addingTimeInterval(-Double(minutesBefore) * 60)
        guard fireDate > Date() else { return }

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "ttl-\(flight.id)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func sendGateChange(for flight: Flight, newGate: String) {
        let content = UNMutableNotificationContent()
        content.title = "Gate Change — \(flight.flightNumber)"
        content.body = "Your gate has changed to \(newGate) at \(flight.originIata)."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        deliver(content, id: "gate-\(flight.id)")
    }

    func sendDelay(for flight: Flight, delayMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Delay — \(flight.flightNumber)"
        let hrs = delayMinutes / 60
        let mins = delayMinutes % 60
        let delayStr = hrs > 0 ? "\(hrs)h \(mins)m" : "\(mins)m"
        content.body = "Departure delayed by \(delayStr). New departure: \(formatted(flight.effectiveDeparture, timezone: flight.origin.timezone))."
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive
        deliver(content, id: "delay-\(flight.id)-\(delayMinutes)")
    }

    func sendCancellation(for flight: Flight) {
        let content = UNMutableNotificationContent()
        content.title = "Cancelled — \(flight.flightNumber)"
        content.body = "\(flight.originIata) → \(flight.destinationIata) has been cancelled."
        content.sound = .defaultCritical
        content.interruptionLevel = .critical
        deliver(content, id: "cancel-\(flight.id)")
    }

    func sendBoarding(for flight: Flight) {
        let content = UNMutableNotificationContent()
        content.title = "Now Boarding — \(flight.flightNumber)"
        let gate = flight.departureGate.map { "Gate \($0)" } ?? ""
        content.body = "\(flight.originIata) → \(flight.destinationIata). \(gate)".trimmingCharacters(in: .whitespaces)
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        deliver(content, id: "board-\(flight.id)")
    }

    func sendLanded(for flight: Flight) {
        let content = UNMutableNotificationContent()
        content.title = "Landed — \(flight.flightNumber)"
        let baggage = flight.baggageClaim.map { " Baggage: \($0)." } ?? ""
        content.body = "Welcome to \(flight.destinationCity)!\(baggage)"
        content.sound = .default
        content.interruptionLevel = .passive
        deliver(content, id: "land-\(flight.id)")
    }

    func cancelAll(for flightId: UUID) {
        let prefixes = ["ttl", "gate", "delay", "cancel", "board", "land"]
        let ids = prefixes.map { "\($0)-\(flightId)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    // MARK: - Private

    private func deliver(_ content: UNMutableNotificationContent, id: String) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func formatted(_ date: Date, timezone: TimeZone) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        f.timeZone = timezone
        return f.string(from: date)
    }
}
