import ARKit
import UIKit

// Drives wink, head-tilt, and mouth-move modalities off a single ARKit face
// session — no rendering view needed, just the raw ARSession + blend shapes.
// Requires a TrueDepth camera; VisionFaceGestureDetector covers other devices.
final class ARFaceGestureDetector: NSObject, GestureDetector, FaceMeasuring, ARSessionDelegate {
    var onAdvance: (() -> Void)? { didSet { processor.onAdvance = onAdvance } }
    var onGoBack: (() -> Void)? { didSet { processor.onGoBack = onGoBack } }
    var onGestureBegan: (() -> Void)? { didSet { processor.onGestureBegan = onGestureBegan } }
    var onGestureEnded: (() -> Void)? { didSet { processor.onGestureEnded = onGestureEnded } }
    var onMeasurement: ((FaceGestureProcessor.Measurement) -> Void)? { didSet { processor.onMeasurement = onMeasurement } }

    private let config: FaceGestureConfig
    private let processor: FaceGestureProcessor
    private let session = ARSession()

    init(config: FaceGestureConfig) {
        self.config = config
        self.processor = FaceGestureProcessor(config: config)
        super.init()
        session.delegate = self
    }

    func attach(to hostViewController: UIViewController, pageView: UIView) {}

    func start() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        session.run(ARFaceTrackingConfiguration())
    }

    func stop() {
        session.pause()
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }

        let advanceCoefficient = config.advanceSignal(faceAnchor)
        let goBackCoefficient = config.goBackSignal(faceAnchor)

        DispatchQueue.main.async { [weak self] in
            self?.processor.process(advanceCoefficient: advanceCoefficient, goBackCoefficient: goBackCoefficient)
        }
    }
}
