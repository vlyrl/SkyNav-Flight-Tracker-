import Foundation
import StoreKit
import Observation

enum SubscriptionPlan {
    case monthly, annual
}

@Observable
@MainActor
final class SubscriptionViewModel {
    var isPremium = false
    var monthlyProduct: Product?
    var annualProduct: Product?
    var selectedPlan: SubscriptionPlan = .annual
    var isPurchasing = false
    var errorMessage: String?

    let premiumFeatures = [
        "Unlimited tracked flights",
        "Live in-flight map & position",
        "Push notifications for every update",
        "Home screen widgets",
        "Live Activities & Dynamic Island",
        "Airport departure & arrival boards",
        "Multi-leg trip itineraries",
    ]

    private let monthlyId = "com.skynav.app.premium.monthly"
    private let annualId  = "com.skynav.app.premium.annual"

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [monthlyId, annualId])
            monthlyProduct = products.first { $0.id == monthlyId }
            annualProduct  = products.first { $0.id == annualId }
            await checkEntitlements()
        } catch {
            // Products unavailable in sandbox / no StoreKit config — gracefully degrade
        }
    }

    func purchase() async {
        let product = selectedPlan == .monthly ? monthlyProduct : annualProduct
        guard let product else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified:
                    isPremium = true
                    SkyNavHaptic.success()
                case .unverified:
                    errorMessage = "Purchase could not be verified."
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await checkEntitlements()
            if isPremium { SkyNavHaptic.success() }
        } catch {
            errorMessage = "Could not restore purchases."
        }
    }

    var selectedProductDisplayPrice: String {
        switch selectedPlan {
        case .monthly: return monthlyProduct?.displayPrice ?? "$4.99/month"
        case .annual:  return annualProduct?.displayPrice ?? "$39.99/year"
        }
    }

    private func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == monthlyId || tx.productID == annualId,
               tx.revocationDate == nil {
                isPremium = true
                return
            }
        }
        isPremium = false
    }
}
