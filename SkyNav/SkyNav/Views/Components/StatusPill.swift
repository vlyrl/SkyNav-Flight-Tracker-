import SwiftUI

struct StatusPill: View {
    let status: FlightStatus
    var showIcon: Bool = true

    // For delayed: white text on charcoal bg.
    // For boarding: white text on accent blue bg.
    // All others: status.color text on status.color.opacity(0.10) bg.
    private var labelColor: Color {
        switch status {
        case .delayed:  return .white
        case .boarding: return .white
        default:        return status.color
        }
    }

    private var pillBackground: Color {
        switch status {
        case .delayed:  return SkyNavColor.statusDelayedBadge
        case .boarding: return SkyNavColor.statusBoarding
        default:        return status.color.opacity(0.10)
        }
    }

    var body: some View {
        pillContent
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: status)
    }

    @ViewBuilder
    private var pillContent: some View {
        if #available(iOS 26, *) {
            HStack(spacing: 4) {
                if showIcon {
                    Image(systemName: status.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(labelColor)
                }
                Text(status.displayName)
                    .font(.skyNavCaption)
                    .foregroundStyle(labelColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .glassEffect(.regular.tinted(pillBackground.opacity(0.6)), in: .capsule)
        } else {
            HStack(spacing: 4) {
                if showIcon {
                    Image(systemName: status.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(labelColor)
                }
                Text(status.displayName)
                    .font(.skyNavCaption)
                    .foregroundStyle(labelColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(pillBackground)
            .clipShape(Capsule())
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(FlightStatus.allCases, id: \.self) { status in
            StatusPill(status: status)
        }
    }
    .padding()
    .background(SkyNavColor.background)
}
