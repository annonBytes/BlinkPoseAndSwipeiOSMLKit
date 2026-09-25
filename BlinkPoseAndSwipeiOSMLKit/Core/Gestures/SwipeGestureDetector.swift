import UIKit

final class SwipeGestureDetector: GestureDetector {
    var onAdvance: (() -> Void)?
    var onGoBack: (() -> Void)?
    var onGestureBegan: (() -> Void)?
    var onGestureEnded: (() -> Void)?

    func attach(to hostViewController: UIViewController, pageView: UIView) {
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        leftSwipe.direction = .left
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        rightSwipe.direction = .right
        pageView.addGestureRecognizer(leftSwipe)
        pageView.addGestureRecognizer(rightSwipe)
    }

    func start() {}
    func stop() {}

    @objc private func handleSwipe(_ sender: UISwipeGestureRecognizer) {
        onGestureBegan?()
        switch sender.direction {
        case .left:
            onAdvance?()
        case .right:
            onGoBack?()
        default:
            break
        }
        onGestureEnded?()
    }
}
