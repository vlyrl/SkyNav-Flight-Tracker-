import SwiftUI

// MARK: - LayoverCard

struct LayoverCard: View {
    let layoverAirport: String
    let duration: TimeInterval
    let isActive: Bool

    @State private var timeRemaining: TimeInterval
    @State private var countdownTimer: Timer?

    init(layoverAirport: String, duration: TimeInterval, isActive: Bool) {
        self.layoverAirport = layoverAirport
        self.duration = duration
        self.isActive = isActive
        _timeRemaining = State(initialValue: duration)
    }

    // MARK: - Severity

    private var severity: LayoverSeverity {
        let minutes = duration / 60
        if minutes >= 90 { return .comfortable }
        if minutes >= 45 { return .tight }
        return .risky
    }

    private enum LayoverSeverity {
        case comfortable, tight, risky

        var color: Color {
            switch self {
            case .comfortable: return SkyNavColor.statusOnTime
            case .tight:       return SkyNavColor.statusDelayed
            case .risky:       return SkyNavColor.statusCancelled
            }
        }

        var label: String {
            switch self {
            case .comfortable: return "Comfortable"
            case .tight:       return "Tight"
            case .risky:       return "Very Tight"
            }
        }

        var icon: String {
            switch self {
            case .comfortable: return "checkmark.circle.fill"
            case .tight:       return "exclamationmark.circle.fill"
            case .risky:       return "exclamationmark.triangle.fill"
            }
        }
    }

    // MARK: - Duration Formatting

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var countdownString: String {
        let totalSeconds = Int(timeRemaining)
        if totalSeconds <= 0 { return "0m" }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left timeline connector
            VStack(spacing: 0) {
                Rectangle()
                    .fill(SkyNavColor.surfaceBorder)
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)

                Circle()
                    .fill(severity.color)
                    .frame(width: 8, height: 8)

                Rectangle()
                    .fill(SkyNavColor.surfaceBorder)
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)
            .padding(.leading, 10)

            // Card body
            HStack(spacing: 12) {
                // Airport + label
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(layoverAirport)
                            .font(.skyNavMono)
                            .foregroundStyle(SkyNavColor.textPrimary)

                        Text("·")
                            .foregroundStyle(SkyNavColor.textTertiary)

                        Text("Layover")
                            .font(.skyNavCaption)
                            .foregroundStyle(SkyNavColor.textSecondary)
                    }

                    HStack(spacing: 5) {
                        Text(formattedDuration(duration))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(severity.color)

                        Image(systemName: severity.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(severity.color)

                        Text(severity.label)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(severity.color.opacity(0.8))
                    }
                }

                Spacer()

                // Countdown (only when active)
                if isActive {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(countdownString)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(severity.color)
                            .contentTransition(.numericText())
                            .animation(.linear(duration: 0.3), value: countdownString)

                        Text("remaining")
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundStyle(SkyNavColor.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(severity.color.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(severity.color.opacity(0.22), lineWidth: 1)
            )
            .padding(.leading, 10)
            .padding(.trailing, 4)
        }
        .frame(height: 64)
        .onAppear {
            if isActive {
                startCountdown()
            }
        }
        .onDisappear {
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
    }

    // MARK: - Timer

    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                withAnimation {
                    timeRemaining -= 1
                }
            } else {
                countdownTimer?.invalidate()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        LayoverCard(layoverAirport: "ORD", duration: 7200, isActive: false)
        LayoverCard(layoverAirport: "DFW", duration: 3900, isActive: true)
        LayoverCard(layoverAirport: "ATL", duration: 1800, isActive: false)
    }
    .padding()
    .background(SkyNavColor.background)
}
