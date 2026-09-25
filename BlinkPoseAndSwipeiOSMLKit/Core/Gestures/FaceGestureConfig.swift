import ARKit
import Vision

struct FaceGestureConfig {
    let name: String
    // ARKit backend (TrueDepth devices): blend shapes / anchor transform.
    let advanceSignal: (ARFaceAnchor) -> Float
    let goBackSignal: (ARFaceAnchor) -> Float
    // Vision backend (any front camera): 2D face landmarks, less precise.
    let visionAdvanceSignal: (VNFaceObservation) -> Float
    let visionGoBackSignal: (VNFaceObservation) -> Float
    let activationThreshold: Float
    let holdTimeThreshold: TimeInterval

    // Left eye blink -> advance, right eye blink -> go back (matches the
    // original hand-tuned WinkIt thresholds).
    static let wink = FaceGestureConfig(
        name: "Wink",
        advanceSignal: { $0.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0 },
        goBackSignal: { $0.blendShapes[.eyeBlinkRight]?.floatValue ?? 0 },
        visionAdvanceSignal: { VisionFaceMetrics.eyeClosure($0, subjectLeft: true) },
        visionGoBackSignal: { VisionFaceMetrics.eyeClosure($0, subjectLeft: false) },
        activationThreshold: 0.80,
        holdTimeThreshold: 0.1
    )

    static let mouthMove = FaceGestureConfig(
        name: "Mouth Move",
        advanceSignal: { $0.blendShapes[.mouthLeft]?.floatValue ?? 0 },
        goBackSignal: { $0.blendShapes[.mouthRight]?.floatValue ?? 0 },
        visionAdvanceSignal: { max(0, VisionFaceMetrics.mouthShift($0)) },
        visionGoBackSignal: { max(0, -VisionFaceMetrics.mouthShift($0)) },
        activationThreshold: 0.5,
        holdTimeThreshold: 0.15
    )

    // Tilt right -> advance, tilt left -> go back.
    static let headTilt = FaceGestureConfig(
        name: "Head Tilt",
        advanceSignal: { anchor in
            let roll = FaceGestureConfig.rollDegrees(for: anchor)
            return roll > 0 ? Float(min(1, roll / 20)) : 0
        },
        goBackSignal: { anchor in
            let roll = FaceGestureConfig.rollDegrees(for: anchor)
            return roll < 0 ? Float(min(1, -roll / 20)) : 0
        },
        visionAdvanceSignal: { max(0, VisionFaceMetrics.tilt($0)) },
        visionGoBackSignal: { max(0, -VisionFaceMetrics.tilt($0)) },
        activationThreshold: 0.8,
        holdTimeThreshold: 0.15
    )

    private static func rollDegrees(for anchor: ARFaceAnchor) -> Double {
        let t = anchor.transform
        let roll = atan2(Double(t.columns.0.y), Double(t.columns.1.y))
        return roll * 180 / .pi
    }
}
