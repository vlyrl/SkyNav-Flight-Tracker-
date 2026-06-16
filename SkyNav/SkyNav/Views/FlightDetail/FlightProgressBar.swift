import SwiftUI

// MARK: - Flight Progress Bar

/// Horizontal progress bar showing flight position from origin to destination.
/// The airplane icon slides along the track and rotates to match the live heading.
struct FlightProgressBar: View {
    let originIata: String
    let destinationIata: String
    /// Value from 0.0 (at origin) to 1.0 (at destination).
    let progress: Double
    /// Aircraft heading in degrees (0 = North, 90 = East). Nil when unknown.
    let heading: Double?

    // Animate the plane position with a spring so live updates feel smooth.
    @State private var animatedProgress: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            // Origin IATA
            Text(originIata)
                .font(.skyNavMono)
                .foregroundStyle(SkyNavColor.textSecondary)
                .frame(minWidth: 34, alignment: .leading)

            // Track + airplane
            GeometryReader { geo in
                let trackWidth = geo.size.width
                let planeX = trackWidth * animatedProgress

                ZStack(alignment: .leading) {
                    // Background dashed track
                    dashedTrack(width: trackWidth)

                    // Colored completed-portion track
                    completedTrack(width: trackWidth)

                    // Airplane icon
                    airplaneIcon
                        .offset(x: planeX - 10)   // center the 20-pt icon over the point
                }
                .frame(height: 20)
            }
            .frame(height: 20)

            // Destination IATA
            Text(destinationIata)
                .font(.skyNavMono)
                .foregroundStyle(SkyNavColor.textSecondary)
                .frame(minWidth: 34, alignment: .trailing)
        }
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }

    // MARK: Sub-views

    private func dashedTrack(width: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 10))
            path.addLine(to: CGPoint(x: width, y: 10))
        }
        .stroke(
            SkyNavColor.surfaceBorder,
            style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
        )
    }

    private func completedTrack(width: CGFloat) -> some View {
        Rectangle()
            .fill(SkyNavGradient.flightProgress)
            .frame(width: max(0, width * animatedProgress), height: 2)
            .offset(y: 9)
            .clipShape(Capsule())
    }

    private var airplaneIcon: some View {
        Image(systemName: "airplane")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(SkyNavColor.accent)
            .rotationEffect(planeRotation)
            .frame(width: 20, height: 20)
            .shadow(color: SkyNavColor.accent.opacity(0.6), radius: 4)
    }

    /// Map heading (degrees from North) to SwiftUI rotation.
    /// Default heading for a left-to-right track is 90° (East), so we offset by −90.
    private var planeRotation: Angle {
        guard let heading else { return .degrees(0) }
        return .degrees(heading - 90)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        FlightProgressBar(
            originIata: "LAX",
            destinationIata: "JFK",
            progress: 0.62,
            heading: 80
        )
        FlightProgressBar(
            originIata: "ORD",
            destinationIata: "LHR",
            progress: 0.0,
            heading: nil
        )
        FlightProgressBar(
            originIata: "SFO",
            destinationIata: "NRT",
            progress: 1.0,
            heading: 285
        )
    }
    .padding(24)
    .background(SkyNavColor.background)
    .preferredColorScheme(.dark)
}
