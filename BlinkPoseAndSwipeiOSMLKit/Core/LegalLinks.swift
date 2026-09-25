import Foundation

// Public URLs for the legal pages (served from the repo's docs/ folder via
// GitHub Pages). Update here if they move to a different host.
enum LegalLinks {
    private static let base = "https://annonbytes.github.io/BlinkPoseAndSwipeiOSMLKit"
    static let privacyPolicy = URL(string: "\(base)/privacy.html")!
    static let termsOfUse = URL(string: "\(base)/terms.html")!
}
