import Foundation

enum ValidationError: LocalizedError, Equatable {
    case emptyHabitName
    case habitNameTooLong(limit: Int)
    case duplicateHabit
    case emptyJournal

    var errorDescription: String? {
        switch self {
        case .emptyHabitName: "Give your habit a short name."
        case .habitNameTooLong(let limit): "Habit names can be up to \(limit) characters."
        case .duplicateHabit: "You already have a habit with this name."
        case .emptyJournal: "Write a few words before saving."
        }
    }
}

/// All user-input rules live here so they are easy to explain and test.
enum InputValidator {
    static let maxNoteLength = 280
    static let maxJournalTitleLength = 80
    static let maxJournalBodyLength = 10_000
    static let maxHabitNameLength = 40
    static let intensityRange = 1...5

    static func clampIntensity(_ value: Int) -> Int {
        min(max(value, intensityRange.lowerBound), intensityRange.upperBound)
    }

    /// Trims surrounding whitespace and new lines, then truncates to `maxLength` characters.
    static func sanitized(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > maxLength ? String(trimmed.prefix(maxLength)) : trimmed
    }

    /// Returns the cleaned name, or throws if it is empty, too long, or already used
    /// (case-insensitive). `existingNames` should exclude the habit being edited.
    static func validatedHabitName(_ name: String, existingNames: [String]) throws -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw ValidationError.emptyHabitName }
        guard cleaned.count <= maxHabitNameLength else {
            throw ValidationError.habitNameTooLong(limit: maxHabitNameLength)
        }
        let lowered = cleaned.lowercased()
        if existingNames.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lowered }) {
            throw ValidationError.duplicateHabit
        }
        return cleaned
    }

    /// A journal entry needs body text. An empty title becomes a dated default.
    static func validatedJournal(title: String, body: String, date: Date) throws -> (title: String, body: String) {
        let cleanBody = sanitized(body, maxLength: maxJournalBodyLength)
        guard !cleanBody.isEmpty else { throw ValidationError.emptyJournal }
        var cleanTitle = sanitized(title, maxLength: maxJournalTitleLength)
        if cleanTitle.isEmpty {
            cleanTitle = "Reflection · " + date.formatted(.dateTime.day().month(.abbreviated))
        }
        return (cleanTitle, cleanBody)
    }
}
