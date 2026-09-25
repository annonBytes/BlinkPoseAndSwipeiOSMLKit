import XCTest
@testable import BlinkPoseAndSwipeiOSMLKit

final class ScoreFollowingTests: XCTestCase {

    /// One note per beat cycling through pitch classes, so every beat has a distinct fingerprint.
    private func melodyTimeline(beats: Int = 80, beatsPerSecond: Double = 2) -> MIDINoteTimeline {
        let notes = (0..<beats).map { MIDINoteTimeline.Note(beat: Double($0), duration: 1, pitch: 60 + ($0 * 5) % 12) }
        return MIDINoteTimeline(notes: notes, beatsPerSecond: beatsPerSecond)
    }

    private func oneHot(_ pitchClass: Int) -> [Float] {
        var vector = [Float](repeating: 0, count: 12)
        vector[pitchClass] = 1
        return vector
    }

    func testTimelineFingerprintsMatchTheNotes() {
        let timeline = melodyTimeline()
        // At the start of beat 3 the note struck is 60 + 15 % 12 = pitch class 3.
        let chroma = timeline.chroma(at: 3)
        XCTAssertEqual(chroma.firstIndex(of: chroma.max()!), 3)
        XCTAssertEqual(timeline.onsetBeats.count, 80)
    }

    func testChordsCountAsOneOnset() {
        let notes = [60, 64, 67].map { MIDINoteTimeline.Note(beat: 0, duration: 1, pitch: $0) }
            + [MIDINoteTimeline.Note(beat: 1, duration: 1, pitch: 62)]
        XCTAssertEqual(MIDINoteTimeline(notes: notes, beatsPerSecond: 2).onsetBeats, [0, 1])
    }

    func testNoteFollowerTracksAPlayerAtTheNominalTempo() {
        let timeline = melodyTimeline()
        let follower = NoteFollower(timeline: timeline)
        var time = 0.0
        let dt = 0.05
        while time < 20 {
            let trueBeat = time * 2
            follower.feed(chroma: oneHot(Int(trueBeat) * 5 % 12), isAudible: true, dt: dt)
            time += dt
        }
        XCTAssertEqual(follower.position, 40, accuracy: 1.5)
    }

    func testNoteFollowerKeepsUpWithAFasterPlayer() {
        let timeline = melodyTimeline()
        let follower = NoteFollower(timeline: timeline)
        var time = 0.0
        let dt = 0.05
        while time < 15 {
            let trueBeat = time * 2.6   // 30% faster than the file
            follower.feed(chroma: oneHot(Int(trueBeat) * 5 % 12), isAudible: true, dt: dt)
            time += dt
        }
        XCTAssertEqual(follower.position, 39, accuracy: 3)
    }

    func testNoteFollowerHoldsDuringSilence() {
        let follower = NoteFollower(timeline: melodyTimeline())
        for step in 0..<40 { follower.feed(chroma: oneHot(step / 10 * 5 % 12), isAudible: true, dt: 0.05) }
        let held = follower.position
        for _ in 0..<100 { follower.feed(chroma: oneHot(0), isAudible: false, dt: 0.05) }
        XCTAssertEqual(follower.position, held, accuracy: 0.001)
    }

    private func onsetTimeline() -> MIDINoteTimeline {
        // Eighth notes: two onsets per beat, at 120 BPM (2 beats per second).
        let notes = (0..<160).map { MIDINoteTimeline.Note(beat: Double($0) * 0.5, duration: 0.5, pitch: 60) }
        return MIDINoteTimeline(notes: notes, beatsPerSecond: 2)
    }

    func testTempoFollowerLearnsASlowerPlayer() {
        let follower = TempoFollower(timeline: onsetTimeline())
        let playerBeatsPerSecond = 1.5
        let onsetInterval = 0.5 / playerBeatsPerSecond
        var time = 0.0
        var nextOnset = 0.0
        while time < 40 {
            if time >= nextOnset { follower.noteOnset(at: time); nextOnset += onsetInterval }
            follower.tick(at: time)
            time += 0.02
        }
        XCTAssertEqual(follower.rate, playerBeatsPerSecond, accuracy: 0.25)
        XCTAssertEqual(follower.position, 40 * playerBeatsPerSecond, accuracy: 6)
    }

    func testTempoFollowerWaitsForTheFirstNoteAndPausesInSilence() {
        let follower = TempoFollower(timeline: onsetTimeline())
        follower.tick(at: 0)
        follower.tick(at: 5)
        XCTAssertEqual(follower.position, 0, "the clock must not start before the player does")

        follower.noteOnset(at: 5)
        for step in 1...20 { follower.tick(at: 5 + Double(step) * 0.1) }
        XCTAssertGreaterThan(follower.position, 2)

        for step in 1...100 { follower.tick(at: 7 + Double(step) * 0.1) }   // long silence
        let held = follower.position
        follower.tick(at: 30)
        XCTAssertEqual(follower.position, held, accuracy: 0.001)
        XCTAssertFalse(follower.isRunning)
    }
}
