import StoreKit

// StoreKit 2 wrapper for the "Premium" auto-renewable subscription group: a
// monthly and a yearly plan. Local development/testing uses Configuration.storekit (wired
// into the Xcode scheme) — no App Store Connect setup needed until this
// ships, at which point a real product with the same identifier must be
// created there.
final class SubscriptionStore {
    static let shared = SubscriptionStore()

    enum Plan: CaseIterable {
        case monthly, yearly

        var productID: String {
            switch self {
            case .monthly: return "com.bytepro.BlinkAndSwipeiOSMLKit.premium.monthly"
            case .yearly: return "com.bytepro.BlinkAndSwipeiOSMLKit.premium.yearly"
            }
        }
    }

    static let premiumMonthlyProductID = Plan.monthly.productID

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
            products = try await Product.products(for: Plan.allCases.map(\.productID))
        } catch {
            products = []
        }
    }

    @discardableResult
    func refreshEntitlements() async -> Bool {
        var subscribed = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, Plan.allCases.contains(where: { $0.productID == transaction.productID }) {
                subscribed = true
            }
        }
        isSubscribed = subscribed
        return subscribed
    }

    func product(for plan: Plan) -> Product? {
        products.first { $0.id == plan.productID }
    }

    func purchase(plan: Plan) async throws {
        guard let product = product(for: plan) else { return }
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
