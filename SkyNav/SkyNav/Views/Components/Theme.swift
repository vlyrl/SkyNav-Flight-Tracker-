import SwiftUI

// MARK: - SkyNav Design System

enum SkyNavColor {
    // Primary palette
    static let background     = Color(hex: "#0A0A0F")
    static let surface        = Color(hex: "#12121A")
    static let surfaceRaised  = Color(hex: "#1C1C28")
    static let surfaceBorder  = Color(hex: "#252535")

    // Accent
    static let accent         = Color(hex: "#4A9EFF")
    static let accentGlow     = Color(hex: "#4A9EFF").opacity(0.15)
    static let accentDim      = Color(hex: "#2B6FCC")

    // Status colors
    static let statusOnTime    = Color(hex: "#34C759")
    static let statusDelayed   = Color(hex: "#FF9F0A")
    static let statusCancelled = Color(hex: "#FF453A")
    static let statusBoarding  = Color(hex: "#30D158")
    static let statusInFlight  = Color(hex: "#64D2FF")
    static let statusLanded    = Color(hex: "#8E8E93")

    // Text
    static let textPrimary    = Color.white
    static let textSecondary  = Color(hex: "#8E8E93")
    static let textTertiary   = Color(hex: "#48484A")

    // Premium
    static let gold           = Color(hex: "#FFD60A")
    static let goldGradient   = LinearGradient(
        colors: [Color(hex: "#FFD60A"), Color(hex: "#FF9F0A")],
        startPoint: .leading, endPoint: .trailing
    )
}

enum SkyNavGradient {
    static let card = LinearGradient(
        colors: [Color(hex: "#1C1C28"), Color(hex: "#12121A")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let flightProgress = LinearGradient(
        colors: [Color(hex: "#4A9EFF"), Color(hex: "#30D158")],
        startPoint: .leading, endPoint: .trailing
    )

    static let activeCard = LinearGradient(
        colors: [Color(hex: "#1A2340"), Color(hex: "#0D1520")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let hero = LinearGradient(
        colors: [Color(hex: "#0A0A0F"), Color(hex: "#0D1A30")],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - Status → Color Mapping

extension FlightStatus {
    var color: Color {
        switch self {
        case .scheduled:  return SkyNavColor.textSecondary
        case .delayed:    return SkyNavColor.statusDelayed
        case .boarding:   return SkyNavColor.statusBoarding
        case .departed:   return SkyNavColor.statusInFlight
        case .inFlight:   return SkyNavColor.statusInFlight
        case .landed:     return SkyNavColor.statusLanded
        case .arrived:    return SkyNavColor.statusLanded
        case .cancelled:  return SkyNavColor.statusCancelled
        case .diverted:   return SkyNavColor.statusDelayed
        }
    }

    var icon: String {
        switch self {
        case .scheduled:  return "clock"
        case .delayed:    return "clock.badge.exclamationmark"
        case .boarding:   return "figure.walk"
        case .departed:   return "airplane.departure"
        case .inFlight:   return "airplane"
        case .landed:     return "airplane.arrival"
        case .arrived:    return "checkmark.circle.fill"
        case .cancelled:  return "xmark.circle.fill"
        case .diverted:   return "arrow.triangle.turn.up.right.circle"
        }
    }
}

// MARK: - Font Tokens

extension Font {
    static let skyNavDisplay    = Font.system(size: 34, weight: .bold, design: .rounded)
    static let skyNavTitle      = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let skyNavHeadline   = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let skyNavBody       = Font.system(size: 15, weight: .regular, design: .rounded)
    static let skyNavCaption    = Font.system(size: 12, weight: .medium, design: .rounded)
    static let skyNavMono       = Font.system(size: 14, weight: .semibold, design: .monospaced)
    static let skyNavMonoLarge  = Font.system(size: 20, weight: .bold, design: .monospaced)
    static let skyNavTime       = Font.system(size: 28, weight: .bold, design: .rounded)
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    var gradient: LinearGradient = SkyNavGradient.card
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(SkyNavColor.surfaceBorder, lineWidth: 0.5)
            )
    }
}

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            )
    }
}

extension View {
    func skyNavCard(gradient: LinearGradient = SkyNavGradient.card, cornerRadius: CGFloat = 16) -> some View {
        modifier(CardStyle(gradient: gradient, cornerRadius: cornerRadius))
    }

    func glassCard() -> some View {
        modifier(GlassCard())
    }
}

// MARK: - Haptics

enum SkyNavHaptic {
    static func light()  { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy()  { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func select()  { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
