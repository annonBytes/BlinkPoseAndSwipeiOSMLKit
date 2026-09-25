import Foundation

// Follows the player's tempo rather than their notes: it only needs to hear
// *when* notes are played. A clock runs through the piece; if the player
// plays more or fewer notes than the score has in that stretch, the clock
// speeds up or slows down to match. The clock holds while the player is silent.
final class TempoFollower {
    private let timeline: MIDINoteTimeline
    private let window: TimeInterval = 6
    private let silenceTimeout: TimeInterval = 2.5

    private(set) var position: Double
    private(set) var rate: Double
    private(set) var isRunning = false

    private var onsets: [TimeInterval] = []
    private var lastOnset: TimeInterval?
    private var lastTick: TimeInterval?

    init(timeline: MIDINoteTimeline, startBeat: Double = 0) {
        self.timeline = timeline
        position = startBeat
        rate = timeline.beatsPerSecond
    }

    /// Call when the microphone hears a note being played.
    func noteOnset(at time: TimeInterval) {
        if !isRunning {
            isRunning = true
            lastTick = time
        }
        lastOnset = time
        onsets.append(time)
        onsets.removeAll { time - $0 > window }
        adaptRate(at: time)
    }

    /// Call regularly (e.g. once per audio frame) to move the clock.
    func tick(at time: TimeInterval) {
        defer { lastTick = time }
        guard isRunning, let lastTick else { return }

        if let lastOnset, time - lastOnset > silenceTimeout {
            isRunning = false
            onsets.removeAll()
            return
        }
        position = min(position + rate * max(0, time - lastTick), timeline.lengthInBeats)
    }

    private func adaptRate(at time: TimeInterval) {
        guard let first = onsets.first, time - first >= window * 0.6 else { return }   // need a few seconds of evidence

        let expected = timeline.onsetCount(in: max(0, position - rate * window)...max(position, 0.001))
        guard expected >= 6, onsets.count >= 4 else { return }

        let ratio = Double(onsets.count) / Double(expected)
        let nominal = timeline.beatsPerSecond
        rate = min(max(rate * pow(ratio, 0.1), nominal * 0.5), nominal * 2)
    }
}
