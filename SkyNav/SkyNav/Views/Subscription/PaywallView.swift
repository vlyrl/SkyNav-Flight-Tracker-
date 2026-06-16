import SwiftUI
import StoreKit

// MARK: - PaywallView

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SubscriptionViewModel

    @State private var featureAnimations: [Bool] = []
    @State private var heroAnimated: Bool = false
    @State private var glowPulse: Bool = false
    @State private var purchaseError: String? = nil
    @State private var showError: Bool = false

    init(viewModel: SubscriptionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SkyNavColor.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    featuresSection
                    planSelector
                    ctaSection
                    footerSection
                }
            }

            // Dismiss button
            Button {
                SkyNavHaptic.light()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SkyNavColor.textSecondary)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
            }
            .padding(.top, 16)
            .padding(.trailing, 20)
        }
        .preferredColorScheme(.dark)
        .alert("Purchase Failed", isPresented: $showError, presenting: purchaseError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error)
        }
        .onAppear {
            startAppearAnimations()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack {
            // Animated gradient background
            AnimatedHeroGradient()
                .frame(height: 340)
                .clipped()

            VStack(spacing: 20) {
                // Airplane icon with glow
                ZStack {
                    Circle()
                        .fill(SkyNavColor.accent.opacity(glowPulse ? 0.25 : 0.10))
                        .frame(width: glowPulse ? 96 : 88, height: glowPulse ? 96 : 88)
                        .blur(radius: 12)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: glowPulse)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [SkyNavColor.accent.opacity(0.35), SkyNavColor.accentDim.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay(Circle().strokeBorder(SkyNavColor.accent.opacity(0.4), lineWidth: 1))

                    Image(systemName: "airplane")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, SkyNavColor.accent],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }
                .scaleEffect(heroAnimated ? 1 : 0.7)
                .opacity(heroAnimated ? 1 : 0)

                VStack(spacing: 10) {
                    Text("SkyNav Premium")
                        .font(.skyNavDisplay)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(hex: "#A8CFFF")],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .opacity(heroAnimated ? 1 : 0)
                        .offset(y: heroAnimated ? 0 : 12)

                    Text("Your flights, perfectly tracked")
                        .font(.skyNavBody)
                        .foregroundStyle(SkyNavColor.textSecondary)
                        .opacity(heroAnimated ? 1 : 0)
                        .offset(y: heroAnimated ? 0 : 8)
                }
            }
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Everything you need")
                    .font(.skyNavTitle)
                    .foregroundStyle(SkyNavColor.textPrimary)

                Text("One subscription, total peace of mind.")
                    .font(.skyNavBody)
                    .foregroundStyle(SkyNavColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 20)

            VStack(spacing: 12) {
                ForEach(Array(viewModel.premiumFeatures.enumerated()), id: \.offset) { index, feature in
                    FeatureRow(
                        text: feature,
                        icon: featureIcon(for: index),
                        appeared: featureAnimations.indices.contains(index) ? featureAnimations[index] : false
                    )
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Plan Selector

    private var planSelector: some View {
        VStack(spacing: 12) {
            Text("CHOOSE YOUR PLAN")
                .font(.skyNavCaption)
                .foregroundStyle(SkyNavColor.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                // Annual plan (left, more prominent)
                PlanCard(
                    title: "Annual",
                    price: annualPriceString,
                    period: "per year",
                    badge: "Most Popular",
                    savingsBadge: "Save 33%",
                    isSelected: viewModel.selectedPlan == .annual,
                    onSelect: {
                        SkyNavHaptic.select()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedPlan = .annual
                        }
                    }
                )

                // Monthly plan (right)
                PlanCard(
                    title: "Monthly",
                    price: monthlyPriceString,
                    period: "per month",
                    badge: nil,
                    savingsBadge: nil,
                    isSelected: viewModel.selectedPlan == .monthly,
                    onSelect: {
                        SkyNavHaptic.select()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedPlan = .monthly
                        }
                    }
                )
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button {
                SkyNavHaptic.medium()
                Task {
                    await viewModel.purchase()
                    if viewModel.isPremium {
                        dismiss()
                    } else if let error = viewModel.errorMessage {
                        purchaseError = error
                        showError = true
                        viewModel.errorMessage = nil
                    }
                }
            } label: {
                ZStack {
                    if viewModel.isPurchasing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        VStack(spacing: 3) {
                            Text("Continue with \(viewModel.selectedPlan == .annual ? "Annual" : "Monthly")")
                                .font(.skyNavHeadline)
                                .foregroundStyle(.white)

                            Text(ctaSubtitle)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    viewModel.isPurchasing
                        ? AnyShapeStyle(SkyNavColor.accentDim)
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [SkyNavColor.accent, SkyNavColor.accentDim],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: SkyNavColor.accent.opacity(0.45), radius: 16, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isPurchasing)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isPurchasing)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 16) {
            // Restore
            Button {
                SkyNavHaptic.light()
                Task { await viewModel.restore() }
            } label: {
                Text("Restore Purchases")
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.accent)
                    .underline(false)
            }
            .buttonStyle(.plain)

            HStack(spacing: 16) {
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(SkyNavColor.textTertiary)

                Text("·")
                    .font(.system(size: 11))
                    .foregroundStyle(SkyNavColor.textTertiary)

                Link("Terms of Use", destination: URL(string: "https://example.com/terms")!)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(SkyNavColor.textTertiary)
            }

            Button {
                SkyNavHaptic.light()
                dismiss()
            } label: {
                Text("Continue with free features")
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textTertiary)
                    .underline()
            }
            .buttonStyle(.plain)

            Text("Subscriptions auto-renew. Cancel anytime in App Store settings.")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(SkyNavColor.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 24)
        .padding(.bottom, 48)
    }

    // MARK: - Helpers

    private var monthlyPriceString: String {
        if let product = viewModel.monthlyProduct {
            return product.displayPrice
        }
        return "$4.99"
    }

    private var annualPriceString: String {
        if let product = viewModel.annualProduct {
            return product.displayPrice
        }
        return "$39.99"
    }

    private var ctaSubtitle: String {
        switch viewModel.selectedPlan {
        case .annual:
            return "\(annualPriceString)/year · billed annually"
        case .monthly:
            return "\(monthlyPriceString)/month · billed monthly"
        }
    }

    private func featureIcon(for index: Int) -> String {
        let icons = [
            "infinity.circle.fill",
            "map.fill",
            "bell.badge.fill",
            "rectangle.on.rectangle",
            "livephoto"
        ]
        guard index < icons.count else { return "star.fill" }
        return icons[index]
    }

    private func startAppearAnimations() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.1)) {
            heroAnimated = true
        }
        glowPulse = true

        let featureCount = viewModel.premiumFeatures.count
        featureAnimations = Array(repeating: false, count: featureCount)
        for i in 0..<featureCount {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.3 + Double(i) * 0.08)) {
                if i < featureAnimations.count {
                    featureAnimations[i] = true
                }
            }
        }
    }
}

// MARK: - AnimatedHeroGradient

struct AnimatedHeroGradient: View {
    @State private var animate: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#050510"),
                    Color(hex: "#0A0A2A"),
                    Color(hex: "#0D0D35"),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Animated blobs
            Circle()
                .fill(Color(hex: "#1A2870").opacity(0.5))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: animate ? -40 : 40, y: animate ? -20 : 20)
                .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: animate)

            Circle()
                .fill(Color(hex: "#2B1070").opacity(0.4))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: animate ? 60 : -30, y: animate ? 40 : -10)
                .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: animate)

            Circle()
                .fill(SkyNavColor.accent.opacity(0.08))
                .frame(width: 150, height: 150)
                .blur(radius: 40)
                .offset(x: animate ? 20 : -50, y: animate ? -40 : 20)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animate)
        }
        .onAppear { animate = true }
    }
}

// MARK: - FeatureRow

struct FeatureRow: View {
    let text: String
    let icon: String
    let appeared: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(SkyNavColor.accent.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SkyNavColor.accent)
            }

            Text(text)
                .font(.skyNavBody)
                .foregroundStyle(SkyNavColor.textPrimary)

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(SkyNavColor.statusOnTime)
        }
        .padding(14)
        .background(SkyNavColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(SkyNavColor.surfaceBorder, lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -20)
    }
}

// MARK: - PlanCard

struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    let badge: String?
    let savingsBadge: String?
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 10) {
                // Badges row
                HStack(spacing: 6) {
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(SkyNavColor.accent)
                            .clipShape(Capsule())
                    }

                    if let savings = savingsBadge {
                        Text(savings)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(SkyNavColor.gold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(SkyNavColor.gold.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: badge != nil ? .leading : .center)
                .opacity(badge != nil || savingsBadge != nil ? 1 : 0)
                .frame(height: 24)

                Spacer()

                Text(title)
                    .font(.skyNavCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? SkyNavColor.textPrimary : SkyNavColor.textSecondary)

                Text(price)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? SkyNavColor.textPrimary : SkyNavColor.textSecondary)

                Text(period)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(SkyNavColor.textTertiary)

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? SkyNavColor.accent : SkyNavColor.surfaceBorder,
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(SkyNavColor.accent)
                            .frame(width: 12, height: 12)
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(
                isSelected
                    ? SkyNavGradient.activeCard
                    : LinearGradient(colors: [SkyNavColor.surface, SkyNavColor.surface], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? SkyNavColor.accent : SkyNavColor.surfaceBorder,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .shadow(
                color: isSelected ? SkyNavColor.accent.opacity(0.2) : Color.clear,
                radius: 12, y: 4
            )
        }
        .buttonStyle(.plain)
    }
}
