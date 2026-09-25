import Foundation

// Follows a live performance by comparing what the microphone hears (a pitch
// class fingerprint per frame) against the MIDI file, searching a window just
// ahead of where the player is expected to be.
final class NoteFollower {
    private let timeline: MIDINoteTimeline

    /// Where the player is, in beats.
    private(set) var position: Double
    /// How fast the player is moving through the piece, in beats per second.
    private(set) var rate: Double
    /// 0...1: how well the last frame matched the score.
    private(set) var confidence: Float = 0

    private var live = [Float](repeating: 0, count: 12)

    private let minimumMatch: Float = 0.6
    private let lookAhead = 4.0
    private let lookBack = 0.5

    init(timeline: MIDINoteTimeline, startBeat: Double = 0) {
        self.timeline = timeline
        position = startBeat
        rate = timeline.beatsPerSecond
    }

    /// Feeds one analysis frame. `chroma` is unit length; `isAudible` is false
    /// during silence, when the position simply holds.
    func feed(chroma: [Float], isAudible: Bool, dt: Double) {
        guard isAudible else {
            live = live.map { $0 * 0.9 }
            confidence *= 0.9
            return
        }

        live = MIDINoteTimeline.normalized(zip(live, chroma).map { 0.6 * $0 + 0.4 * $1 })

        let expected = position + rate * dt
        var best = expected
        var bestScore = -Float.infinity
        var bestSimilarity: Float = 0
        var candidate = max(0, position - lookBack)
        let end = min(timeline.lengthInBeats, position + lookAhead)
        while candidate <= end {
            let similarity = MIDINoteTimeline.similarity(live, timeline.chroma(at: candidate))
            // Prefer candidates near where the tempo says we should be.
            let score = similarity - 0.03 * Float(abs(candidate - expected))
            if score > bestScore {
                bestScore = score
                best = candidate
                bestSimilarity = similarity
            }
            candidate += MIDINoteTimeline.gridStep
        }

        confidence = max(0, bestSimilarity)
        let previous = position
        if bestSimilarity >= minimumMatch {
            position += 0.5 * (best - position)
        } else {
            position += 0.5 * rate * dt   // sound but no clear match: drift on at half speed
        }
        position = min(max(position, previous - lookBack), timeline.lengthInBeats)

        if dt > 0 {
            let measured = min(max((position - previous) / dt, timeline.beatsPerSecond * 0.5), timeline.beatsPerSecond * 1.6)
            rate = 0.97 * rate + 0.03 * measured
        }
    }
}
