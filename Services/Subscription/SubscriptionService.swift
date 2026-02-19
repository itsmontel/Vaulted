import Foundation
import StoreKit

// MARK: - Subscription Service (StoreKit 2)
// Product IDs: Configure in App Store Connect as vaulted_pro_monthly, vaulted_pro_yearly
// US: $5.99/mo, $49.99/yr | UK: £4.99/mo, £39.99/yr | 3-day free trial
@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    static let monthlyProductId = "vaulted_pro_monthly"
    static let yearlyProductId = "vaulted_pro_yearly"

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseError: String?
    @Published private(set) var isLoading = false
    @Published private(set) var hasAccess = false

    private var updateListener: Task<Void, Error>?

    private init() {
        updateListener = listenForTransactions()
        Task { await loadProducts() }
        Task { await updateAccess() }
    }

    deinit { updateListener?.cancel() }

    // MARK: - Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [Self.monthlyProductId, Self.yearlyProductId])
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyProductId } }
    var yearlyProduct: Product? { products.first { $0.id == Self.yearlyProductId } }

    // MARK: - Purchase

    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateAccess()
                return true
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        purchaseError = nil
        do {
            try await AppStore.sync()
            await updateAccess()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Access

    func updateAccess() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if tx.productID == Self.monthlyProductId || tx.productID == Self.yearlyProductId {
                hasAccess = true
                return
            }
        }
        // Also check if in introductory offer (free trial)
        for await result in Transaction.all {
            guard case .verified(let tx) = result else { continue }
            if tx.productID == Self.monthlyProductId || tx.productID == Self.yearlyProductId {
                if let expiration = tx.expirationDate, expiration > Date() {
                    hasAccess = true
                    return
                }
            }
        }
        hasAccess = false
    }

    // MARK: - Listeners

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let tx) = result else { continue }
                await tx.finish()
                await self?.updateAccess()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let t): return t
        case .unverified: throw StoreError.failedVerification
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
