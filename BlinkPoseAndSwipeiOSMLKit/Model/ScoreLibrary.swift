import PDFKit
import UIKit

// PDFs are copied into the app's own Documents/Scores directory rather than
// referenced via a security-scoped bookmark to an external URL. These files
// are small and copying avoids stale/broken bookmarks if the user moves or
// renames the original in Files — the library stays self-contained.
final class ScoreLibrary {
    static let shared = ScoreLibrary()

    private(set) var scores: [Score] = []

    private let scoresDirectory: URL
    private let storeURL: URL

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        scoresDirectory = documents.appendingPathComponent("Scores", isDirectory: true)
        storeURL = documents.appendingPathComponent("scores.json")
        try? FileManager.default.createDirectory(at: scoresDirectory, withIntermediateDirectories: true)
        load()
        seedWelcomeScoreIfNeeded()
    }

    func fileURL(for score: Score) -> URL {
        scoresDirectory.appendingPathComponent(score.fileName)
    }

    @discardableResult
    func importPDF(at sourceURL: URL) throws -> Score {
        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if didStartAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        let id = UUID()
        let fileName = "\(id.uuidString).pdf"
        try FileManager.default.copyItem(at: sourceURL, to: scoresDirectory.appendingPathComponent(fileName))

        let title = sourceURL.deletingPathExtension().lastPathComponent
        let score = Score(id: id, title: title, fileName: fileName)
        scores.append(score)
        save()
        return score
    }

    func score(withID id: UUID) -> Score? {
        scores.first { $0.id == id }
    }

    func midiURL(for score: Score) -> URL? {
        score.midiFileName.map { scoresDirectory.appendingPathComponent($0) }
    }

    /// Copies a MIDI file into the library for this score. Replacing a file
    /// also clears the old page marks, since they were recorded against it.
    func attachMIDI(at sourceURL: URL, to score: Score) throws {
        guard let index = scores.firstIndex(where: { $0.id == score.id }) else { return }

        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if didStartAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        let fileName = "\(score.id.uuidString)-\(UUID().uuidString.prefix(8)).mid"
        try FileManager.default.copyItem(at: sourceURL, to: scoresDirectory.appendingPathComponent(fileName))

        if let old = scores[index].midiFileName {
            try? FileManager.default.removeItem(at: scoresDirectory.appendingPathComponent(old))
        }
        scores[index].midiFileName = fileName
        scores[index].pageMarks = nil
        save()
    }

    func removeMIDI(from score: Score) {
        guard let index = scores.firstIndex(where: { $0.id == score.id }) else { return }
        if let old = scores[index].midiFileName {
            try? FileManager.default.removeItem(at: scoresDirectory.appendingPathComponent(old))
        }
        scores[index].midiFileName = nil
        scores[index].pageMarks = nil
        save()
    }

    func setPageMarks(_ marks: [PageMark], for score: Score) {
        guard let index = scores.firstIndex(where: { $0.id == score.id }) else { return }
        scores[index].pageMarks = marks
        save()
    }

    func delete(_ score: Score) {
        guard !score.isBuiltIn else { return }
        try? FileManager.default.removeItem(at: fileURL(for: score))
        if let midi = midiURL(for: score) { try? FileManager.default.removeItem(at: midi) }
        scores.removeAll { $0.id == score.id }
        save()
    }

    func move(fromIndex: Int, toIndex: Int) {
        guard fromIndex != toIndex, scores.indices.contains(fromIndex) else { return }
        let score = scores.remove(at: fromIndex)
        scores.insert(score, at: min(toIndex, scores.count))
        save()
    }

    func setPreferredModality(_ modality: ModalityKind, for score: Score) {
        guard let index = scores.firstIndex(where: { $0.id == score.id }) else { return }
        scores[index].preferredModality = modality
        save()
    }

    func thumbnail(for score: Score, size: CGSize) -> UIImage? {
        guard let document = PDFDocument(url: fileURL(for: score)), let page = document.page(at: 0) else { return nil }
        return page.thumbnail(of: size, for: .mediaBox)
    }

    private func seedWelcomeScoreIfNeeded() {
        guard scores.isEmpty else { return }
        let fileName = "welcome.pdf"
        let destinationURL = scoresDirectory.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.copyItem(at: ScoreViewerViewController.demoDocumentURL, to: destinationURL)
        }
        scores.append(Score(title: "Welcome", fileName: fileName, isBuiltIn: true))
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        scores = (try? JSONDecoder().decode([Score].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(scores) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
