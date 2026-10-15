import Foundation

/// Streak and completion-rate rules for habits, written over plain sets of days
/// so they can be unit tested without SwiftData.
enum HabitStreakCalculator {
    /// Collapses any timestamps to the start of their day.
    static func normalizedDays(_ dates: [Date], calendar: Calendar = .current) -> Set<Date> {
        Set(dates.map { calendar.startOfDay(for: $0) })
    }

    /// Consecutive completed days ending today.
    ///
    /// If today is not done *yet*, a streak that ran up to yesterday is still
    /// reported — the student has until midnight, so the app does not "break"
    /// the streak in the morning.
    static func currentStreak(completedDays: Set<Date>, today: Date, calendar: Calendar = .current) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        var cursor: Date
        if completedDays.contains(todayStart) {
            cursor = todayStart
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart),
                  completedDays.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while completedDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// The longest run of consecutive days anywhere in the history.
    static func longestStreak(completedDays: Set<Date>, calendar: Calendar = .current) -> Int {
        let sorted = completedDays.sorted()
        guard var previous = sorted.first else { return 0 }
        var longest = 1
        var running = 1
        for day in sorted.dropFirst() {
            let gap = calendar.dateComponents([.day], from: previous, to: day).day ?? 0
            running = (gap == 1) ? running + 1 : 1
            longest = max(longest, running)
            previous = day
        }
        return longest
    }

    /// Fraction (0–1) of the last `days` days on which the habit was completed.
    static func completionRate(completedDays: Set<Date>, lastDays days: Int,
                               endingOn end: Date, calendar: Calendar = .current) -> Double {
        let window = calendar.lastDays(days, endingOn: end)
        guard !window.isEmpty else { return 0 }
        let hits = window.filter { completedDays.contains($0) }.count
        return Double(hits) / Double(window.count)
    }

    /// For each of the last `days` days: completions on that day ÷ number of habits (0–1).
    /// `completionDays` contains one entry per completion record (habits × days).
    static func dailyCompletionRatio(completionDays: [Date], habitCount: Int, lastDays days: Int,
                                     endingOn end: Date, calendar: Calendar = .current) -> [DailyValue] {
        let window = calendar.lastDays(days, endingOn: end)
        guard habitCount > 0 else { return window.map { DailyValue(day: $0, value: 0) } }
        var counts: [Date: Int] = [:]
        for date in completionDays { counts[calendar.startOfDay(for: date), default: 0] += 1 }
        return window.map { day in
            DailyValue(day: day, value: min(1, Double(counts[day, default: 0]) / Double(habitCount)))
        }
    }

    /// Students may tick off today or past days, but never a future day.
    static func canToggle(day: Date, today: Date, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: day) <= calendar.startOfDay(for: today)
    }
}
