import Foundation
import SwiftData

/// A private journal entry. Text never leaves the device; on-device analysis
/// results are *not* stored, because they can always be recomputed from `body`.
@Model
final class JournalEntry {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var title: String = ""
    var body: String = ""
    /// The writing prompt the student chose, if any.
    var prompt: String = ""
    var isFavorite: Bool = false
    var isSample: Bool = false

    init(title: String, body: String, prompt: String = "", createdAt: Date = .now,
         isFavorite: Bool = false, isSample: Bool = false) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.prompt = prompt
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isFavorite = isFavorite
        self.isSample = isSample
    }

    /// First line of the body, for list previews.
    var preview: String {
        let firstLine = body.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return firstLine.count > 120 ? String(firstLine.prefix(120)) + "…" : firstLine
    }

    var wordCount: Int {
        body.split { $0.isWhitespace || $0.isNewline }.count
    }
}
