import Foundation

// English text doubles as the lookup key, so a missing translation falls
// back to readable English instead of a raw key.
extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    func localized(_ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), locale: Locale.current, arguments: arguments)
    }
}
