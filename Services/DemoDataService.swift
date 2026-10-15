import Foundation
import SwiftData

/// Loads and removes realistic demonstration data.
///
/// Every record it creates has `isSample == true`, so "Remove sample data" deletes
/// exactly those records and never touches anything the student entered.
/// A seeded generator makes the data identical on every load, which keeps demos
/// and screenshots repeatable.
@MainActor
enum DemoDataService {
    static let days = 14

    static func hasSampleData(in context: ModelContext) -> Bool {
        let moods = (try? context.fetch(FetchDescriptor<MoodEntry>())) ?? []
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        return moods.contains(where: \.isSample) || habits.contains(where: \.isSample)
    }

    /// Replaces any previous sample data with a fresh 14-day story ending on `now`.
    static func loadSampleData(into context: ModelContext, now: Date = .now,
                               calendar: Calendar = .current) throws {
        try removeSampleData(from: context)
        var random = SeededGenerator(seed: 2026)
        let today = calendar.startOfDay(for: now)

        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        // Moods: an assignment-and-exam fortnight that eases towards the end.
        let story: [(Emotion, Emotion?)] = [
            (.calm, .motivated), (.okay, .tired), (.motivated, .grateful), (.okay, .anxious),
            (.anxious, .stressed), (.stressed, .tired), (.tired, .okay), (.anxious, .calm),
            (.okay, .motivated), (.calm, .grateful), (.motivated, .joyful), (.tired, .calm),
            (.calm, .grateful)
        ]
        let factorSets: [[MoodFactor]] = [[.study], [.sleep], [.exams, .study], [.friends], [.exercise],
                                          [.family], [.rest], [.health], [.money, .study]]
        for (index, pair) in story.enumerated() {
            let offset = days - 1 - index            // 13 … 1 (today is left for the student)
            guard offset >= 1 else { continue }
            let morning = MoodEntry(timestamp: at(offset, 8, Int.random(in: 0...50, using: &random)),
                                    emotion: pair.0, intensity: Int.random(in: 2...4, using: &random),
                                    factors: factorSets[index % factorSets.count], isSample: true)
            context.insert(morning)
            if let evening = pair.1 {
                let entry = MoodEntry(timestamp: at(offset, 20, Int.random(in: 0...50, using: &random)),
                                      emotion: evening, intensity: Int.random(in: 2...5, using: &random),
                                      note: index == 4 ? "Two deadlines on the same day." : "",
                                      factors: factorSets[(index + 3) % factorSets.count], isSample: true)
                context.insert(entry)
            }
        }

        // Habits and their completion history.
        let habitSpecs: [(String, String, HabitTint, Double)] = [
            ("Drink water", "drop.fill", .teal, 0.85),
            ("Move for 20 minutes", "figure.walk", .mint, 0.6),
            ("Lights out by 11:30", "bed.double.fill", .lavender, 0.5),
            ("Phone-free study block", "iphone.slash", .sky, 0.7)
        ]
        for (order, spec) in habitSpecs.enumerated() {
            let habit = Habit(name: spec.0, symbolName: spec.1, tint: spec.2, sortOrder: order,
                              createdAt: at(days, 9), isSample: true)
            context.insert(habit)
            for offset in 0..<days {
                // Today only the first habit is pre-ticked, so the student can try the rest.
                let done = offset == 0 ? order == 0 : Double.random(in: 0...1, using: &random) < spec.3
                guard done else { continue }
                let completion = HabitCompletion(day: at(offset, 12), completedAt: at(offset, 18),
                                                 isSample: true, calendar: calendar)
                context.insert(completion)
                habit.completions.append(completion)
            }
        }

        // Focus sessions on most days.
        for offset in 1..<days where offset % 7 != 0 {
            let count = Int.random(in: 1...3, using: &random)
            for n in 0..<count {
                let planned = [25, 25, 45][Int.random(in: 0...2, using: &random)]
                let completed = Double.random(in: 0...1, using: &random) > 0.2
                let seconds = completed ? planned * 60 : Int.random(in: 8...(planned - 5), using: &random) * 60
                let start = at(offset, 10 + n * 3, 15)
                context.insert(FocusSession(startedAt: start, endedAt: start.addingTimeInterval(TimeInterval(seconds)),
                                            plannedMinutes: planned, durationSeconds: seconds,
                                            wasCompleted: completed,
                                            intention: ["Lab report", "Revise lecture 7", "Read paper", "Assignment code"][n % 4],
                                            isSample: true))
            }
        }

        // Breathing on roughly every other day.
        for offset in stride(from: 1, to: days, by: 2) {
            let pattern = BreathingPattern.allCases[offset % BreathingPattern.allCases.count]
            let minutes = [3, 5, 1][offset % 3]
            let seconds = minutes * 60
            context.insert(BreathingSession(startedAt: at(offset, 21, 30), durationSeconds: seconds,
                                            pattern: pattern,
                                            cyclesCompleted: Int(Double(seconds) / pattern.cycleDuration),
                                            wasCompleted: true, isSample: true))
        }

        // A few journal entries.
        for (offset, entry) in sampleJournals {
            context.insert(JournalEntry(title: entry.title, body: entry.body, prompt: entry.prompt,
                                        createdAt: at(offset, 22, 10), isFavorite: offset == 3, isSample: true))
        }

        try context.save()
    }

    /// Deletes only records flagged as sample data.
    static func removeSampleData(from context: ModelContext) throws {
        // Fetch-then-filter keeps this simple and avoids predicate edge cases; the data set is small.
        // Completions first, then habits, so nothing is deleted twice via the cascade rule.
        for item in try context.fetch(FetchDescriptor<HabitCompletion>()) where item.isSample || item.habit?.isSample == true {
            context.delete(item)
        }
        for habit in try context.fetch(FetchDescriptor<Habit>()) where habit.isSample { context.delete(habit) }
        for item in try context.fetch(FetchDescriptor<MoodEntry>()) where item.isSample { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<JournalEntry>()) where item.isSample { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<FocusSession>()) where item.isSample { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<BreathingSession>()) where item.isSample { context.delete(item) }
        try context.save()
    }

    private static let sampleJournals: [(Int, (title: String, body: String, prompt: String))] = [
        (12, ("Settling into the semester",
              "The first week back felt busy but manageable. I made a proper timetable and stuck to it for three days, which is a small win. I want to keep my evenings free for at least one hour of something that is not study.",
              "What went well this week?")),
        (9, ("Too many tabs open",
             "Two deadlines landed on the same day and my head felt crowded. I kept switching between tasks and finished neither. Tomorrow I will do one focus block for each, starting with the lab report, and stop at nine.",
             "What is taking up space in your mind?")),
        (6, ("Walk after the exam",
             "The exam was harder than I expected, but walking home with friends afterwards helped. We laughed about the last question. I slept badly though, so I want to protect my sleep before the next paper.",
             "")),
        (3, ("Small things that helped",
             "Grateful for a quiet library corner, a good cup of tea, and my sister calling to check in. I finished the assignment draft early and felt genuinely proud of the structure. Calm evening.",
             "Name three small things you are grateful for.")),
        (1, ("Planning the next stretch",
             "Feeling more balanced. I noticed I focus best in the morning, so I will move the hardest reading there. Keeping the phone-free study block has made a real difference to how scattered I feel.",
             "What would make tomorrow a little easier?"))
    ]
}

/// A tiny deterministic random number generator (a linear congruential generator)
/// so sample data is the same every time it is loaded.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
