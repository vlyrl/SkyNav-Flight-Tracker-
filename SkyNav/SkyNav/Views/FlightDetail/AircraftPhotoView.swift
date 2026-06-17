import SwiftUI

// MARK: - Planespotters API Models

private struct PlanespottersResponse: Codable {
    let photos: [PlanePhoto]
}

private struct PlanePhoto: Codable {
    let id: String
    let thumbnailLarge: ThumbnailInfo
    let link: String
    let photographer: String

    enum CodingKeys: String, CodingKey {
        case id
        case thumbnailLarge = "thumbnail_large"
        case link
        case photographer
    }
}

private struct ThumbnailInfo: Codable {
    let src: String
}

// MARK: - View Model

@Observable
private final class AircraftPhotoViewModel {
    var photo: PlanePhoto?
    var isLoading = false

    func load(registration: String) async {
        guard !registration.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        let urlString = "https://api.planespotters.net/pub/photos/reg/\(registration)"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(PlanespottersResponse.self, from: data)
            photo = response.photos.first
        } catch {
            photo = nil
        }
    }
}

// MARK: - Aircraft Photo View

struct AircraftPhotoView: View {
    let registration: String?
    let aircraftType: String?

    @State private var vm = AircraftPhotoViewModel()

    var body: some View {
        Group {
            if let reg = registration, !reg.isEmpty {
                content(registration: reg)
                    .task(id: reg) { await vm.load(registration: reg) }
            } else {
                silhouetteCard(registration: nil)
            }
        }
    }

    @ViewBuilder
    private func content(registration: String) -> some View {
        if vm.isLoading {
            loadingCard
        } else if let photo = vm.photo, let photoURL = URL(string: photo.thumbnailLarge.src) {
            photoCard(url: photoURL, photo: photo, registration: registration)
        } else {
            silhouetteCard(registration: registration)
        }
    }

    // MARK: Real Photo Card

    private func photoCard(url: URL, photo: PlanePhoto, registration: String) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                ZStack(alignment: .bottom) {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.72)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline) {
                            if let type = aircraftType {
                                Text(type)
                                    .font(.skyNavHeadline)
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Text(registration)
                                .font(.skyNavMono)
                                .foregroundStyle(SkyNavColor.accent)
                        }
                        Text("Photo: \(photo.photographer)")
                            .font(.skyNavCaption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(12)
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(SkyNavColor.surfaceBorder, lineWidth: 0.5)
                )
            default:
                silhouetteCard(registration: registration)
            }
        }
    }

    // MARK: Silhouette Fallback

    private func silhouetteCard(registration: String?) -> some View {
        ZStack(alignment: .bottom) {
            SkyNavGradient.activeCard

            PlaneSilhouette()
                .fill(SkyNavColor.accent.opacity(0.20))
                .frame(width: 200, height: 100)
                .padding(.bottom, 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(aircraftType ?? "Unknown Aircraft")
                        .font(.skyNavHeadline)
                        .foregroundStyle(aircraftType != nil ? SkyNavColor.textPrimary : SkyNavColor.textSecondary)
                    Spacer()
                    if let reg = registration {
                        Text(reg)
                            .font(.skyNavMono)
                            .foregroundStyle(SkyNavColor.accent)
                    }
                }
                Text("No photo available")
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textTertiary)
            }
            .padding(12)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(SkyNavColor.surfaceBorder, lineWidth: 0.5)
        )
    }

    // MARK: Loading Card

    private var loadingCard: some View {
        ZStack {
            SkyNavGradient.activeCard
            ProgressView()
                .tint(SkyNavColor.accent)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(SkyNavColor.surfaceBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Plane Silhouette Shape

struct PlaneSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height

        // Fuselage
        p.addRoundedRect(
            in: CGRect(x: w * 0.05, y: h * 0.42, width: w * 0.88, height: h * 0.16),
            cornerSize: CGSize(width: h * 0.08, height: h * 0.08)
        )

        // Nose
        p.move(to: CGPoint(x: w * 0.87, y: h * 0.42))
        p.addCurve(
            to: CGPoint(x: w * 0.98, y: h * 0.50),
            control1: CGPoint(x: w * 0.96, y: h * 0.42),
            control2: CGPoint(x: w * 0.98, y: h * 0.45)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.87, y: h * 0.58),
            control1: CGPoint(x: w * 0.98, y: h * 0.55),
            control2: CGPoint(x: w * 0.96, y: h * 0.58)
        )

        // Upper main wing
        p.move(to: CGPoint(x: w * 0.62, y: h * 0.44))
        p.addLine(to: CGPoint(x: w * 0.28, y: h * 0.04))
        p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.04))
        p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.44))
        p.closeSubpath()

        // Lower main wing
        p.move(to: CGPoint(x: w * 0.62, y: h * 0.56))
        p.addLine(to: CGPoint(x: w * 0.28, y: h * 0.96))
        p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.96))
        p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.56))
        p.closeSubpath()

        // Upper tail fin
        p.move(to: CGPoint(x: w * 0.14, y: h * 0.44))
        p.addLine(to: CGPoint(x: w * 0.05, y: h * 0.18))
        p.addLine(to: CGPoint(x: w * 0.02, y: h * 0.18))
        p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.44))
        p.closeSubpath()

        // Lower tail fin
        p.move(to: CGPoint(x: w * 0.14, y: h * 0.56))
        p.addLine(to: CGPoint(x: w * 0.05, y: h * 0.82))
        p.addLine(to: CGPoint(x: w * 0.02, y: h * 0.82))
        p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.56))
        p.closeSubpath()

        return p
    }
}

#Preview {
    VStack(spacing: 16) {
        AircraftPhotoView(registration: "N12345", aircraftType: "Boeing 737-800")
        AircraftPhotoView(registration: nil, aircraftType: nil)
    }
    .padding()
    .background(SkyNavColor.background)
}
