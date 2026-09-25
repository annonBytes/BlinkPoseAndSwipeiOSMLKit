import UIKit

// Small on-screen indicator that pulses green while a gesture is being
// recognized, so the player gets confirmation the camera/pedal/tap is live.
final class GestureFeedbackView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemGray4
        alpha = 0.85
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }

    func showActive() {
        UIView.animate(withDuration: 0.15) {
            self.backgroundColor = .systemGreen
            self.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }
    }

    func showIdle() {
        UIView.animate(withDuration: 0.25) {
            self.backgroundColor = .systemGray4
            self.transform = .identity
        }
    }
}
