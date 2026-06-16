import SwiftUI

// MARK: - Flight Status Row

/// A single labelled metadata row used inside the Flight Info section.
/// Displays an SF Symbol icon and a label on the left, a value on the right.
/// Set `highlight` to true to render the value in the accent colour (e.g. for gate changes).
struct FlightStatusRow: View {
    let label: String
    let value: String
    let icon: String
    var highlight: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(highlight ? SkyNavColor.accent : SkyNavColor.textSecondary)
                .frame(width: 20, alignment: .center)

            // Label
            Text(label)
                .font(.skyNavBody)
                .foregroundStyle(SkyNavColor.textSecondary)

            Spacer()

            // Value
            Text(value)
                .font(.skyNavBody)
                .foregroundStyle(highlight ? SkyNavColor.accent : SkyNavColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())  // make the full row hittable for future tap handlers
    }
}

// MARK: - Divider-separated list helper

/// Wraps a sequence of `FlightStatusRow` items with hairline dividers between them,
/// all inside a single `.skyNavCard()` surface.
struct FlightStatusRowGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 16)
        .skyNavCard()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        FlightStatusRow(label: "Departure Gate",  value: "B22",       icon: "door.right.hand.open",    highlight: true)
        Divider().background(SkyNavColor.surfaceBorder)
        FlightStatusRow(label: "Terminal",        value: "Terminal 2", icon: "building.2",              highlight: false)
        Divider().background(SkyNavColor.surfaceBorder)
        FlightStatusRow(label: "Baggage Claim",   value: "Carousel 5", icon: "suitcase.rolling",        highlight: false)
        Divider().background(SkyNavColor.surfaceBorder)
        FlightStatusRow(label: "Aircraft",        value: "Boeing 737-800", icon: "airplane",            highlight: false)
        Divider().background(SkyNavColor.surfaceBorder)
        FlightStatusRow(label: "Flight Duration", value: "5h 23m",     icon: "clock",                   highlight: false)
        Divider().background(SkyNavColor.surfaceBorder)
        FlightStatusRow(label: "Distance",        value: "2,475 mi",   icon: "location",                highlight: false)
    }
    .padding(.horizontal, 16)
    .skyNavCard()
    .padding(24)
    .background(SkyNavColor.background)
    .preferredColorScheme(.dark)
}
