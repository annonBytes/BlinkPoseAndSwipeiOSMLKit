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

// Face detectors can report live coefficients so a calibration screen can show
// the user what the camera is seeing.
protocol FaceMeasuring: AnyObject {
    var onMeasurement: ((FaceGestureProcessor.Measurement) -> Void)? { get set }
}
