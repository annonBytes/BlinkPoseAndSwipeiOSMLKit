import XCTest
@testable import BlinkPoseAndSwipeiOSMLKit

final class TrialAndEntitlementTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        let name = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testFreshInstallGetsFullSevenDayTrial() {
        let trial = TrialManager(defaults: makeDefaults())
        XCTAssertTrue(trial.isActive)
        XCTAssertEqual(trial.daysRemaining, 7)
    }

    func testTrialPersistsFirstLaunchDate() {
        let defaults = makeDefaults()
        let first = TrialManager(defaults: defaults)
        let second = TrialManager(defaults: defaults)
        XCTAssertEqual(first.firstLaunchDate, second.firstLaunchDate)
    }

    func testTrialCountsDownAndExpires() {
        let defaults = makeDefaults()
        defaults.set(Date().addingTimeInterval(-3 * 86_400), forKey: "TrialManager.firstLaunchDate")
        let midway = TrialManager(defaults: defaults)
        XCTAssertTrue(midway.isActive)
        XCTAssertEqual(midway.daysRemaining, 4)

        defaults.set(Date().addingTimeInterval(-8 * 86_400), forKey: "TrialManager.firstLaunchDate")
        let expired = TrialManager(defaults: defaults)
        XCTAssertFalse(expired.isActive)
        XCTAssertEqual(expired.daysRemaining, 0)
    }

    func testAutoTurnIsNeverIncludedInTrial() {
        // Performance auto-turn is subscription-only, even while the trial is active.
        XCTAssertFalse(SubscriptionStore.shared.isSubscribed)
        XCTAssertFalse(EntitlementManager.hasPerformanceAccess)
    }
}
