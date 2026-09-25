import PDFKit

// Drives page turning from a MIDI backing track, in two modes:
//  - recording: the user plays along and turns pages themselves; each manual
//    turn is stamped with the current beat.
//  - playing: as the track passes each recorded beat, the page is turned
//    automatically.
final class MIDIPageTurnController {
    enum Mode { case idle, playing, recording }

    private(set) var mode: Mode = .idle {
        didSet { if oldValue != mode { onModeChanged?(mode) } }
    }

    var onModeChanged: ((Mode) -> Void)?
    var onRecordingFinished: (([PageMark]) -> Void)?

    private let pdfView: PDFView
    private var engine: MIDIPlaybackEngine?
    private var timer: Timer?
    private var marks: [PageMark] = []
    private var recorded: [PageMark] = []

    init(pdfView: PDFView) {
        self.pdfView = pdfView
    }

    deinit {
        timer?.invalidate()
    }

    func startPlaying(midiURL: URL, marks: [PageMark], silent: Bool = false) throws {
        stop()
        let engine = try MIDIPlaybackEngine(midiURL: midiURL, silent: silent)
        self.engine = engine
        self.marks = marks.sorted { $0.beat < $1.beat }

        goToPage(0)
        try engine.start()
        mode = .playing
        startTimer()
    }

    func startRecording(midiURL: URL) throws {
        stop()
        let engine = try MIDIPlaybackEngine(midiURL: midiURL)
        self.engine = engine
        recorded = []

        goToPage(0)
        try engine.start()
        mode = .recording
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil

        let finishedRecording = mode == .recording ? recorded : []
        engine?.stop()
        engine = nil
        mode = .idle

        if !finishedRecording.isEmpty {
            onRecordingFinished?(finishedRecording)
        }
    }

    /// Call whenever the visible page changes; only meaningful while recording.
    func pageChanged() {
        guard mode == .recording, let engine else { return }
        let page = currentPageIndex
        guard page > (recorded.last?.page ?? 0) else { return }
        recorded.append(PageMark(page: page, beat: engine.currentBeat))
    }

    private var currentPageIndex: Int {
        guard let document = pdfView.document, let page = pdfView.currentPage else { return 0 }
        return document.index(for: page)
    }

    private func goToPage(_ index: Int) {
        guard let page = pdfView.document?.page(at: index) else { return }
        pdfView.go(to: page)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard let engine else { return }

        if mode == .playing {
            // Page shown = the latest recorded mark the track has passed.
            let target = marks.last(where: { $0.beat <= engine.currentBeat })?.page ?? 0
            if target != currentPageIndex { goToPage(target) }
        }

        if engine.hasFinished { stop() }
    }
}
