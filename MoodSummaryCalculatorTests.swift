import XCTest
@testable import MindBloom

final class MoodSummaryCalculatorTests: XCTestCase {
    private let calendar = TestClock.calendar
    private let now = TestClock.now

    func testEmptyInputGivesEmptySummary() {
        let summary = MoodSummaryCalculator.summary(for: [StubMood](), lastDays: 7, endingOn: now, calendar: calendar)
        XCTAssertEqual(summary, .empty)
        XCTAssertNil(summary.averageScore)
        XCTAssertEqual(summary.trend, .insufficientData)
    }

    func testAveragesUseValenceMappedToOneToFive() {
        // joyful = 5, sad = 1 → average 3. Intensities 4 and 2 → average 3.
        let records = [StubMood(timestamp: TestClock.daysAgo(1), emotion: .joyful, intensity: 4),
                       StubMood(timestamp: TestClock.daysAgo(2), emotion: .sad, intensity: 2)]
        let summary = MoodSummaryCalculator.summary(for: records, lastDays: 7, endingOn: now, calendar: calendar)
        XCTAssertEqual(summary.checkInCount, 2)
        XCTAssertEqual(summary.daysWithCheckIns, 2)
        XCTAssertEqual(summary.averageScore ?? 0, 3, accuracy: 0.0001)
        XCTAssertEqual(summary.averageIntensity ?? 0, 3, accuracy: 0.0001)
    }

    func testRecordsOutsideTheWindowAreIgnored() {
        let records = [StubMood(timestamp: TestClock.daysAgo(0), emotion: .calm, intensity: 3),
                       StubMood(timestamp: TestClock.daysAgo(6), emotion: .calm, intensity: 3),
                       StubMood(timestamp: TestClock.daysAgo(7), emotion: .sad, intensity: 3),   // 8th day back: outside
                       StubMood(timestamp: TestClock.daysAgo(-1), emotion: .sad, intensity: 3)]  // tomorrow: outside
        let summary = MoodSummaryCalculator.summary(for: records, lastDays: 7, endingOn: now, calendar: calendar)
        XCTAssertEqual(summary.checkInCount, 2)
        XCTAssertEqual(summary.emotionCounts[.calm], 2)
        XCTAssertNil(summary.emotionCounts[.sad])
    }

    func testDailyAveragesGroupSeveralCheckInsOnOneDay() {
        let records = [StubMood(timestamp: TestClock.daysAgo(1, hour: 8), emotion: .joyful, intensity: 3),   // 5
                       StubMood(timestamp: TestClock.daysAgo(1, hour: 20), emotion: .okay, intensity: 3)]    // 3
        let summary = MoodSummaryCalculator.summary(for: records, lastDays: 7, endingOn: now, calendar: calendar)
        XCTAssertEqual(summary.dailyAverages.count, 1)
        XCTAssertEqual(summary.dailyAverages.first?.value ?? 0, 4, accuracy: 0.0001)
    }

    func testMostFrequentEmotionBreaksTiesByDeclarationOrder() {
        XCTAssertEqual(MoodSummaryCalculator.mostFrequent(in: [.calm: 2, .joyful: 2, .sad: 1]), .joyful)
        XCTAssertEqual(MoodSummaryCalculator.mostFrequent(in: [.tired: 3, .calm: 1]), .tired)
        XCTAssertNil(MoodSummaryCalculator.mostFrequent(in: [:]))
    }

    func testTrendNeedsFourDays() {
        let three = (1...3).map { DailyValue(day: TestClock.daysAgo($0), value: 3) }
        XCTAssertEqual(MoodSummaryCalculator.trend(for: three), .insufficientData)
    }

    func testTrendDetectsImprovementAndDip() {
        let improving = [2.0, 2.0, 4.0, 4.0].enumerated().map { DailyValue(day: TestClock.daysAgo(4 - $0.offset), value: $0.element) }
        XCTAssertEqual(MoodSummaryCalculator.trend(for: improving), .improving)

        let dipping = [4.0, 4.0, 2.5, 2.5].enumerated().map { DailyValue(day: TestClock.daysAgo(4 - $0.offset), value: $0.element) }
        XCTAssertEqual(MoodSummaryCalculator.trend(for: dipping), .dipping)

        let steady = [3.0, 3.2, 3.1, 3.3].enumerated().map { DailyValue(day: TestClock.daysAgo(4 - $0.offset), value: $0.element) }
        XCTAssertEqual(MoodSummaryCalculator.trend(for: steady), .steady)
    }

    func testScoreLabels() {
        XCTAssertEqual(MoodSummaryCalculator.label(forScore: 1.0), "Heavy")
        XCTAssertEqual(MoodSummaryCalculator.label(forScore: 3.0), "Balanced")
        XCTAssertEqual(MoodSummaryCalculator.label(forScore: 5.0), "Bright")
    }

    func testEveryEmotionHasAValidScore() {
        for emotion in Emotion.allCases {
            XCTAssertTrue((1.0...5.0).contains(emotion.moodScore), "\(emotion) out of range")
        }
    }
}
