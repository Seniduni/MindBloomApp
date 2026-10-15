import XCTest
@testable import MindBloom

/// Tests for the on-device NaturalLanguage feature.
///
/// Apple's sentiment model can change between OS versions, so these tests check
/// *relationships* (clearly positive text scores higher than clearly negative
/// text; scores stay in range) rather than exact numbers.
final class JournalAnalyzerTests: XCTestCase {
    private let analyzer = JournalAnalyzer()

    private let positive = """
    Today was a wonderful day. I finished my assignment early, my friends surprised me with lunch, \
    and I felt genuinely happy and proud of the progress I am making this semester.
    """

    private let negative = """
    Today was awful. I failed the quiz, missed the bus, argued with my roommate, and felt \
    miserable, exhausted and hopeless about everything I still have to do.
    """

    func testShortTextIsNotAnalysed() {
        let result = analyzer.analyze("Tired today.")
        XCTAssertFalse(result.hasEnoughText)
        XCTAssertNil(result.sentimentScore)
        XCTAssertTrue(result.keywords.isEmpty)
    }

    func testEmptyTextIsHandled() {
        let result = analyzer.analyze("   \n ")
        XCTAssertEqual(result.wordCount, 0)
        XCTAssertFalse(result.hasEnoughText)
    }

    func testEnglishIsDetectedAndWordsCounted() {
        let result = analyzer.analyze(positive)
        XCTAssertTrue(result.hasEnoughText)
        XCTAssertEqual(result.languageCode, "en")
        XCTAssertGreaterThan(result.wordCount, 20)
    }

    func testScoresStayInRangeAndPositiveBeatsNegative() throws {
        let good = try XCTUnwrap(analyzer.analyze(positive).sentimentScore)
        let bad = try XCTUnwrap(analyzer.analyze(negative).sentimentScore)
        XCTAssertTrue((-1...1).contains(good))
        XCTAssertTrue((-1...1).contains(bad))
        XCTAssertGreaterThan(good, bad)
    }

    func testToneThresholds() {
        XCTAssertEqual(JournalAnalyzer.tone(for: 0.6), .leaningPositive)
        XCTAssertEqual(JournalAnalyzer.tone(for: 0.0), .mixedOrNeutral)
        XCTAssertEqual(JournalAnalyzer.tone(for: -0.6), .leaningNegative)
    }

    func testKeywordsComeFromRepeatedMeaningfulWords() {
        let text = "The exam stress is real. Another exam tomorrow, then a library session. The library is quiet and the exam is long."
        let keywords = analyzer.analyze(text).keywords
        XCTAssertTrue(keywords.contains("exam"), "Got \(keywords)")
        XCTAssertTrue(keywords.contains("library"), "Got \(keywords)")
        XCTAssertFalse(keywords.contains("the"))
    }
}
