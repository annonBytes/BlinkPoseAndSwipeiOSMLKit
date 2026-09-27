import UIKit

// The Figma concept is dark-first with an orange accent. Forcing the window
// to dark lets every system semantic color (backgrounds, labels, grouped
// cards) resolve to its dark variant without per-screen overrides.
enum Theme {
    static let accent = UIColor(red: 0.95, green: 0.64, blue: 0.22, alpha: 1)
    static let accentDeep = UIColor(red: 0.90, green: 0.42, blue: 0.13, alpha: 1)

    /// Near-black canvas with a hint of warmth, so score pages glow against it.
    static let background = UIColor(red: 0.045, green: 0.045, blue: 0.055, alpha: 1)
    static let card = UIColor(red: 0.105, green: 0.105, blue: 0.12, alpha: 1)
    static let hairline = UIColor(white: 1, alpha: 0.08)

    static func apply(to window: UIWindow) {
        window.overrideUserInterfaceStyle = .dark
        window.tintColor = accent
    }

    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

/// A capsule button with the accent gradient, used for primary actions.
final class GradientButton: UIButton {
    private let gradient: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [Theme.accent.cgColor, Theme.accentDeep.cgColor]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        return layer
    }()

    init(title: String) {
        super.init(frame: .zero)
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .black
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var out = $0
            out.font = .systemFont(ofSize: 17, weight: .bold)
            return out
        }
        configuration = config
        layer.insertSublayer(gradient, at: 0)
        clipsToBounds = true
        layer.shadowColor = Theme.accent.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        layer.cornerRadius = bounds.height / 2
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.5 }
    }

    override var isHighlighted: Bool {
        didSet { UIView.animate(withDuration: 0.12) { self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity } }
    }
}

/// The paywall's header: accent glow fading into the app background.
final class PaywallHeaderView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.colors = [
            UIColor(red: 0.98, green: 0.62, blue: 0.20, alpha: 1).cgColor,
            UIColor(red: 0.78, green: 0.30, blue: 0.10, alpha: 1).cgColor,
            Theme.background.cgColor,
        ]
        gradient.locations = [0, 0.5, 1]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)   // vertical, so the fade into the background has no diagonal edge
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradient, at: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}

/// A vertical accent gradient used for progress fills.
final class GradientFillView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let gradient = layer as! CAGradientLayer
        gradient.colors = [Theme.accent.cgColor, Theme.accentDeep.cgColor]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// A soft accent glow at the top of the paywall, fading into the background.
final class PaywallGlowView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        let gradient = layer as! CAGradientLayer
        gradient.colors = [Theme.accent.withAlphaComponent(0.32).cgColor, Theme.accentDeep.withAlphaComponent(0.10).cgColor, Theme.background.withAlphaComponent(0).cgColor]
        gradient.locations = [0, 0.5, 1]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Full-screen paywall backdrop: warm accent at the top fading to the app background.
final class PaywallBackdropView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        let gradient = layer as! CAGradientLayer
        gradient.colors = [
            UIColor(red: 0.84, green: 0.36, blue: 0.10, alpha: 1).cgColor,
            UIColor(red: 0.36, green: 0.14, blue: 0.07, alpha: 1).cgColor,
            Theme.background.cgColor,
        ]
        gradient.locations = [0, 0.32, 0.58]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
