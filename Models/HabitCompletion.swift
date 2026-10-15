import Foundation
import SwiftData

/// Marks one habit as done on one calendar day.
///
/// The link to its `Habit` is set *after* insertion (by appending to
/// `habit.completions`), which is the most reliable way to build SwiftData relationships.
@Model
final class HabitCompletion {
    var id: UUID = UUID()
    /// Always the *start* of the day, so "is it done today?" is a simple comparison.
    var day: Date = Date.now
    /// When the student actually tapped the habit.
    var completedAt: Date = Date.now
    var habit: Habit?
    var isSample: Bool = false

    init(day: Date, completedAt: Date = .now, isSample: Bool = false, calendar: Calendar = .current) {
        self.id = UUID()
        self.day = calendar.startOfDay(for: day)
        self.completedAt = completedAt
        self.isSample = isSample
    }
}
