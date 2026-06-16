import SwiftUI
import Foundation

struct TimeDisplay: View {
    let date: Date
    let timezone: TimeZone
    let label: String
    var showDelay: Bool = false
    var delayMinutes: Int = 0

    private var isDelayed: Bool {
        showDelay && delayMinutes > 0
    }

    private var scheduledDate: Date {
        guard isDelayed else { return date }
        return date.addingTimeInterval(-Double(delayMinutes) * 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.skyNavCaption)
                .foregroundStyle(SkyNavColor.textTertiary)
                .tracking(0.8)

            if isDelayed {
                Text(formattedTime(scheduledDate))
                    .font(.skyNavTime)
                    .foregroundStyle(SkyNavColor.statusCancelled)
                    .strikethrough(true, color: SkyNavColor.statusCancelled)

                Text(formattedTime(date))
                    .font(.skyNavTime)
                    .foregroundStyle(SkyNavColor.statusDelayed)
            } else {
                Text(formattedTime(date))
                    .font(.skyNavTime)
                    .foregroundStyle(SkyNavColor.textPrimary)
            }

            Text(timezoneAbbreviation)
                .font(.skyNavCaption)
                .foregroundStyle(SkyNavColor.textSecondary)
        }
    }

    private func formattedTime(_ d: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.timeZone = timezone
        return formatter.string(from: d)
    }

    private var timezoneAbbreviation: String {
        timezone.abbreviation(for: date) ?? timezone.identifier
    }
}

#Preview {
    HStack(spacing: 32) {
        TimeDisplay(
            date: Date(),
            timezone: .current,
            label: "Departure",
            showDelay: false,
            delayMinutes: 0
        )
        TimeDisplay(
            date: Date().addingTimeInterval(3600),
            timezone: TimeZone(identifier: "America/New_York") ?? .current,
            label: "Arrival",
            showDelay: true,
            delayMinutes: 45
        )
    }
    .padding()
    .background(SkyNavColor.background)
}
