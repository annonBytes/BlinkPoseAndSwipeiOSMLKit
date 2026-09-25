import AVFoundation

// Sample-accurate click track: click sounds are synthesized in-memory (no
// bundled audio asset needed) and scheduled directly on the AVAudioEngine
// render timeline via chained AVAudioTime-based scheduling, rather than a
// wall-clock Timer — this is what keeps the beat tight instead of jittery.
final class MetronomeEngine {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let format: AVAudioFormat

    private let accentBuffer: AVAudioPCMBuffer
    private let clickBuffer: AVAudioPCMBuffer

    private(set) var isPlaying = false

    var bpm: Double = 100 {
        didSet { bpm = min(max(bpm, 30), 260) }
    }

    var beatsPerMeasure: Int = 4

    /// Called on the main thread for every beat that plays, with its index
    /// within the measure (0 = downbeat/accent).
    var onBeat: ((Int) -> Void)?

    private var currentBeat = 0
    private var nextBeatSampleTime: AVAudioFramePosition = 0

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        accentBuffer = Self.makeClickBuffer(format: format, frequency: 1500, durationSeconds: 0.03, amplitude: 0.9)
        clickBuffer = Self.makeClickBuffer(format: format, frequency: 900, durationSeconds: 0.02, amplitude: 0.5)

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
    }

    func start() {
        guard !isPlaying else { return }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        guard (try? engine.start()) != nil else { return }

        isPlaying = true
        currentBeat = 0
        nextBeatSampleTime = AVAudioFramePosition(format.sampleRate * 0.1)
        playerNode.play()
        scheduleNextBeat()
    }

    func stop() {
        isPlaying = false
        playerNode.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func scheduleNextBeat() {
        guard isPlaying else { return }

        let beatIndex = currentBeat
        let buffer = beatIndex == 0 ? accentBuffer : clickBuffer
        let time = AVAudioTime(sampleTime: nextBeatSampleTime, atRate: format.sampleRate)

        let interval = 60.0 / bpm
        nextBeatSampleTime += AVAudioFramePosition(interval * format.sampleRate)
        currentBeat = (currentBeat + 1) % max(beatsPerMeasure, 1)

        playerNode.scheduleBuffer(buffer, at: time, options: []) { [weak self] in
            self?.scheduleNextBeat()
            DispatchQueue.main.async {
                self?.onBeat?(beatIndex)
            }
        }
    }

    private static func makeClickBuffer(format: AVAudioFormat, frequency: Double, durationSeconds: Double, amplitude: Float) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(format.sampleRate * durationSeconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let channel = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / format.sampleRate
            let envelope = Float(1.0 - t / durationSeconds)
            channel[frame] = Float(sin(2.0 * .pi * frequency * t)) * amplitude * envelope
        }
        return buffer
    }
}
