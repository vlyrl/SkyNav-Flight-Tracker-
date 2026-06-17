import SwiftUI
import Foundation

struct FlightCard: View {
    let flight: Flight
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var isPressed: Bool = false
    @State private var pulsing: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    private var isActive: Bool {
        flight.status.isActive
    }

    private var originTimezone: TimeZone {
        TimeZone(identifier: flight.originTimezone) ?? .current
    }

    private var destinationTimezone: TimeZone {
        TimeZone(identifier: flight.destinationTimezone) ?? .current
    }

    private var formattedDuration: String {
        let seconds = flight.effectiveArrival.timeIntervalSince(flight.effectiveDeparture)
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var headingAngle: Double {
        flight.livePosition?.heading ?? 90.0
    }

    var body: some View {
        Button(action: {
            SkyNavHaptic.medium()
            onTap()
        }) {
            VStack(spacing: 0) {
                cardContent
                if isActive {
                    progressBar
                }
            }
            .modifier(FlightCardBackgroundModifier(isActive: isActive))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isActive
                            ? SkyNavColor.accent.opacity(pulsing ? 0.85 : 0.35)
                            : SkyNavColor.surfaceBorder,
                        lineWidth: isActive ? 1.0 : 0.5
                    )
                    .animation(
                        isActive
                            ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                            : .default,
                        value: pulsing
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Remove Flight", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Remove \(flight.flightNumber)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                SkyNavHaptic.warning()
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This flight will be removed from your tracked flights.")
        }
        .onAppear {
            if isActive {
                pulsing = true
            }
        }
    }

    private var cardContent: some View {
        VStack(spacing: 12) {
            topRow
            routeRow
            bottomRow
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, isActive ? 10 : 14)
    }

    private var topRow: some View {
        HStack(spacing: 10) {
            AirlineLogoView(iataCode: flight.airlineIata, size: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(flight.airlineName)
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textSecondary)
                    .lineLimit(1)
                Text(flight.flightNumber)
                    .font(.skyNavHeadline)
                    .foregroundStyle(SkyNavColor.textPrimary)
            }

            Spacer()

            StatusPill(status: flight.status)
        }
    }

    private var routeRow: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(flight.originIata)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(SkyNavColor.textPrimary)

                Text(formattedLocalTime(flight.effectiveDeparture, timezone: originTimezone))
                    .font(.skyNavMono)
                    .foregroundStyle(
                        flight.delayMinutes > 0
                            ? SkyNavColor.statusDelayed
                            : SkyNavColor.textPrimary
                    )

                Text(flight.originCity)
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(spacing: 4) {
                Spacer().frame(height: 12)
                flightPathIndicator
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(flight.destinationIata)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(SkyNavColor.textPrimary)

                Text(formattedLocalTime(flight.effectiveArrival, timezone: destinationTimezone))
                    .font(.skyNavMono)
                    .foregroundStyle(SkyNavColor.textPrimary)

                Text(flight.destinationCity)
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var flightPathIndicator: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(SkyNavColor.textTertiary)
                .frame(width: 5, height: 5)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [SkyNavColor.textTertiary, SkyNavColor.textTertiary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .overlay(
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { _ in
                            Capsule()
                                .fill(SkyNavColor.textTertiary)
                                .frame(width: 4, height: 1)
                        }
                    }
                )

            Image(systemName: "airplane")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    isActive ? SkyNavColor.accent : SkyNavColor.textSecondary
                )
                .rotationEffect(.degrees(headingAngle - 90))
                .shadow(color: isActive ? SkyNavColor.accent.opacity(0.6) : .clear, radius: 4)

            Rectangle()
                .fill(SkyNavColor.textTertiary)
                .frame(height: 1)
                .overlay(
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { _ in
                            Capsule()
                                .fill(SkyNavColor.textTertiary)
                                .frame(width: 4, height: 1)
                        }
                    }
                )

            Circle()
                .fill(SkyNavColor.textTertiary)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: 120)
    }

    private var bottomRow: some View {
        HStack(spacing: 12) {
            Label(formattedDuration, systemImage: "clock")
                .font(.skyNavCaption)
                .foregroundStyle(SkyNavColor.textSecondary)

            if let gate = flight.departureGate {
                Divider()
                    .frame(height: 12)
                    .background(SkyNavColor.textTertiary)

                Label("Gate \(gate)", systemImage: "door.left.hand.open")
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textSecondary)
            }

            if let baggage = flight.baggageClaim {
                Divider()
                    .frame(height: 12)
                    .background(SkyNavColor.textTertiary)

                Label("Belt \(baggage)", systemImage: "suitcase")
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textSecondary)
            }

            Spacer()

            if flight.delayMinutes > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SkyNavColor.statusDelayed)
                    Text("+\(flight.delayMinutes)m")
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.statusDelayed)
                }
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(SkyNavColor.surfaceBorder)
                    .frame(height: 3)

                Rectangle()
                    .fill(SkyNavGradient.flightProgress)
                    .frame(width: geometry.size.width * flight.progressFraction, height: 3)
                    .animation(.easeInOut(duration: 0.8), value: flight.progressFraction)
            }
        }
        .frame(height: 3)
        .clipShape(
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private func formattedLocalTime(_ date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }
}

// MARK: - iOS 26 Glass Modifier

private struct FlightCardBackgroundModifier: ViewModifier {
    let isActive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if isActive {
                content
                    .glassEffect(.regular.tinted(Color(hex: "#1A2340").opacity(0.5)), in: .rect(cornerRadius: 16))
            } else {
                content
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
        } else {
            content
                .skyNavCard(gradient: isActive ? SkyNavGradient.activeCard : SkyNavGradient.card)
        }
    }
}
