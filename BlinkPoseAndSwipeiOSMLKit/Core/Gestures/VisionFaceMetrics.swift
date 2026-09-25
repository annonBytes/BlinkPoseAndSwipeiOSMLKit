import Vision

// Converts Vision's 2D face landmarks into the same 0...1-ish "how strongly
// is this gesture happening" coefficients ARKit blend shapes provide.
//
// All of this assumes the capture buffer is mirrored selfie-style (as
// VisionFaceGestureDetector configures it), so image-right is the subject's
// left. The scale constants are first-pass estimates that need calibration on
// a real device — Vision is inherently less precise than ARKit's depth data.
enum VisionFaceMetrics {

    /// 0 = eye fully open, 1 = fully closed.
    static func eyeClosure(_ face: VNFaceObservation, subjectLeft: Bool) -> Float {
        guard let landmarks = face.landmarks else { return 0 }
        // Mirrored buffer: the subject's left eye is Vision's image-right eye.
        guard let eye = subjectLeft ? landmarks.rightEye : landmarks.leftEye else { return 0 }

        let points = eye.normalizedPoints
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max(),
              maxX > minX else { return 0 }

        let openness = (maxY - minY) / (maxX - minX)
        return clamp01(Float((0.30 - openness) / 0.18))
    }

    /// Positive = mouth shifted toward the subject's left, negative = right.
    static func mouthShift(_ face: VNFaceObservation) -> Float {
        guard let landmarks = face.landmarks,
              let lips = landmarks.outerLips?.normalizedPoints, !lips.isEmpty,
              let leftEye = landmarks.leftEye?.normalizedPoints, !leftEye.isEmpty,
              let rightEye = landmarks.rightEye?.normalizedPoints, !rightEye.isEmpty else { return 0 }

        let lipsCenter = lips.map(\.x).reduce(0, +) / CGFloat(lips.count)
        let eyeCenter = (leftEye.map(\.x).reduce(0, +) / CGFloat(leftEye.count)
            + rightEye.map(\.x).reduce(0, +) / CGFloat(rightEye.count)) / 2

        return Float((lipsCenter - eyeCenter) / 0.08)
    }

    /// Positive = head tilted toward the subject's right, negative = left.
    static func tilt(_ face: VNFaceObservation) -> Float {
        guard let roll = face.roll?.doubleValue else { return 0 }
        // Vision roll is counterclockwise-positive in image space; tilting
        // toward the subject's right looks clockwise in a mirrored frame.
        return Float(-roll * 180 / .pi / 20)
    }

    private static func clamp01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
