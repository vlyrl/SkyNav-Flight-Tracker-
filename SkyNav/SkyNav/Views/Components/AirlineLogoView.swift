import SwiftUI

struct AirlineLogoView: View {
    let iataCode: String
    let size: CGFloat

    private var logoURL: URL? {
        URL(string: "https://www.gstatic.com/flights/airline_logos/70px/\(iataCode.uppercased()).png")
    }

    var body: some View {
        AsyncImage(url: logoURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.10)
                    .frame(width: size, height: size)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                            .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                    )
            default:
                fallbackView
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Fallback (colored box with initials)

    private var fallbackView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                )

            Text(initials)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(width: size, height: size)
    }

    private var backgroundColor: Color {
        let palette: [Color] = [
            Color(hex: "#1A3A5C"),
            Color(hex: "#1A4A2E"),
            Color(hex: "#3A1A4A"),
            Color(hex: "#4A2A1A"),
            Color(hex: "#1A1A4A"),
            Color(hex: "#4A1A1A"),
            Color(hex: "#1A3A3A"),
            Color(hex: "#2A3A1A"),
        ]
        let hash = iataCode.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[abs(hash) % palette.count]
    }

    private var initials: String {
        let letters = iataCode.uppercased().filter { $0.isLetter }
        if letters.count <= 2 { return String(letters) }
        return String(letters.prefix(2))
    }

    private var fontSize: CGFloat { size * 0.38 }
}

#Preview {
    HStack(spacing: 16) {
        AirlineLogoView(iataCode: "AA", size: 44)
        AirlineLogoView(iataCode: "UA", size: 44)
        AirlineLogoView(iataCode: "DL", size: 44)
        AirlineLogoView(iataCode: "WN", size: 44)
        AirlineLogoView(iataCode: "BA", size: 44)
    }
    .padding()
    .background(SkyNavColor.background)
}
