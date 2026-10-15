import Foundation
import SwiftData

/// Creates the SwiftData container. The app uses the on-disk store; tests and
/// UI-test launches use an in-memory store so they never touch real data.
enum PersistenceController {
    static let modelTypes: [any PersistentModel.Type] = [
        MoodEntry.self, JournalEntry.self, Habit.self, HabitCompletion.self,
        FocusSession.self, BreathingSession.self
    ]

    static var schema: Schema { Schema(modelTypes) }

    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration("MindBloom", schema: schema, isStoredInMemoryOnly: inMemory,
                                               cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// A store at an explicit file location. Used by tests to simulate an app relaunch
    /// (write with one container, then read the same file with a brand-new container).
    static func makeContainer(at url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration("MindBloomTest", schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
