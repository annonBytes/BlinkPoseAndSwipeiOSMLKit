import Foundation

// Turns two per-frame gesture coefficients (0...1, "right" = advance signal,
// "left" = go-back signal) into page-turn actions. Shared by the ARKit and
// Vision detectors so thresholds, hold time, invert, and turn-speed settings
// behave identically no matter which tracking backend produced the numbers.
final class FaceGestureProcessor {
    var onAdvance: (() -> Void)?
    var onGoBack: (() -> Void)?
    var onGestureBegan: (() -> Void)?
    var onGestureEnded: (() -> Void)?

    /// A live reading for the calibration screen: the raw coefficients and the
    /// threshold each side currently has to reach.
    struct Measurement {
        let advance: Float
        let goBack: Float
        let advanceThreshold: Float
        let goBackThreshold: Float
    }
    var onMeasurement: ((Measurement) -> Void)?

    /// How much stronger the intended side must be than the opposite one.
    static let dominanceMargin: Float = 0.25

    private let config: FaceGestureConfig

    private enum ActivationState { case idle, active }
    private enum Action { case advance, goBack }

    private var lastFire = Date.distantPast

    private var advanceInterval = DateInterval()
    private var advanceState: ActivationState = .idle {
        didSet {
            guard oldValue != advanceState else { return }
            switch advanceState {
            case .active:
                advanceInterval.start = Date()
                onGestureBegan?()
            case .idle:
                advanceInterval.end = Date()
                onGestureEnded?()
                if advanceInterval.duration >= holdTime {
                    fire(.advance)
                }
            }
        }
    }

    private var goBackInterval = DateInterval()
    private var goBackState: ActivationState = .idle {
        didSet {
            guard oldValue != goBackState else { return }
            switch goBackState {
            case .active:
                goBackInterval.start = Date()
                onGestureBegan?()
            case .idle:
                goBackInterval.end = Date()
                onGestureEnded?()
                if goBackInterval.duration >= holdTime {
                    fire(.goBack)
                }
            }
        }
    }

    init(config: FaceGestureConfig) {
        self.config = config
    }

    /// Must be called on the main thread.
    func process(advanceCoefficient: Float, goBackCoefficient: Float) {
        let profile = GestureSettings.shared.profile(for: config.name)
        let rightThreshold = threshold(forSensitivity: profile.rightSensitivity)
        let leftThreshold = threshold(forSensitivity: profile.leftSensitivity)
        onMeasurement?(Measurement(advance: advanceCoefficient, goBack: goBackCoefficient,
                                   advanceThreshold: rightThreshold, goBackThreshold: leftThreshold))

        // One side has to clearly dominate. This is what tells a wink from a
        // blink: a natural blink closes both eyes, and even a wink partly
        // closes the other one, so requiring a margin over the opposite side
        // ignores blinks (and one eye lagging a frame behind the other).
        let advanceDominates = advanceCoefficient - goBackCoefficient >= Self.dominanceMargin
        let goBackDominates = goBackCoefficient - advanceCoefficient >= Self.dominanceMargin
        advanceState = advanceCoefficient >= rightThreshold && advanceDominates ? .active : .idle
        goBackState = goBackCoefficient >= leftThreshold && goBackDominates ? .active : .idle
    }

    private func fire(_ action: Action) {
        let settings = GestureSettings.shared
        let now = Date()
        guard now.timeIntervalSince(lastFire) >= settings.turnInterval else { return }
        lastFire = now

        switch (action, settings.invertControls) {
        case (.advance, false), (.goBack, true): onAdvance?()
        case (.goBack, false), (.advance, true): onGoBack?()
        }
    }

    private var holdTime: TimeInterval {
        GestureSettings.shared.profile(for: config.name).holdTime ?? config.holdTimeThreshold
    }

    private func threshold(forSensitivity sensitivity: Float) -> Float {
        min(max(config.activationThreshold * (0.5 + sensitivity), 0.05), 0.98)
    }
}
