import XCTest
import SwiftData
@testable import MindBloom

/// Exercises `WellnessRepository` and `DemoDataService` against a real SwiftData
/// stack. Each test gets a fresh in-memory container, so tests are isolated.
@MainActor
final class PersistenceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var repository: WellnessRepository { WellnessRepository(context: context) }

    override func setUp() async throws {
        container = try PersistenceController.makeContainer(inMemory: true)
    }

    override func tearDown() async throws {
        container = nil
    }

    private func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    // MARK: Mood

    func testSaveAndFetchMood() throws {
        try repository.addMood(emotion: .calm, intensity: 9, note: "  after the lecture  ", factors: [.study])
        let moods = try context.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(moods.count, 1)
        XCTAssertEqual(moods.first?.emotion, .calm)
        XCTAssertEqual(moods.first?.intensity, 5, "Intensity is clamped to 1...5")
        XCTAssertEqual(moods.first?.note, "after the lecture", "Note is trimmed")
        XCTAssertEqual(moods.first?.factors, [.study])
    }

    func testUnknownStoredEmotionFallsBackSafely() throws {
        let entry = MoodEntry(emotion: .joyful, intensity: 3)
        entry.emotionRaw = "not-a-real-emotion"
        XCTAssertEqual(entry.emotion, .okay)
    }

    // MARK: Journal

    func testJournalCreateEditDelete() throws {
        let created = try repository.saveJournal(existing: nil, title: "", body: "First draft",
                                                 prompt: "", now: TestClock.now)
        XCTAssertTrue(created.title.hasPrefix("Reflection"))

        let later = TestClock.now.addingTimeInterval(3_600)
        try repository.saveJournal(existing: created, title: "Edited", body: "Second draft", prompt: "", now: later)
        let entries = try context.fetch(FetchDescriptor<JournalEntry>())
        XCTAssertEqual(entries.count, 1, "Editing updates in place rather than creating a copy")
        XCTAssertEqual(entries.first?.title, "Edited")
        XCTAssertEqual(entries.first?.body, "Second draft")
        XCTAssertEqual(entries.first?.updatedAt, later)
        XCTAssertEqual(entries.first?.createdAt, TestClock.now)

        try repository.delete(created)
        XCTAssertEqual(try count(JournalEntry.self), 0)
    }

    func testEmptyJournalIsRejected() {
        XCTAssertThrowsError(try repository.saveJournal(existing: nil, title: "Title", body: "   ", prompt: ""))
        XCTAssertEqual(try count(JournalEntry.self), 0)
    }

    // MARK: Habits

    func testAddHabitRejectsDuplicates() throws {
        try repository.addHabit(name: "Drink water", symbolName: "drop.fill", tint: .teal)
        XCTAssertThrowsError(try repository.addHabit(name: "drink water", symbolName: "drop.fill", tint: .sky))
        XCTAssertEqual(try count(Habit.self), 1)
    }

    func testToggleHabitCreatesAndRemovesCompletion() throws {
        let habit = try repository.addHabit(name: "Walk", symbolName: "figure.walk", tint: .mint)
        let today = Date.now

        XCTAssertTrue(try repository.toggleHabit(habit, on: today, today: today))
        XCTAssertTrue(habit.isCompleted(on: today))
        XCTAssertEqual(try count(HabitCompletion.self), 1)

        XCTAssertFalse(try repository.toggleHabit(habit, on: today, today: today))
        XCTAssertFalse(habit.isCompleted(on: today))
        XCTAssertEqual(try count(HabitCompletion.self), 0)
    }

    func testFutureDayToggleIsIgnored() throws {
        let habit = try repository.addHabit(name: "Read", symbolName: "book.fill", tint: .sky)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        XCTAssertFalse(try repository.toggleHabit(habit, on: tomorrow, today: .now))
        XCTAssertEqual(try count(HabitCompletion.self), 0)
    }

    func testDeletingHabitCascadesToCompletions() throws {
        let habit = try repository.addHabit(name: "Stretch", symbolName: "figure.walk", tint: .peach)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        try repository.toggleHabit(habit, on: .now)
        try repository.toggleHabit(habit, on: yesterday)
        XCTAssertEqual(habit.currentStreak(), 2)

        try repository.delete(habit)
        XCTAssertEqual(try count(Habit.self), 0)
        XCTAssertEqual(try count(HabitCompletion.self), 0)
    }

    // MARK: Sessions

    func testRecordSessions() throws {
        try repository.recordFocusSession(startedAt: TestClock.now, endedAt: TestClock.now.addingTimeInterval(1_500),
                                          plannedMinutes: 25, focusedSeconds: 1_500, completed: true, intention: "Essay")
        try repository.recordBreathingSession(startedAt: TestClock.now, seconds: 180, pattern: .box,
                                              cycles: 11, completed: true)
        let focus = try context.fetch(FetchDescriptor<FocusSession>())
        let breathing = try context.fetch(FetchDescriptor<BreathingSession>())
        XCTAssertEqual(focus.first?.durationSeconds, 1_500)
        XCTAssertEqual(focus.first?.intention, "Essay")
        XCTAssertEqual(breathing.first?.pattern, .box)
        XCTAssertEqual(breathing.first?.cyclesCompleted, 11)
    }

    // MARK: Sample data

    func testSampleDataLoadsAndRemovesWithoutTouchingUserData() throws {
        try repository.addMood(emotion: .grateful, intensity: 3, note: "mine", factors: [])
        try repository.addHabit(name: "My own habit", symbolName: "leaf.fill", tint: .teal)

        try DemoDataService.loadSampleData(into: context, now: .now)
        XCTAssertTrue(DemoDataService.hasSampleData(in: context))
        XCTAssertGreaterThan(try count(MoodEntry.self), 10)
        XCTAssertGreaterThan(try count(FocusSession.self), 0)
        XCTAssertGreaterThan(try count(BreathingSession.self), 0)
        XCTAssertEqual(try count(JournalEntry.self), 5)

        // Loading twice replaces rather than duplicates.
        let moodsAfterFirstLoad = try count(MoodEntry.self)
        try DemoDataService.loadSampleData(into: context, now: .now)
        XCTAssertEqual(try count(MoodEntry.self), moodsAfterFirstLoad)

        try DemoDataService.removeSampleData(from: context)
        XCTAssertFalse(DemoDataService.hasSampleData(in: context))
        let remainingMoods = try context.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(remainingMoods.map(\.note), ["mine"])
        XCTAssertEqual(try context.fetch(FetchDescriptor<Habit>()).map(\.name), ["My own habit"])
        XCTAssertEqual(try count(HabitCompletion.self), 0)
    }

    func testDeleteAllData() throws {
        try DemoDataService.loadSampleData(into: context, now: .now)
        try repository.deleteAllData()
        XCTAssertEqual(try count(MoodEntry.self), 0)
        XCTAssertEqual(try count(Habit.self), 0)
        XCTAssertEqual(try count(HabitCompletion.self), 0)
        XCTAssertEqual(try count(JournalEntry.self), 0)
        XCTAssertEqual(try count(FocusSession.self), 0)
        XCTAssertEqual(try count(BreathingSession.self), 0)
    }

    func testExportContainsStoredRecords() throws {
        try repository.addMood(emotion: .calm, intensity: 2, note: "", factors: [])
        let export = try DataExportService.makeExport(from: context)
        XCTAssertEqual(export.moods.count, 1)
        XCTAssertEqual(export.moods.first?.emotion, "calm")
    }
}

/// Writes to a store on disk, discards the container, then opens the same file
/// with a brand-new container — the same thing that happens when the app relaunches.
@MainActor
final class RelaunchPersistenceTests: XCTestCase {
    func testDataSurvivesANewContainer() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("relaunch-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
            }
        }

        do {
            let first = try PersistenceController.makeContainer(at: url)
            let repository = WellnessRepository(context: first.mainContext)
            try repository.addMood(emotion: .motivated, intensity: 4, note: "before relaunch", factors: [.exams])
            let habit = try repository.addHabit(name: "Water", symbolName: "drop.fill", tint: .teal)
            try repository.toggleHabit(habit, on: .now)
        }

        let second = try PersistenceController.makeContainer(at: url)
        let moods = try second.mainContext.fetch(FetchDescriptor<MoodEntry>())
        let habits = try second.mainContext.fetch(FetchDescriptor<Habit>())
        XCTAssertEqual(moods.first?.note, "before relaunch")
        XCTAssertEqual(moods.first?.factors, [.exams])
        XCTAssertEqual(habits.first?.completions.count, 1)
        XCTAssertTrue(habits.first?.isCompleted(on: .now) ?? false)
    }
}
