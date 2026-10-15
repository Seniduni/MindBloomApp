import Foundation
import SwiftData

/// Exports everything the student has stored as a readable JSON file they can
/// save or share themselves (data portability). Nothing is uploaded by the app.
@MainActor
enum DataExportService {
    struct Export: Codable {
        let exportedAt: Date
        let app: String
        let moods: [Mood]
        let journal: [Journal]
        let habits: [HabitRecord]
        let focusSessions: [Session]
        let breathingSessions: [Session]

        struct Mood: Codable { let date: Date; let emotion: String; let intensity: Int; let note: String; let factors: [String] }
        struct Journal: Codable { let created: Date; let updated: Date; let title: String; let body: String; let favorite: Bool }
        struct HabitRecord: Codable { let name: String; let completedDays: [Date] }
        struct Session: Codable { let started: Date; let seconds: Int; let completed: Bool; let detail: String }
    }

    static func makeExport(from context: ModelContext, now: Date = .now) throws -> Export {
        let moods = try context.fetch(FetchDescriptor<MoodEntry>(sortBy: [SortDescriptor(\.timestamp)]))
        let journal = try context.fetch(FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.createdAt)]))
        let habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
        let focus = try context.fetch(FetchDescriptor<FocusSession>(sortBy: [SortDescriptor(\.startedAt)]))
        let breathing = try context.fetch(FetchDescriptor<BreathingSession>(sortBy: [SortDescriptor(\.startedAt)]))

        return Export(
            exportedAt: now,
            app: "MIND BLOOM 1.0",
            moods: moods.map { Export.Mood(date: $0.timestamp, emotion: $0.emotion.rawValue, intensity: $0.intensity,
                                     note: $0.note, factors: $0.factorsRaw) },
            journal: journal.map { Export.Journal(created: $0.createdAt, updated: $0.updatedAt, title: $0.title,
                                         body: $0.body, favorite: $0.isFavorite) },
            habits: habits.map { Export.HabitRecord(name: $0.name, completedDays: $0.completions.map(\.day).sorted()) },
            focusSessions: focus.map { Export.Session(started: $0.startedAt, seconds: $0.durationSeconds,
                                             completed: $0.wasCompleted, detail: $0.intention) },
            breathingSessions: breathing.map { Export.Session(started: $0.startedAt, seconds: $0.durationSeconds,
                                                     completed: $0.wasCompleted, detail: $0.pattern.displayName) })
    }

    /// Writes the export to a temporary file and returns its URL for `ShareLink`.
    static func writeExportFile(from context: ModelContext) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(makeExport(from: context))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MindBloom-export.json")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}
