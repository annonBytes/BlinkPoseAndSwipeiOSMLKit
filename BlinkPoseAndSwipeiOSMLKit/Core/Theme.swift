import UIKit

// The Figma concept is dark-first with an orange accent. Forcing the window
// to dark lets every system semantic color (backgrounds, labels, grouped
// cards) resolve to its dark variant without per-screen overrides.
enum Theme {
    static let accent = UIColor(red: 0.95, green: 0.64, blue: 0.22, alpha: 1)

    static func apply(to window: UIWindow) {
        window.overrideUserInterfaceStyle = .dark
        window.tintColor = accent
    }
}
