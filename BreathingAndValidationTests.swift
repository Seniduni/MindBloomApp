import XCTest
@testable import MindBloom

final class BreathingPatternTests: XCTestCase {
    func testCycleDurations() {
        XCTAssertEqual(BreathingPattern.balanced.cycleDuration, 10)
        XCTAssertEqual(BreathingPattern.box.cycleDuration, 16)
        XCTAssertEqual(BreathingPattern.longExhale.cycleDuration, 10)
    }

    func testBoxBreathingPhasesOverTime() {
        let box = BreathingPattern.box
        XCTAssertEqual(box.progress(atElapsed: 0).phase, .inhale)
        XCTAssertEqual(box.progress(atElapsed: 5).phase, .holdIn)
        XCTAssertEqual(box.progress(atElapsed: 9).phase, .exhale)
        XCTAssertEqual(box.progress(atElapsed: 13).phase, .holdOut)
        let secondCycle = box.progress(atElapsed: 17)
        XCTAssertEqual(secondCycle.phase, .inhale)
        XCTAssertEqual(secondCycle.completedCycles, 1)
        XCTAssertEqual(secondCycle.phaseFraction, 0.25, accuracy: 0.0001)
        XCTAssertEqual(secondCycle.secondsLeftInPhase, 3, accuracy: 0.0001)
    }

    func testNegativeElapsedIsTreatedAsStart() {
        let progress = BreathingPattern.balanced.progress(atElapsed: -5)
        XCTAssertEqual(progress.phase, .inhale)
        XCTAssertEqual(progress.completedCycles, 0)
    }

    func testOrbScaleStaysInRangeAndPeaksAfterInhale() {
        let pattern = BreathingPattern.longExhale
        for tenth in 0..<100 {
            let scale = BreathingPattern.orbScale(for: pattern.progress(atElapsed: Double(tenth) / 10))
            XCTAssertTrue((0.55...1.0).contains(scale))
        }
        let endOfInhale = BreathingPattern.orbScale(for: pattern.progress(atElapsed: 3.999))
        XCTAssertEqual(endOfInhale, 1.0, accuracy: 0.01)
    }
}

final class InputValidatorTests: XCTestCase {
    func testIntensityIsClamped() {
        XCTAssertEqual(InputValidator.clampIntensity(0), 1)
        XCTAssertEqual(InputValidator.clampIntensity(3), 3)
        XCTAssertEqual(InputValidator.clampIntensity(9), 5)
    }

    func testSanitizedTrimsAndTruncates() {
        XCTAssertEqual(InputValidator.sanitized("  hello \n", maxLength: 10), "hello")
        XCTAssertEqual(InputValidator.sanitized("abcdefghij", maxLength: 4), "abcd")
    }

    func testHabitNameRules() throws {
        XCTAssertEqual(try InputValidator.validatedHabitName("  Walk  ", existingNames: []), "Walk")
        XCTAssertThrowsError(try InputValidator.validatedHabitName("   ", existingNames: [])) {
            XCTAssertEqual($0 as? ValidationError, .emptyHabitName)
        }
        XCTAssertThrowsError(try InputValidator.validatedHabitName(String(repeating: "a", count: 41), existingNames: [])) {
            XCTAssertEqual($0 as? ValidationError, .habitNameTooLong(limit: 40))
        }
        XCTAssertThrowsError(try InputValidator.validatedHabitName("drink WATER", existingNames: ["Drink water"])) {
            XCTAssertEqual($0 as? ValidationError, .duplicateHabit)
        }
    }

    func testJournalNeedsBodyAndGetsDefaultTitle() throws {
        XCTAssertThrowsError(try InputValidator.validatedJournal(title: "Title", body: "  \n ", date: TestClock.now))
        let result = try InputValidator.validatedJournal(title: "", body: "Some words", date: TestClock.now)
        XCTAssertTrue(result.title.hasPrefix("Reflection"))
        XCTAssertEqual(result.body, "Some words")
    }
}

final class KeywordExtractorTests: XCTestCase {
    func testRanksByFrequencyAndSkipsStopWords() {
        let words = ["The", "exam", "was", "hard", "exam", "library", "and", "library", "exam", "tea"]
        XCTAssertEqual(KeywordExtractor.topKeywords(from: words, limit: 3), ["exam", "library", "hard"])
    }

    func testIgnoresShortWordsNumbersAndPunctuation() {
        XCTAssertEqual(KeywordExtractor.topKeywords(from: ["ok", "42", "...", "calm!"]), ["calm"])
    }

    func testLimitAndEmptyInput() {
        XCTAssertEqual(KeywordExtractor.topKeywords(from: [], limit: 5), [])
        XCTAssertEqual(KeywordExtractor.topKeywords(from: ["alpha", "beta"], limit: 0), [])
    }
}

final class WellnessStatsTests: XCTestCase {
    private let calendar = TestClock.calendar

    func testMinutesPerDayIsZeroFilled() {
        let sessions = [StubSession(startedAt: TestClock.daysAgo(0), durationSeconds: 1_500, wasCompleted: true),
                        StubSession(startedAt: TestClock.daysAgo(0, hour: 15), durationSeconds: 300, wasCompleted: false),
                        StubSession(startedAt: TestClock.daysAgo(2), durationSeconds: 600, wasCompleted: true)]
        let series = WellnessStats.minutesPerDay(sessions, lastDays: 3, endingOn: TestClock.now, calendar: calendar)
        XCTAssertEqual(series.map(\.value), [10, 0, 30])
        XCTAssertEqual(WellnessStats.totalMinutes(sessions, lastDays: 7, endingOn: TestClock.now, calendar: calendar), 40)
        XCTAssertEqual(WellnessStats.completedCount(sessions, lastDays: 7, endingOn: TestClock.now, calendar: calendar), 2)
    }

    func testDailyRitualStatus() {
        let status = DailyRitualStatus.evaluate(moodTimes: [TestClock.now],
                                                breathingTimes: [TestClock.daysAgo(1)],
                                                focusTimes: [TestClock.now],
                                                habitCount: 2, habitsCompletedToday: 2,
                                                today: TestClock.now, calendar: calendar)
        XCTAssertTrue(status.checkedIn)
        XCTAssertFalse(status.breathed, "Yesterday's breathing doesn't count for today")
        XCTAssertTrue(status.focused)
        XCTAssertTrue(status.habitsDone)
        XCTAssertEqual(status.completedCount, 3)
        XCTAssertEqual(status.progress, 0.75)
    }

    func testHabitsRitualNeedsAtLeastOneHabit() {
        let status = DailyRitualStatus.evaluate(moodTimes: [], breathingTimes: [], focusTimes: [],
                                                habitCount: 0, habitsCompletedToday: 0,
                                                today: TestClock.now, calendar: calendar)
        XCTAssertFalse(status.habitsDone)
        XCTAssertEqual(status.completedCount, 0)
    }
}
