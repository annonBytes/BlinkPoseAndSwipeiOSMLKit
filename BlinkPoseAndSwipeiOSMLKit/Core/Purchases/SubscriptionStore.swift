import StoreKit

// StoreKit 2 wrapper for the single "Premium Monthly" auto-renewable
// subscription. Local development/testing uses Configuration.storekit (wired
// into the Xcode scheme) — no App Store Connect setup needed until this
// ships, at which point a real product with the same identifier must be
// created there.
final class SubscriptionStore {
    static let shared = SubscriptionStore()

    static let premiumMonthlyProductID = "com.bytepro.BlinkAndSwipeiOSMLKit.premium.monthly"

    private(set) var products: [Product] = []
    private(set) var isSubscribed = false

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.premiumMonthlyProductID])
        } catch {
            products = []
        }
    }

    @discardableResult
    func refreshEntitlements() async -> Bool {
        var subscribed = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.premiumMonthlyProductID {
                subscribed = true
            }
        }
        isSubscribed = subscribed
        return subscribed
    }

    func purchase() async throws {
        guard let product = products.first else { return }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
            }
            await refreshEntitlements()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }
}
