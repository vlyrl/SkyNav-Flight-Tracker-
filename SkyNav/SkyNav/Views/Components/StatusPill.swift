import SwiftUI

struct StatusPill: View {
    let status: FlightStatus
    var showIcon: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            if showIcon {
                Image(systemName: status.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(status.color)
            }
            Text(status.displayName)
                .font(.skyNavCaption)
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.10))
        .clipShape(Capsule())
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: status)
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
