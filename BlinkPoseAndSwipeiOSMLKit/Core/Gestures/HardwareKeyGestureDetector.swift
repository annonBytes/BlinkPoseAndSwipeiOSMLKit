import UIKit

// Handles Bluetooth page-turner pedals (AirTurn, PageFlip, iRig BlueBoard,
// etc.) — these all pair as plain Bluetooth HID keyboards and send arrow-key
// or spacebar presses, no custom BLE/MFi protocol required.
final class HardwareKeyGestureDetector: GestureDetector, HardwareKeyHandling {
    var onAdvance: (() -> Void)?
    var onGoBack: (() -> Void)?
    var onGestureBegan: (() -> Void)?
    var onGestureEnded: (() -> Void)?

    func attach(to hostViewController: UIViewController, pageView: UIView) {}
    func start() {}
    func stop() {}

    func handleKeyPress(_ key: UIKey) {
        switch key.keyCode {
        case .keyboardDownArrow, .keyboardRightArrow, .keyboardSpacebar:
            onGestureBegan?()
            onAdvance?()
            onGestureEnded?()
        case .keyboardUpArrow, .keyboardLeftArrow:
            onGestureBegan?()
            onGoBack?()
            onGestureEnded?()
        default:
            break
        }
    }
}
