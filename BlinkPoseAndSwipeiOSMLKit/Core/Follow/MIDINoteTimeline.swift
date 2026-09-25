import AudioToolbox
import Foundation

// The notes of a MIDI file laid out in beats, with a precomputed "which pitch
// classes should be sounding here" fingerprint for every eighth of a beat.
// Score following compares live microphone audio against these fingerprints.
final class MIDINoteTimeline {
    struct Note {
        let beat: Double
        let duration: Double
        let pitch: Int
    }

    static let gridStep = 0.125

    let notes: [Note]
    let lengthInBeats: Double
    /// Nominal tempo of the file, in beats per second.
    let beatsPerSecond: Double
    /// Distinct moments (in beats) at which something is struck; simultaneous
    /// notes (a chord) count once, which is what a microphone hears too.
    let onsetBeats: [Double]

    private let chromaGrid: [[Float]]

    init(notes: [Note], beatsPerSecond: Double) {
        self.notes = notes.sorted { $0.beat < $1.beat }
        self.beatsPerSecond = max(beatsPerSecond, 0.1)
        lengthInBeats = self.notes.map { $0.beat + $0.duration }.max() ?? 0

        var onsets: [Double] = []
        for note in self.notes where onsets.last.map({ note.beat - $0 > 0.05 }) ?? true {
            onsets.append(note.beat)
        }
        onsetBeats = onsets

        let steps = Int(ceil(lengthInBeats / Self.gridStep)) + 1
        var grid = [[Float]](repeating: [Float](repeating: 0, count: 12), count: max(steps, 1))
        for note in self.notes {
            let first = max(0, Int(floor(note.beat / Self.gridStep)))
            let last = min(steps - 1, Int(ceil((note.beat + max(note.duration, 0.25)) / Self.gridStep)))
            guard first <= last else { continue }
            for index in first...last {
                let age = Double(index) * Self.gridStep - note.beat
                // Struck notes are loudest; they fade as they ring on.
                grid[index][((note.pitch % 12) + 12) % 12] += Float(max(0.3, exp(-0.7 * max(age, 0))))
            }
        }
        chromaGrid = grid.map(Self.normalized)
    }

    /// Loads a MIDI file. Returns nil if it can't be read or has no notes.
    convenience init?(url: URL) {
        var sequence: MusicSequence?
        guard NewMusicSequence(&sequence) == noErr, let sequence,
              MusicSequenceFileLoad(sequence, url as CFURL, .midiType, []) == noErr else { return nil }
        defer { DisposeMusicSequence(sequence) }

        var notes: [Note] = []
        var trackCount: UInt32 = 0
        MusicSequenceGetTrackCount(sequence, &trackCount)
        for index in 0..<trackCount {
            var track: MusicTrack?
            guard MusicSequenceGetIndTrack(sequence, index, &track) == noErr, let track else { continue }
            var iterator: MusicEventIterator?
            NewMusicEventIterator(track, &iterator)
            guard let iterator else { continue }
            defer { DisposeMusicEventIterator(iterator) }

            var hasEvent: DarwinBoolean = false
            MusicEventIteratorHasCurrentEvent(iterator, &hasEvent)
            while hasEvent.boolValue {
                var time: MusicTimeStamp = 0
                var type: MusicEventType = 0
                var data: UnsafeRawPointer?
                var size: UInt32 = 0
                MusicEventIteratorGetEventInfo(iterator, &time, &type, &data, &size)
                if type == kMusicEventType_MIDINoteMessage, let data {
                    let message = data.assumingMemoryBound(to: MIDINoteMessage.self).pointee
                    if message.channel != 9 {   // channel 10 is percussion: no pitch to follow
                        notes.append(Note(beat: time, duration: Double(message.duration), pitch: Int(message.note)))
                    }
                }
                MusicEventIteratorNextEvent(iterator)
                MusicEventIteratorHasCurrentEvent(iterator, &hasEvent)
            }
        }
        guard !notes.isEmpty else { return nil }

        let totalBeats = notes.map { $0.beat + $0.duration }.max() ?? 1
        var seconds: Float64 = 0
        MusicSequenceGetSecondsForBeats(sequence, totalBeats, &seconds)
        self.init(notes: notes, beatsPerSecond: seconds > 0 ? totalBeats / seconds : 2)
    }

    /// The pitch-class fingerprint (12 values, unit length) at a beat.
    func chroma(at beat: Double) -> [Float] {
        let index = min(max(Int((beat / Self.gridStep).rounded()), 0), chromaGrid.count - 1)
        return chromaGrid[index]
    }

    /// How many distinct onsets fall in `beats`.
    func onsetCount(in beats: ClosedRange<Double>) -> Int {
        onsetBeats.lazy.filter { beats.contains($0) }.count
    }

    static func normalized(_ vector: [Float]) -> [Float] {
        let length = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        return length > 0 ? vector.map { $0 / length } : vector
    }

    static func similarity(_ a: [Float], _ b: [Float]) -> Float {
        zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }   // both inputs are unit length
    }
}
