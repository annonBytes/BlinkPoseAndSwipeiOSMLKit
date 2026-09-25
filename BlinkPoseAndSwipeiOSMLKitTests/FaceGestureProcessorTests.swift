import XCTest
@testable import BlinkPoseAndSwipeiOSMLKit

final class FaceGestureProcessorTests: XCTestCase {

    private let settings = GestureSettings.shared
    private var advances = 0
    private var goBacks = 0
    private var processor: FaceGestureProcessor!

    override func setUp() {
        super.setUp()
        settings.resetProfile(for: FaceGestureConfig.wink.name)
        settings.invertControls = false
        settings.turnInterval = 0.05
        advances = 0
        goBacks = 0
        processor = FaceGestureProcessor(config: .wink)
        processor.onAdvance = { [unowned self] in advances += 1 }
        processor.onGoBack = { [unowned self] in goBacks += 1 }
    }

    override func tearDown() {
        settings.resetProfile(for: FaceGestureConfig.wink.name)
        settings.invertControls = false
        settings.turnInterval = 0.3
        super.tearDown()
    }

    /// Holds a gesture for `hold` seconds, then releases it.
    private func gesture(advance: Float, goBack: Float, hold: TimeInterval = 0.2) {
        processor.process(advanceCoefficient: advance, goBackCoefficient: goBack)
        Thread.sleep(forTimeInterval: hold)
        processor.process(advanceCoefficient: 0, goBackCoefficient: 0)
    }

    func testWinkAdvancesOrGoesBack() {
        gesture(advance: 1, goBack: 0)
        XCTAssertEqual(advances, 1)
        Thread.sleep(forTimeInterval: 0.1)
        gesture(advance: 0, goBack: 1)
        XCTAssertEqual(goBacks, 1)
    }

    func testBothEyesClosedIsABlinkAndIsIgnored() {
        gesture(advance: 1, goBack: 1)
        XCTAssertEqual(advances + goBacks, 0)
    }

    func testEyeLaggingBehindInABlinkIsIgnored() {
        // One eye a little ahead of the other, as in a natural blink.
        gesture(advance: 0.95, goBack: 0.8)
        XCTAssertEqual(advances + goBacks, 0)
    }

    func testTooShortAGestureIsIgnored() {
        gesture(advance: 1, goBack: 0, hold: 0.02)
        XCTAssertEqual(advances, 0)
    }

    func testBelowThresholdDoesNothing() {
        gesture(advance: 0.3, goBack: 0)
        XCTAssertEqual(advances, 0)
    }

    func testInvertSwapsDirections() {
        settings.invertControls = true
        gesture(advance: 1, goBack: 0)
        XCTAssertEqual(goBacks, 1)
        XCTAssertEqual(advances, 0)
    }

    func testTurnIntervalLimitsRepeatTurns() {
        settings.turnInterval = 1.0
        gesture(advance: 1, goBack: 0)
        gesture(advance: 1, goBack: 0)
        XCTAssertEqual(advances, 1)
    }

    func testSensitivityChangesThreshold() {
        // Higher sensitivity value = a stronger gesture is required.
        var profile = settings.profile(for: FaceGestureConfig.wink.name)
        profile.rightSensitivity = 1.0
        settings.setProfile(profile, for: FaceGestureConfig.wink.name)
        gesture(advance: 0.85, goBack: 0)
        XCTAssertEqual(advances, 0)

        profile.rightSensitivity = 0.1
        settings.setProfile(profile, for: FaceGestureConfig.wink.name)
        gesture(advance: 0.85, goBack: 0)
        XCTAssertEqual(advances, 1)
    }

    func testMeasurementReportsLiveValues() {
        var last: FaceGestureProcessor.Measurement?
        processor.onMeasurement = { last = $0 }
        processor.process(advanceCoefficient: 0.4, goBackCoefficient: 0.1)
        XCTAssertEqual(last?.advance, 0.4)
        XCTAssertEqual(last?.goBack, 0.1)
    }
}
