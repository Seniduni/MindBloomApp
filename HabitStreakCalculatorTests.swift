import XCTest
@testable import MindBloom

final class HabitStreakCalculatorTests: XCTestCase {
    private let calendar = TestClock.calendar
    private let now = TestClock.now

    private func days(_ offsets: [Int]) -> Set<Date> {
        HabitStreakCalculator.normalizedDays(offsets.map { TestClock.daysAgo($0, hour: 9) }, calendar: calendar)
    }

    func testStreakCountsBackFromToday() {
        XCTAssertEqual(HabitStreakCalculator.currentStreak(completedDays: days([0, 1, 2]), today: now, calendar: calendar), 3)
    }

    func testStreakStaysAliveUntilTodayIsOver() {
        // Not done yet today, but done the three previous days.
        XCTAssertEqual(HabitStreakCalculator.currentStreak(completedDays: days([1, 2, 3]), today: now, calendar: calendar), 3)
    }

    func testStreakBreaksAfterAMissedDay() {
        XCTAssertEqual(HabitStreakCalculator.currentStreak(completedDays: days([2, 3, 4]), today: now, calendar: calendar), 0)
        XCTAssertEqual(HabitStreakCalculator.currentStreak(completedDays: days([0, 2, 3]), today: now, calendar: calendar), 1)
    }

    func testEmptyHistory() {
        XCTAssertEqual(HabitStreakCalculator.currentStreak(completedDays: [], today: now, calendar: calendar), 0)
        XCTAssertEqual(HabitStreakCalculator.longestStreak(completedDays: [], calendar: calendar), 0)
    }

    func testLongestStreakFindsBestRun() {
        XCTAssertEqual(HabitStreakCalculator.longestStreak(completedDays: days([0, 1, 5, 6, 7, 8, 12]), calendar: calendar), 4)
    }

    func testDuplicateTimestampsOnOneDayCountOnce() {
        let sameDay = [TestClock.daysAgo(0, hour: 8), TestClock.daysAgo(0, hour: 21)]
        XCTAssertEqual(HabitStreakCalculator.normalizedDays(sameDay, calendar: calendar).count, 1)
    }

    func testCompletionRate() {
        let rate = HabitStreakCalculator.completionRate(completedDays: days([0, 2, 4, 20]), lastDays: 7, endingOn: now, calendar: calendar)
        XCTAssertEqual(rate, 3.0 / 7.0, accuracy: 0.0001)
    }

    func testDailyCompletionRatio() {
        // Two habits; today both done, yesterday one done.
        let completions = [TestClock.daysAgo(0), TestClock.daysAgo(0, hour: 18), TestClock.daysAgo(1)]
        let series = HabitStreakCalculator.dailyCompletionRatio(completionDays: completions, habitCount: 2,
                                                                lastDays: 3, endingOn: now, calendar: calendar)
        XCTAssertEqual(series.map(\.value), [0, 0.5, 1])
    }

    func testDailyCompletionRatioWithNoHabitsIsZero() {
        let series = HabitStreakCalculator.dailyCompletionRatio(completionDays: [TestClock.now], habitCount: 0,
                                                                lastDays: 7, endingOn: now, calendar: calendar)
        XCTAssertEqual(series.count, 7)
        XCTAssertTrue(series.allSatisfy { $0.value == 0 })
    }

    func testFutureDaysCannotBeToggled() {
        XCTAssertTrue(HabitStreakCalculator.canToggle(day: TestClock.daysAgo(3), today: now, calendar: calendar))
        XCTAssertTrue(HabitStreakCalculator.canToggle(day: now, today: now, calendar: calendar))
        XCTAssertFalse(HabitStreakCalculator.canToggle(day: TestClock.daysAgo(-1), today: now, calendar: calendar))
    }
}
