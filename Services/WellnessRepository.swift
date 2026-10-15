import Foundation
import SwiftData

/// The single place where records are created, changed and deleted.
///
/// Views *read* with `@Query` (which updates automatically) and *write* through
/// this repository, so validation and saving happen consistently and can be
/// tested against an in-memory container.
@MainActor
struct WellnessRepository {
    let context: ModelContext
    var calendar: Calendar = .current

    // MARK: Mood

    @discardableResult
    func addMood(emotion: Emotion, intensity: Int, note: String, factors: [MoodFactor],
                 at date: Date = .now) throws -> MoodEntry {
        let entry = MoodEntry(timestamp: date, emotion: emotion, intensity: intensity,
                              note: note, factors: factors)
        context.insert(entry)
        try save()
        return entry
    }

    func delete(_ entry: MoodEntry) throws {
        context.delete(entry)
        try save()
    }

    // MARK: Journal

    /// Creates a new entry when `existing` is nil, otherwise updates it in place.
    @discardableResult
    func saveJournal(existing: JournalEntry?, title: String, body: String, prompt: String,
                     now: Date = .now) throws -> JournalEntry {
        let valid = try InputValidator.validatedJournal(title: title, body: body, date: existing?.createdAt ?? now)
        if let existing {
            existing.title = valid.title
            existing.body = valid.body
            existing.prompt = prompt
            existing.updatedAt = now
            try save()
            return existing
        }
        let entry = JournalEntry(title: valid.title, body: valid.body, prompt: prompt, createdAt: now)
        context.insert(entry)
        try save()
        return entry
    }

    func toggleFavorite(_ entry: JournalEntry) throws {
        entry.isFavorite.toggle()
        try save()
    }

    func delete(_ entry: JournalEntry) throws {
        context.delete(entry)
        try save()
    }

    // MARK: Habits

    @discardableResult
    func addHabit(name: String, symbolName: String, tint: HabitTint) throws -> Habit {
        let existing = try context.fetch(FetchDescriptor<Habit>())
        let cleanName = try InputValidator.validatedHabitName(name, existingNames: existing.map(\.name))
        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        let habit = Habit(name: cleanName, symbolName: symbolName, tint: tint, sortOrder: nextOrder)
        context.insert(habit)
        try save()
        return habit
    }

    func updateHabit(_ habit: Habit, name: String, symbolName: String, tint: HabitTint) throws {
        let others = try context.fetch(FetchDescriptor<Habit>()).filter { $0.id != habit.id }
        habit.name = try InputValidator.validatedHabitName(name, existingNames: others.map(\.name))
        habit.symbolName = symbolName
        habit.tint = tint
        try save()
    }

    func delete(_ habit: Habit) throws {
        context.delete(habit)   // completions are removed by the cascade rule
        try save()
    }

    /// Marks the habit done (or not done) for `day`. Returns the new state.
    /// Future days are rejected so history cannot be faked forward.
    @discardableResult
    func toggleHabit(_ habit: Habit, on day: Date, today: Date = .now) throws -> Bool {
        guard HabitStreakCalculator.canToggle(day: day, today: today, calendar: calendar) else {
            return habit.isCompleted(on: day, calendar: calendar)
        }
        let matches = habit.completions.filter { calendar.isDate($0.day, inSameDayAs: day) }
        if matches.isEmpty {
            // Insert first, then link through the to-many side; SwiftData sets the inverse.
            let completion = HabitCompletion(day: day, completedAt: today, calendar: calendar)
            context.insert(completion)
            habit.completions.append(completion)
            try save()
            return true
        } else {
            let ids = Set(matches.map(\.id))
            habit.completions.removeAll { ids.contains($0.id) }
            matches.forEach { context.delete($0) }
            try save()
            return false
        }
    }

    // MARK: Sessions

    @discardableResult
    func recordFocusSession(startedAt: Date, endedAt: Date, plannedMinutes: Int,
                            focusedSeconds: Int, completed: Bool, intention: String) throws -> FocusSession {
        let session = FocusSession(startedAt: startedAt, endedAt: endedAt, plannedMinutes: plannedMinutes,
                                   durationSeconds: focusedSeconds, wasCompleted: completed, intention: intention)
        context.insert(session)
        try save()
        return session
    }

    @discardableResult
    func recordBreathingSession(startedAt: Date, seconds: Int, pattern: BreathingPattern,
                                cycles: Int, completed: Bool) throws -> BreathingSession {
        let session = BreathingSession(startedAt: startedAt, durationSeconds: seconds, pattern: pattern,
                                       cyclesCompleted: cycles, wasCompleted: completed)
        context.insert(session)
        try save()
        return session
    }

    // MARK: Housekeeping

    /// Permanently removes every record of every type.
    func deleteAllData() throws {
        try context.fetch(FetchDescriptor<HabitCompletion>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Habit>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<MoodEntry>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<JournalEntry>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<FocusSession>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<BreathingSession>()).forEach { context.delete($0) }
        try save()
    }

    func save() throws {
        if context.hasChanges { try context.save() }
    }
}
