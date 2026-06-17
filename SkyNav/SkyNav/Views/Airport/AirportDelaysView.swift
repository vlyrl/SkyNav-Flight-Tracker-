import SwiftUI

// MARK: - AirportDelaysView
// Shows FAA Ground Delay Programs for a given airport (mock data).

struct AirportDelaysView: View {
    let iataCode: String

    private var programs: [GroundDelay] {
        AirportDelayService.activePrograms(for: iataCode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SkyNavColor.accent)
                Text("GROUND DELAYS & PROGRAMS")
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textTertiary)
                    .tracking(1.0)
            }

            if programs.isEmpty {
                noDelaysRow
            } else {
                VStack(spacing: 10) {
                    ForEach(programs) { program in
                        DelayProgramRow(program: program)
                    }
                }
            }
        }
    }

    private var noDelaysRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(SkyNavColor.statusOnTime)

            VStack(alignment: .leading, spacing: 2) {
                Text("No Active Programs")
                    .font(.skyNavBody)
                    .foregroundStyle(SkyNavColor.textPrimary)
                Text("Operations running normally at \(iataCode)")
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(SkyNavColor.statusOnTime.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(SkyNavColor.statusOnTime.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - DelayProgramRow

struct DelayProgramRow: View {
    let program: GroundDelay

    private var isGroundStop: Bool { program.program == "Ground Stop" }

    private var badgeColor: Color {
        isGroundStop ? SkyNavColor.statusCancelled : SkyNavColor.statusDelayedBadge
    }

    private var badgeForeground: Color {
        isGroundStop ? .white : SkyNavColor.statusDelayed
    }

    private var badgeText: String {
        isGroundStop ? "GROUND STOP" : "DELAY \(program.avgDelay)m"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Badge
            Text(badgeText)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(badgeForeground)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(badgeColor.opacity(isGroundStop ? 1 : 0.8))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    isGroundStop ? nil :
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(SkyNavColor.statusDelayed.opacity(0.3), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(program.program)
                    .font(.skyNavCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(SkyNavColor.textPrimary)
                Text("\(program.reason) · \(program.scope)")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(SkyNavColor.textSecondary)
            }

            Spacer()

            if program.avgDelay > 0 {
                Text("avg \(program.avgDelay)m")
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textTertiary)
            }
        }
        .padding(14)
        .background(isGroundStop
            ? SkyNavColor.statusCancelled.opacity(0.08)
            : SkyNavColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isGroundStop
                        ? SkyNavColor.statusCancelled.opacity(0.3)
                        : SkyNavColor.surfaceBorder,
                    lineWidth: 1
                )
        )
    }
}
