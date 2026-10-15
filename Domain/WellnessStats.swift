import Foundation

/// Anything timed and completed: focus sessions and breathing sessions both conform.
protocol TimedSessionRecord {
    var startedAt: Date { get }
    var durationSeconds: Int { get }
    var wasCompleted: Bool { get }
}

/// Aggregations used by the Today and Insights screens. Pure functions only.
enum WellnessStats {
    /// Minutes per day for the last `days` days (zero-filled so bar charts show gaps honestly).
    static func minutesPerDay<S: TimedSessionRecord>(_ sessions: [S], lastDays days: Int,
                                                     endingOn end: Date, calendar: Calendar = .current) -> [DailyValue] {
        var totals: [Date: Int] = [:]
        for session in sessions {
            totals[calendar.startOfDay(for: session.startedAt), default: 0] += session.durationSeconds
        }
        return calendar.lastDays(days, endingOn: end).map { day in
            DailyValue(day: day, value: Double(totals[day, default: 0]) / 60)
        }
    }

    static func totalMinutes<S: TimedSessionRecord>(_ sessions: [S], lastDays days: Int,
                                                    endingOn end: Date, calendar: Calendar = .current) -> Int {
        let window = calendar.interval(lastDays: days, endingOn: end)
        let seconds = sessions.filter { window.containsHalfOpen($0.startedAt) }.reduce(0) { $0 + $1.durationSeconds }
        return seconds / 60
    }

    static func completedCount<S: TimedSessionRecord>(_ sessions: [S], lastDays days: Int,
                                                      endingOn end: Date, calendar: Calendar = .current) -> Int {
        let window = calendar.interval(lastDays: days, endingOn: end)
        return sessions.filter { $0.wasCompleted && window.containsHalfOpen($0.startedAt) }.count
    }
}

/// The four small daily rituals that make up the "bloom" on the Today screen.
struct DailyRitualStatus: Equatable, Sendable {
    var checkedIn = false
    var breathed = false
    var focused = false
    /// True only when there is at least one habit and every habit is done today.
    var habitsDone = false

    var completedCount: Int { [checkedIn, breathed, focused, habitsDone].filter { $0 }.count }
    var progress: Double { Double(completedCount) / 4 }

    static func evaluate(moodTimes: [Date], breathingTimes: [Date], focusTimes: [Date],
                         habitCount: Int, habitsCompletedToday: Int,
                         today: Date, calendar: Calendar = .current) -> DailyRitualStatus {
        let isToday: (Date) -> Bool = { calendar.isDate($0, inSameDayAs: today) }
        return DailyRitualStatus(checkedIn: moodTimes.contains(where: isToday),
                                 breathed: breathingTimes.contains(where: isToday),
                                 focused: focusTimes.contains(where: isToday),
                                 habitsDone: habitCount > 0 && habitsCompletedToday >= habitCount)
    }
}
