import ARKit

// Unifies the page-turn modalities behind one identifier so a Score can
// persist which one it should open with, and the library UI can offer all
// of them from a single list.
enum ModalityKind: String, Codable, CaseIterable {
    case tap
    case swipe
    case hardwareKey
    case wink
    case headTilt
    case mouthMove

    var displayName: String {
        switch self {
        case .tap: return "Tap".localized
        case .swipe: return "Swipe".localized
        case .hardwareKey: return "Hardware Pedal".localized
        case .wink: return "Wink".localized
        case .headTilt: return "Head Tilt".localized
        case .mouthMove: return "Mouth Move".localized
        }
    }

    func makeDetector() -> GestureDetector {
        switch self {
        case .tap: return TapGestureDetector()
        case .swipe: return SwipeGestureDetector()
        case .hardwareKey: return HardwareKeyGestureDetector()
        case .wink: return Self.faceDetector(.wink)
        case .headTilt: return Self.faceDetector(.headTilt)
        case .mouthMove: return Self.faceDetector(.mouthMove)
        }
    }

    // ARKit (TrueDepth) when available; otherwise — or when the user forces
    // it in Settings — the less accurate Vision-based fallback.
    static var usesAdvancedFaceTracking: Bool {
        ARFaceTrackingConfiguration.isSupported && !GestureSettings.shared.forceFallbackTracking
    }

    private static func faceDetector(_ config: FaceGestureConfig) -> GestureDetector {
        usesAdvancedFaceTracking ? ARFaceGestureDetector(config: config) : VisionFaceGestureDetector(config: config)
    }
}
