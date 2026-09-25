import Accelerate
import AVFoundation

// Listens to the microphone and reports, ~43 times a second, a pitch-class
// fingerprint of what it hears, plus a callback whenever a new note is struck.
// Audio is analysed in memory and never recorded or stored.
final class MicrophoneAnalyzer {
    struct Frame {
        let chroma: [Float]     // unit length, 12 pitch classes (C = 0)
        let isAudible: Bool     // above the room's noise floor
        let time: TimeInterval  // ProcessInfo.systemUptime
    }

    /// Called on the main thread.
    var onFrame: ((Frame) -> Void)?
    var onOnset: ((TimeInterval) -> Void)?

    private let engine = AVAudioEngine()
    private let frameSize = 2048
    private let hop = 1024
    private let log2n: vDSP_Length = 11

    private var fft: FFTSetup?
    private var window = [Float]()
    private var samples = [Float]()
    private var previousMagnitudes = [Float]()
    private var fluxHistory = [Float]()
    private var lastOnset: TimeInterval = 0
    private var noiseFloor: Float = 0.02
    private var sampleRate: Double = 44_100

    static func requestPermission(_ completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
        try session.setActive(true)

        fft = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: frameSize, isHalfWindow: false)
        samples = []
        previousMagnitudes = [Float](repeating: 0, count: frameSize / 2)
        fluxHistory = []

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        sampleRate = format.sampleRate
        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(hop), format: format) { [weak self] buffer, _ in
            guard let self, let channel = buffer.floatChannelData?[0] else { return }
            self.samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
            while self.samples.count >= self.frameSize {
                self.analyze(Array(self.samples[0..<self.frameSize]))
                self.samples.removeFirst(self.hop)
            }
        }
        try engine.start()
    }

    func stop() {
        guard engine.isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        if let fft { vDSP_destroy_fftsetup(fft) }
        fft = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    deinit { stop() }

    // MARK: - Analysis (audio thread)

    private func analyze(_ frame: [Float]) {
        guard let fft else { return }
        let time = ProcessInfo.processInfo.systemUptime

        var rms: Float = 0
        vDSP_rmsqv(frame, 1, &rms, vDSP_Length(frameSize))
        noiseFloor = min(noiseFloor * 1.0005, max(rms, 0.0005))
        let audible = rms > max(0.003, noiseFloor * 3)

        // Windowed FFT -> magnitude spectrum.
        var windowed = [Float](repeating: 0, count: frameSize)
        vDSP.multiply(frame, window, result: &windowed)
        let half = frameSize / 2
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)
        real.withUnsafeMutableBufferPointer { realPointer in
            imag.withUnsafeMutableBufferPointer { imagPointer in
                var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
                windowed.withUnsafeBufferPointer { pointer in
                    pointer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(fft, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(half))
            }
        }

        // Pitch-class energy between roughly 100 Hz and 2 kHz.
        let binWidth = Float(sampleRate) / Float(frameSize)
        var chroma = [Float](repeating: 0, count: 12)
        for bin in 1..<half {
            let frequency = Float(bin) * binWidth
            guard frequency >= 100, frequency <= 2000 else { continue }
            let pitch = Int((12 * log2(frequency / 440) + 69).rounded())
            chroma[((pitch % 12) + 12) % 12] += magnitudes[bin]
        }
        chroma = MIDINoteTimeline.normalized(chroma)

        // Onset detection: rise in (log-compressed) spectral energy.
        var flux: Float = 0
        let lowBin = Int(100 / binWidth), highBin = min(half - 1, Int(4000 / binWidth))
        var compressed = previousMagnitudes
        for bin in lowBin...highBin {
            compressed[bin] = log10(1 + 100 * magnitudes[bin] / Float(frameSize))
            flux += max(0, compressed[bin] - previousMagnitudes[bin])
        }
        previousMagnitudes = compressed
        fluxHistory.append(flux)
        if fluxHistory.count > 43 { fluxHistory.removeFirst() }
        let mean = fluxHistory.reduce(0, +) / Float(fluxHistory.count)
        let deviation = sqrt(fluxHistory.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Float(fluxHistory.count))
        let isOnset = audible && flux > mean + 2 * deviation + 0.05 && time - lastOnset > 0.1
        if isOnset { lastOnset = time }

        let result = Frame(chroma: chroma, isAudible: audible, time: time)
        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(result)
            if isOnset { self?.onOnset?(time) }
        }
    }
}
