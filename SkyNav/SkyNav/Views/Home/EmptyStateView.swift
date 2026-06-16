import SwiftUI

struct EmptyStateView: View {
    let onAddFlight: () -> Void

    @State private var bobbing: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "airplane.circle")
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(SkyNavColor.accent.opacity(0.6))
                .shadow(color: SkyNavColor.accent.opacity(0.25), radius: 16)
                .offset(y: bobbing ? -8 : 0)
                .animation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true),
                    value: bobbing
                )

            VStack(spacing: 8) {
                Text("No Flights Yet")
                    .font(.skyNavTitle)
                    .foregroundStyle(SkyNavColor.textPrimary)

                Text("Add your first flight to get started")
                    .font(.skyNavBody)
                    .foregroundStyle(SkyNavColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                SkyNavHaptic.medium()
                onAddFlight()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Add Flight")
                        .font(.skyNavHeadline)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(SkyNavColor.accent)
                .clipShape(Capsule())
                .shadow(color: SkyNavColor.accent.opacity(0.4), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            bobbing = true
        }
    }
}

#Preview {
    EmptyStateView(onAddFlight: {})
        .background(SkyNavColor.background)
}
