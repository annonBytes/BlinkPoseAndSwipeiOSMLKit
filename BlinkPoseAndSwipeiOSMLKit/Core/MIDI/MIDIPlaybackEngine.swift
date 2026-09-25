import AVFoundation

// Plays a MIDI file through a sampler and exposes its position in beats. Beats
// (not seconds) are what page marks are stored in, so the same marks stay
// correct if the file's tempo track changes or playback rate is adjusted.
final class MIDIPlaybackEngine {
    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private let sequencer: AVAudioSequencer

    let lengthInBeats: Double

    private(set) var isPlaying = false

    var currentBeat: Double {
        sequencer.currentPositionInBeats
    }

    var hasFinished: Bool {
        currentBeat >= lengthInBeats
    }

    /// When silent the sequencer still runs as a clock but makes no sound, and
    /// the audio session mixes with other audio instead of taking it over.
    private let silent: Bool

    init(midiURL: URL, silent: Bool = false) throws {
        self.silent = silent
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = silent ? 0 : 1

        sequencer = AVAudioSequencer(audioEngine: engine)
        try sequencer.load(from: midiURL, options: [])
        for track in sequencer.tracks {
            track.destinationAudioUnit = sampler
        }
        lengthInBeats = sequencer.tracks.map(\.lengthInBeats).max() ?? 0
    }

    func start() throws {
        try? AVAudioSession.sharedInstance().setCategory(silent ? .ambient : .playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        if !engine.isRunning { try engine.start() }
        sequencer.currentPositionInBeats = 0
        sequencer.prepareToPlay()
        try sequencer.start()
        isPlaying = true
    }

    func stop() {
        guard isPlaying else { return }
        sequencer.stop()
        engine.stop()
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    deinit {
        stop()
    }
}
