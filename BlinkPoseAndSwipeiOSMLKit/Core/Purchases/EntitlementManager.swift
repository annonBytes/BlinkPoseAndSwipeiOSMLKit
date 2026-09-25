import Foundation

// Single source of truth for "can this user upload more PDFs beyond the free
// built-in Welcome score": true during the local trial or with an active
// subscription, false otherwise (the Welcome score itself is never gated).
enum EntitlementManager {
    static var hasUnlimitedAccess: Bool {
        TrialManager.shared.isActive || SubscriptionStore.shared.isSubscribed
    }

    /// Performance-mode auto page turning is a paid feature: an active
    /// subscription is required, the free trial does not include it.
    static var hasPerformanceAccess: Bool {
        SubscriptionStore.shared.isSubscribed
    }
}
