import Foundation

// Single source of truth for "can this user upload more PDFs beyond the free
// built-in Welcome score": true during the local trial or with an active
// subscription, false otherwise (the Welcome score itself is never gated).
enum EntitlementManager {
    static var hasUnlimitedAccess: Bool {
        TrialManager.shared.isActive || SubscriptionStore.shared.isSubscribed
    }
}
