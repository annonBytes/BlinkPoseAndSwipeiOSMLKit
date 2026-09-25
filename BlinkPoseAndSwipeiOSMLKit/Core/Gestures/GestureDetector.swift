import UIKit

protocol GestureDetector: AnyObject {
    var onAdvance: (() -> Void)? { get set }
    var onGoBack: (() -> Void)? { get set }
    var onGestureBegan: (() -> Void)? { get set }
    var onGestureEnded: (() -> Void)? { get set }

    func attach(to hostViewController: UIViewController, pageView: UIView)
    func start()
    func stop()
}

protocol HardwareKeyHandling: AnyObject {
    func handleKeyPress(_ key: UIKey)
}
