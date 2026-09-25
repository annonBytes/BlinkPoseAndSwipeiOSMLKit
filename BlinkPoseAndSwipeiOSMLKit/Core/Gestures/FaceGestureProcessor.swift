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
                if advanceInterval.duration >= config.holdTimeThreshold {
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
                if goBackInterval.duration >= config.holdTimeThreshold {
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
        let rightThreshold = threshold(forSensitivity: GestureSettings.shared.rightSensitivity)
        let leftThreshold = threshold(forSensitivity: GestureSettings.shared.leftSensitivity)

        if advanceCoefficient >= rightThreshold && goBackCoefficient >= leftThreshold {
            return
        }
        advanceState = advanceCoefficient >= rightThreshold ? .active : .idle
        goBackState = goBackCoefficient >= leftThreshold ? .active : .idle
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

    private func threshold(forSensitivity sensitivity: Float) -> Float {
        min(max(config.activationThreshold * (0.5 + sensitivity), 0.05), 0.98)
    }
}
