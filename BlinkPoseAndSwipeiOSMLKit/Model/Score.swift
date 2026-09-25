import Foundation

// Where in the attached MIDI (in beats, so it scales with playback tempo) a
// given page should come up.
struct PageMark: Codable, Equatable {
    let page: Int
    let beat: Double
}

// A user's uploaded (or built-in) piece of sheet music. The PDF itself lives
// in ScoreLibrary's Scores/ directory under `fileName`; this struct is just
// the persisted metadata row.
struct Score: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    let fileName: String
    var dateAdded: Date
    var preferredModality: ModalityKind
    var isBuiltIn: Bool

    // Optional MIDI backing track and the recorded page-turn points. Both are
    // optional so libraries saved before this feature still decode.
    var midiFileName: String?
    var pageMarks: [PageMark]?

    init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        dateAdded: Date = Date(),
        preferredModality: ModalityKind = .tap,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.dateAdded = dateAdded
        self.preferredModality = preferredModality
        self.isBuiltIn = isBuiltIn
    }
}
