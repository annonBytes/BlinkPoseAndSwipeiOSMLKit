import UIKit

final class TapGestureDetector: GestureDetector {
    var onAdvance: (() -> Void)?
    var onGoBack: (() -> Void)?
    var onGestureBegan: (() -> Void)?
    var onGestureEnded: (() -> Void)?

    private let leftZone = UIView()
    private let rightZone = UIView()

    func attach(to hostViewController: UIViewController, pageView: UIView) {
        let hostView = hostViewController.view!

        for zone in [leftZone, rightZone] {
            zone.backgroundColor = .clear
            zone.translatesAutoresizingMaskIntoConstraints = false
            hostView.addSubview(zone)
        }

        NSLayoutConstraint.activate([
            leftZone.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            leftZone.topAnchor.constraint(equalTo: hostView.topAnchor),
            leftZone.bottomAnchor.constraint(equalTo: hostView.bottomAnchor),
            leftZone.widthAnchor.constraint(equalToConstant: 100),

            rightZone.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            rightZone.topAnchor.constraint(equalTo: hostView.topAnchor),
            rightZone.bottomAnchor.constraint(equalTo: hostView.bottomAnchor),
            rightZone.widthAnchor.constraint(equalToConstant: 100),
        ])

        leftZone.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(leftTapped)))
        rightZone.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(rightTapped)))
    }

    func start() {}
    func stop() {}

    @objc private func leftTapped() {
        onGestureBegan?()
        onGoBack?()
        onGestureEnded?()
    }

    @objc private func rightTapped() {
        onGestureBegan?()
        onAdvance?()
        onGestureEnded?()
    }
}
