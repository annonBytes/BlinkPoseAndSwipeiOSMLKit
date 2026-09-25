import Foundation

// User-tunable gesture behavior, persisted in UserDefaults and read live by
// ARFaceGestureDetector so slider changes apply without restarting a session.
// Sensitivity is 0...1 with 0.5 = the config's original hand-tuned threshold.
final class GestureSettings {
    static let shared = GestureSettings()

    private let defaults = UserDefaults.standard

    var invertControls: Bool {
        get { defaults.bool(forKey: "GestureSettings.invert") }
        set { defaults.set(newValue, forKey: "GestureSettings.invert") }
    }

    var leftSensitivity: Float {
        get { value(forKey: "GestureSettings.left", default: 0.5) }
        set { defaults.set(newValue, forKey: "GestureSettings.left") }
    }

    var rightSensitivity: Float {
        get { value(forKey: "GestureSettings.right", default: 0.5) }
        set { defaults.set(newValue, forKey: "GestureSettings.right") }
    }

    /// Minimum seconds between page turns when gesturing continuously.
    var turnInterval: TimeInterval {
        get { TimeInterval(value(forKey: "GestureSettings.interval", default: 0.3)) }
        set { defaults.set(Float(newValue), forKey: "GestureSettings.interval") }
    }

    /// Use the Vision fallback even on devices that support ARKit face tracking.
    var forceFallbackTracking: Bool {
        get { defaults.bool(forKey: "GestureSettings.forceFallback") }
        set { defaults.set(newValue, forKey: "GestureSettings.forceFallback") }
    }

    private func value(forKey key: String, default fallback: Float) -> Float {
        defaults.object(forKey: key) == nil ? fallback : defaults.float(forKey: key)
    }
}
