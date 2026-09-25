import Foundation

// A no-payment-required grace period: every install gets 7 days of full
// access starting from first launch, tracked purely locally (no backend, no
// StoreKit introductory offer — just a UserDefaults timestamp).
final class TrialManager {
    static let shared = TrialManager()

    private let trialLength: TimeInterval = 7 * 24 * 60 * 60
    private let firstLaunchDateKey = "TrialManager.firstLaunchDate"
    private let defaults: UserDefaults

    private(set) var firstLaunchDate: Date

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let existing = defaults.object(forKey: firstLaunchDateKey) as? Date {
            firstLaunchDate = existing
        } else {
            let now = Date()
            defaults.set(now, forKey: firstLaunchDateKey)
            firstLaunchDate = now
        }
    }

    var expirationDate: Date {
        firstLaunchDate.addingTimeInterval(trialLength)
    }

    var isActive: Bool {
        Date() < expirationDate
    }

    var daysRemaining: Int {
        max(0, Int(ceil(expirationDate.timeIntervalSinceNow / (24 * 60 * 60))))
    }
}
