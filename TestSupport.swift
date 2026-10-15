import Foundation
@testable import MindBloom

/// A fixed calendar and clock so date-based tests give the same result in any
/// time zone, on any day the tests are run.
enum TestClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Tuesday 10 March 2026, 12:00 UTC.
    static let now: Date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))!

    static func daysAgo(_ days: Int, hour: Int = 12) -> Date {
        let day = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now))!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }
}

/// Plain value used to test mood maths without SwiftData.
struct StubMood: MoodRecord {
    let timestamp: Date
    let emotion: Emotion
    let intensity: Int
}

struct StubSession: TimedSessionRecord {
    let startedAt: Date
    let durationSeconds: Int
    let wasCompleted: Bool
}
