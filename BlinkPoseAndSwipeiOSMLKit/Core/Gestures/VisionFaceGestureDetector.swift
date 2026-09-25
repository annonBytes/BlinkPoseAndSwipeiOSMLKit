import AVFoundation
import UIKit
import Vision

// Fallback for devices without a TrueDepth camera (or when the user forces
// it in Settings): front-camera frames run through Vision face landmarks.
// Less accurate than ARFaceGestureDetector, but works on any device.
final class VisionFaceGestureDetector: NSObject, GestureDetector, FaceMeasuring, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onAdvance: (() -> Void)? { didSet { processor.onAdvance = onAdvance } }
    var onGoBack: (() -> Void)? { didSet { processor.onGoBack = onGoBack } }
    var onGestureBegan: (() -> Void)? { didSet { processor.onGestureBegan = onGestureBegan } }
    var onGestureEnded: (() -> Void)? { didSet { processor.onGestureEnded = onGestureEnded } }
    var onMeasurement: ((FaceGestureProcessor.Measurement) -> Void)? { didSet { processor.onMeasurement = onMeasurement } }

    private let config: FaceGestureConfig
    private let processor: FaceGestureProcessor

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "VisionFaceGestureDetector.session")
    private let frameQueue = DispatchQueue(label: "VisionFaceGestureDetector.frames")
    private var isConfigured = false

    init(config: FaceGestureConfig) {
        self.config = config
        self.processor = FaceGestureProcessor(config: config)
        super.init()
    }

    func attach(to hostViewController: UIViewController, pageView: UIView) {}

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { self?.startSession() }
            }
        default:
            break
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured { self.configureSession() }
            if self.isConfigured, !self.session.isRunning { self.session.startRunning() }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: frameQueue)
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 90
            } else {
                connection.videoOrientation = .portrait
            }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }

        isConfigured = true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        guard (try? handler.perform([request])) != nil,
              let face = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) else { return }

        let advance = config.visionAdvanceSignal(face)
        let goBack = config.visionGoBackSignal(face)

        DispatchQueue.main.async { [weak self] in
            self?.processor.process(advanceCoefficient: advance, goBackCoefficient: goBack)
        }
    }
}
