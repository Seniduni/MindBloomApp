import Foundation
import SwiftData

/// A daily self-care habit. Completions are separate records (one per day),
/// so streaks and history are *calculated* rather than stored.
@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var symbolName: String = "leaf"
    var colorKey: String = HabitTint.teal.rawValue
    var createdAt: Date = Date.now
    var sortOrder: Int = 0
    var isSample: Bool = false

    /// Deleting a habit deletes its completion history too.
    @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.habit)
    var completions: [HabitCompletion] = []

    init(name: String, symbolName: String, tint: HabitTint, sortOrder: Int = 0,
         createdAt: Date = .now, isSample: Bool = false) {
        self.id = UUID()
        self.name = name
        self.symbolName = symbolName
        self.colorKey = tint.rawValue
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.isSample = isSample
    }

    var tint: HabitTint {
        get { HabitTint(rawValue: colorKey) ?? .teal }
        set { colorKey = newValue.rawValue }
    }

    func completedDays(calendar: Calendar = .current) -> Set<Date> {
        HabitStreakCalculator.normalizedDays(completions.map(\.day), calendar: calendar)
    }

    func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        let target = calendar.startOfDay(for: date)
        return completions.contains { calendar.isDate($0.day, inSameDayAs: target) }
    }

    func currentStreak(today: Date = .now, calendar: Calendar = .current) -> Int {
        HabitStreakCalculator.currentStreak(completedDays: completedDays(calendar: calendar),
                                            today: today, calendar: calendar)
    }
}

/// Colour choices offered for a habit. Kept as plain keys so the model does not depend on SwiftUI.
enum HabitTint: String, CaseIterable, Codable, Identifiable, Sendable {
    case teal, mint, lavender, sky, sun, peach
    var id: String { rawValue }
}

/// Curated SF Symbols for habits — all present in SF Symbols 5 (iOS 17+).
enum HabitSymbols {
    static let options = [
        "drop.fill", "figure.walk", "bed.double.fill", "book.fill", "leaf.fill", "sun.max.fill",
        "fork.knife", "music.note", "pencil", "iphone.slash", "person.2.fill", "heart.fill"
    ]
}
