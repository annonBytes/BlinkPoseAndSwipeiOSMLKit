import Foundation

enum FollowMode: String, CaseIterable {
    case notes, tempo

    private static let key = "Follow.mode"

    static var current: FollowMode {
        get { UserDefaults.standard.string(forKey: key).flatMap(FollowMode.init(rawValue:)) ?? .notes }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    var title: String {
        switch self {
        case .notes: return "Follow the Notes".localized
        case .tempo: return "Follow My Tempo".localized
        }
    }

    var explanation: String {
        switch self {
        case .notes: return "Matches what you play to the MIDI file. Best for pieces you play accurately.".localized
        case .tempo: return "Follows how fast you play. More forgiving of wrong notes and busy rooms.".localized
        }
    }
}

// Turns pages by listening to the player, using the MIDI file and the page
// turns recorded against it. Pure position logic lives in NoteFollower and
// TempoFollower; this class connects them to the microphone and the viewer.
final class ScoreFollowController {
    enum State { case idle, listening, following }

    var onNavigate: ((Int) -> Void)?
    var onStateChanged: ((State) -> Void)?

    private(set) var state: State = .idle {
        didSet { if oldValue != state { onStateChanged?(state) } }
    }

    private let currentPage: () -> Int
    private let analyzer = MicrophoneAnalyzer()
    private var marks: [PageMark] = []
    private var noteFollower: NoteFollower?
    private var tempoFollower: TempoFollower?
    private var lastFrameTime: TimeInterval?
    private var lastAudible: TimeInterval = 0
    private var behindFrames = 0

    var isActive: Bool { state != .idle }

    init(currentPage: @escaping () -> Int) {
        self.currentPage = currentPage
    }

    enum StartError: LocalizedError {
        case unreadableMIDI, microphoneDenied
        var errorDescription: String? {
            switch self {
            case .unreadableMIDI: return "This MIDI file has no notes to follow.".localized
            case .microphoneDenied: return "PageTurn needs microphone access to follow your playing. You can allow it in Settings › PageTurn.".localized
            }
        }
    }

    func start(midiURL: URL, marks: [PageMark], mode: FollowMode, completion: @escaping (Error?) -> Void) {
        guard let timeline = MIDINoteTimeline(url: midiURL) else { return completion(StartError.unreadableMIDI) }
        MicrophoneAnalyzer.requestPermission { [weak self] granted in
            guard let self else { return }
            guard granted else { return completion(StartError.microphoneDenied) }
            do {
                self.begin(timeline: timeline, marks: marks, mode: mode)
                try self.analyzer.start()
                completion(nil)
            } catch {
                self.stop()
                completion(error)
            }
        }
    }

    func stop() {
        analyzer.stop()
        analyzer.onFrame = nil
        analyzer.onOnset = nil
        noteFollower = nil
        tempoFollower = nil
        state = .idle
    }

    private func begin(timeline: MIDINoteTimeline, marks: [PageMark], mode: FollowMode) {
        self.marks = marks.sorted { $0.beat < $1.beat }
        lastFrameTime = nil
        lastAudible = 0
        behindFrames = 0
        noteFollower = mode == .notes ? NoteFollower(timeline: timeline) : nil
        tempoFollower = mode == .tempo ? TempoFollower(timeline: timeline) : nil
        state = .listening

        analyzer.onFrame = { [weak self] frame in self?.handle(frame) }
        analyzer.onOnset = { [weak self] time in self?.tempoFollower?.noteOnset(at: time) }
    }

    private func handle(_ frame: MicrophoneAnalyzer.Frame) {
        let dt = lastFrameTime.map { frame.time - $0 } ?? 0
        lastFrameTime = frame.time
        if frame.isAudible { lastAudible = frame.time }
        state = frame.time - lastAudible < 2 ? .following : .listening

        let position: Double
        if let noteFollower {
            noteFollower.feed(chroma: frame.chroma, isAudible: frame.isAudible, dt: dt)
            position = noteFollower.position
        } else if let tempoFollower {
            tempoFollower.tick(at: frame.time)
            position = tempoFollower.position
        } else {
            return
        }
        updatePage(for: position)
    }

    private func updatePage(for position: Double) {
        let target = marks.last { $0.beat <= position }?.page ?? 0
        let current = currentPage()
        if target > current {
            behindFrames = 0
            onNavigate?(target)
        } else if target < current {
            // Going back (a repeat) needs to look deliberate, not a one-frame glitch.
            behindFrames += 1
            if behindFrames > 40 {
                behindFrames = 0
                onNavigate?(target)
            }
        } else {
            behindFrames = 0
        }
    }
}
