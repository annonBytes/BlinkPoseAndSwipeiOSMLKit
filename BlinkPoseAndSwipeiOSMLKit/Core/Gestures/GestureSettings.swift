import Foundation

// User-tunable gesture behavior, persisted in UserDefaults and read live by
// ARFaceGestureDetector so slider changes apply without restarting a session.
// Sensitivity is 0...1 with 0.5 = the config's original hand-tuned threshold.
struct GestureProfile: Equatable {
    /// 0...1, higher = a stronger gesture is required (0.5 = the original tuning).
    var leftSensitivity: Float
    var rightSensitivity: Float
    /// How long the gesture must be held; nil = the gesture's built-in default.
    var holdTime: TimeInterval?
}

final class GestureSettings {
    static let shared = GestureSettings()

    private let defaults = UserDefaults.standard

    var invertControls: Bool {
        get { defaults.bool(forKey: "GestureSettings.invert") }
        set { defaults.set(newValue, forKey: "GestureSettings.invert") }
    }

    /// Per-gesture tuning: people wink, tilt, and move their mouths very
    /// differently, so each face gesture keeps its own profile.
    func profile(for gesture: String) -> GestureProfile {
        GestureProfile(
            leftSensitivity: value(forKey: "GestureSettings.\(gesture).left", default: 0.5),
            rightSensitivity: value(forKey: "GestureSettings.\(gesture).right", default: 0.5),
            holdTime: defaults.object(forKey: "GestureSettings.\(gesture).hold") == nil
                ? nil : TimeInterval(defaults.float(forKey: "GestureSettings.\(gesture).hold")))
    }

    func setProfile(_ profile: GestureProfile, for gesture: String) {
        defaults.set(profile.leftSensitivity, forKey: "GestureSettings.\(gesture).left")
        defaults.set(profile.rightSensitivity, forKey: "GestureSettings.\(gesture).right")
        if let hold = profile.holdTime {
            defaults.set(Float(hold), forKey: "GestureSettings.\(gesture).hold")
        } else {
            defaults.removeObject(forKey: "GestureSettings.\(gesture).hold")
        }
    }

    func resetProfile(for gesture: String) {
        for suffix in ["left", "right", "hold"] {
            defaults.removeObject(forKey: "GestureSettings.\(gesture).\(suffix)")
        }
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
