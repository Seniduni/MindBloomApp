import Foundation

/// A single value attached to a calendar day. Used by every chart series.
struct DailyValue: Identifiable, Equatable, Sendable {
    let day: Date
    let value: Double
    var id: Date { day }
}

extension Calendar {
    /// The start of each of the last `count` days, oldest first, ending with the day containing `end`.
    func lastDays(_ count: Int, endingOn end: Date) -> [Date] {
        guard count > 0 else { return [] }
        let endDay = startOfDay(for: end)
        return (0..<count).reversed().compactMap { offset in
            date(byAdding: .day, value: -offset, to: endDay)
        }
    }

    /// A half-open interval covering the last `days` whole days, ending at midnight after `end`.
    func interval(lastDays days: Int, endingOn end: Date) -> DateInterval {
        let endDay = startOfDay(for: end)
        let upper = date(byAdding: .day, value: 1, to: endDay) ?? end
        let lower = date(byAdding: .day, value: -(max(days, 1) - 1), to: endDay) ?? endDay
        return DateInterval(start: lower, end: upper)
    }
}

extension DateInterval {
    /// `contains` in Foundation is inclusive of the end date; charts need a half-open range.
    func containsHalfOpen(_ date: Date) -> Bool {
        date >= start && date < end
    }
}
