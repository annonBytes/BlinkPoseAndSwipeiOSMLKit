import UIKit

// On-screen badge showing which page-turn modality is active. It lights up
// green and pulses while a gesture is being recognized, so the player gets
// confirmation the camera/pedal/tap is live.
final class GestureFeedbackView: UIView {
    private let iconView = UIImageView()
    private let ring = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.systemGray4.withAlphaComponent(0.85)
        isUserInteractionEnabled = false

        ring.layer.borderColor = UIColor.systemGreen.cgColor
        ring.layer.borderWidth = 2
        ring.alpha = 0
        ring.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ring)

        iconView.tintColor = .label
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        NSLayoutConstraint.activate([
            ring.topAnchor.constraint(equalTo: topAnchor), ring.bottomAnchor.constraint(equalTo: bottomAnchor),
            ring.leadingAnchor.constraint(equalTo: leadingAnchor), ring.trailingAnchor.constraint(equalTo: trailingAnchor),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.6),
            iconView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.6),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        ring.layer.cornerRadius = bounds.width / 2
    }

    func setModality(_ kind: ModalityKind) {
        iconView.image = UIImage(named: "modality-\(kind.rawValue)")
        isAccessibilityElement = true
        accessibilityLabel = String.localizedStringWithFormat("Page-turn method: %@".localized, kind.displayName)
    }

    func showActive() {
        UIView.animate(withDuration: 0.15) {
            self.backgroundColor = .systemGreen
            self.iconView.tintColor = .white
            self.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
        }
        ring.transform = .identity
        ring.alpha = 0.9
        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseOut]) {
            self.ring.transform = CGAffineTransform(scaleX: 1.8, y: 1.8)
            self.ring.alpha = 0
        }
    }

    func showIdle() {
        // Brief hold so instant gestures (tap, swipe, pedal) still register visibly.
        UIView.animate(withDuration: 0.25, delay: 0.3, options: [.beginFromCurrentState]) {
            self.backgroundColor = UIColor.systemGray4.withAlphaComponent(0.85)
            self.iconView.tintColor = .label
            self.transform = .identity
        }
    }
}
