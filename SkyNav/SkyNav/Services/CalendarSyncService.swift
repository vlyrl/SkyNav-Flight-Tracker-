import Foundation
import EventKit
import UIKit

// MARK: - CalendarSyncService
// Syncs tracked flights to a dedicated "SkyNav Flights" calendar using EventKit.

@MainActor
final class CalendarSyncService {
    static let shared = CalendarSyncService()

    private let store = EKEventStore()
    private let calendarTitle = "SkyNav Flights"
    private var authorized = false

    private init() {}

    // MARK: - Authorization

    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                let granted = try await store.requestWriteOnlyAccessToEvents()
                authorized = granted
                return granted
            } catch {
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                store.requestAccess(to: .event) { granted, _ in
                    Task { @MainActor in
                        self.authorized = granted
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    // MARK: - Sync Flight

    /// Creates or updates a calendar event for the given flight.
    /// Stores the resulting EKEvent identifier back on `flight.calendarEventID`.
    func syncFlight(_ flight: Flight) {
        guard authorized else {
            Task { [weak self] in
                guard let self else { return }
                let ok = await requestAccess()
                if ok { syncFlight(flight) }
            }
            return
        }

        let calendar = skyNavCalendar()

        // Look up existing event or create a new one
        let event: EKEvent
        if let existingId = flight.calendarEventID,
           let existing = store.event(withIdentifier: existingId) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
            event.calendar = calendar
        }

        // Populate fields
        event.title = "✈ \(flight.flightNumber) \(flight.originIata)→\(flight.destinationIata)"
        event.startDate = flight.scheduledDeparture
        event.endDate = flight.scheduledArrival

        var notesParts: [String] = []
        if let gate = flight.departureGate { notesParts.append("Gate: \(gate)") }
        if let terminal = flight.departureTerminal { notesParts.append("Terminal: \(terminal)") }
        if let aircraft = flight.aircraftType { notesParts.append("Aircraft: \(aircraft)") }
        event.notes = notesParts.isEmpty ? nil : notesParts.joined(separator: " • ")

        // 2-hour-before alert
        event.alarms = [EKAlarm(relativeOffset: -2 * 3600)]

        event.timeZone = TimeZone(identifier: flight.originTimezone) ?? .current

        do {
            try store.save(event, span: .thisEvent, commit: true)
            flight.calendarEventID = event.eventIdentifier
        } catch {
            // Silently fail — calendar sync is best-effort
        }
    }

    /// Removes the calendar event associated with the given flight.
    func removeFlight(_ flight: Flight) {
        guard authorized,
              let eventId = flight.calendarEventID,
              let event = store.event(withIdentifier: eventId) else { return }
        try? store.remove(event, span: .thisEvent, commit: true)
        flight.calendarEventID = nil
    }

    // MARK: - Private Helpers

    private func skyNavCalendar() -> EKCalendar {
        // Return the existing SkyNav Flights calendar if present
        if let existing = store.calendars(for: .event).first(where: { $0.title == calendarTitle }) {
            return existing
        }

        // Create a new one
        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = calendarTitle
        cal.cgColor = UIColor(red: 0.0, green: 0.7, blue: 0.7, alpha: 1.0).cgColor // teal

        // Use the default calendar source (iCloud or local)
        if let iCloud = store.sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" }) {
            cal.source = iCloud
        } else if let local = store.sources.first(where: { $0.sourceType == .local }) {
            cal.source = local
        } else if let fallback = store.defaultCalendarForNewEvents?.source {
            cal.source = fallback
        }

        try? store.saveCalendar(cal, commit: true)
        return cal
    }
}
