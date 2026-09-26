import CoreGraphics
import Foundation

// How large the score is drawn. Remembered across scores and launches so
// players who need bigger notation don't have to zoom every time.
enum ZoomSetting: Equatable {
    case fitPage
    case fitWidth
    /// A multiple of the fit-page size (1.25, 1.5, ...).
    case factor(CGFloat)

    private static let key = "Zoom.setting"

    static var current: ZoomSetting {
        get {
            switch UserDefaults.standard.string(forKey: key) {
            case "width": return .fitWidth
            case .some(let text) where text.hasPrefix("factor:"):
                return Double(text.dropFirst("factor:".count)).map { .factor(CGFloat($0)) } ?? .fitPage
            default: return .fitPage
            }
        }
        set {
            let text: String
            switch newValue {
            case .fitPage: text = "page"
            case .fitWidth: text = "width"
            case .factor(let value): text = "factor:\(value)"
            }
            UserDefaults.standard.set(text, forKey: key)
        }
    }
}
