import XCTest
@testable import MindBloom

final class FocusTimerEngineTests: XCTestCase {
    private let t0 = TestClock.now

    func testNewTimerIsIdleWithFullTimeRemaining() {
        let engine = FocusTimerEngine(plannedMinutes: 25)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.remaining(at: t0), 25 * 60)
        XCTAssertEqual(engine.progress(at: t0), 0)
    }

    func testRunningTimerCountsDownFromTheClock() {
        var engine = FocusTimerEngine(plannedMinutes: 25)
        engine.start(at: t0)
        XCTAssertEqual(engine.state, .running)
        XCTAssertEqual(engine.elapsed(at: t0.addingTimeInterval(90)), 90)
        XCTAssertEqual(engine.remaining(at: t0.addingTimeInterval(90)), 25 * 60 - 90)
    }

    func testPauseFreezesElapsedTimeAndResumeContinues() {
        var engine = FocusTimerEngine(plannedMinutes: 10)
        engine.start(at: t0)
        engine.pause(at: t0.addingTimeInterval(120))
        XCTAssertEqual(engine.state, .paused)
        // Time passing while paused does not count.
        XCTAssertEqual(engine.elapsed(at: t0.addingTimeInterval(1_000)), 120)

        engine.resume(at: t0.addingTimeInterval(1_000))
        XCTAssertEqual(engine.state, .running)
        XCTAssertEqual(engine.elapsed(at: t0.addingTimeInterval(1_030)), 150)
    }

    func testResetReturnsToIdle() {
        var engine = FocusTimerEngine(plannedMinutes: 10)
        engine.start(at: t0)
        engine.reset()
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNil(engine.sessionStart)
        XCTAssertEqual(engine.elapsed(at: t0.addingTimeInterval(60)), 0)
    }

    func testTickFinishesExactlyOnce() {
        var engine = FocusTimerEngine(plannedMinutes: 1)
        engine.start(at: t0)
        XCTAssertFalse(engine.tick(at: t0.addingTimeInterval(59)))
        XCTAssertTrue(engine.tick(at: t0.addingTimeInterval(61)))
        XCTAssertEqual(engine.state, .finished)
        XCTAssertFalse(engine.tick(at: t0.addingTimeInterval(120)), "Second tick must not report finishing again")
        XCTAssertEqual(engine.progress(at: t0.addingTimeInterval(500)), 1)
    }

    func testInvalidTransitionsAreIgnored() {
        var engine = FocusTimerEngine(plannedMinutes: 5)
        engine.pause(at: t0)                       // can't pause when idle
        XCTAssertEqual(engine.state, .idle)
        engine.resume(at: t0)                      // can't resume when idle
        XCTAssertEqual(engine.state, .idle)
        engine.start(at: t0)
        engine.start(at: t0.addingTimeInterval(100))   // second start ignored
        XCTAssertEqual(engine.sessionStart, t0)
        engine.setPlannedMinutes(50)               // can't change length mid-session
        XCTAssertEqual(engine.plannedMinutes, 5)
    }

    func testPlannedMinutesAreClamped() {
        XCTAssertEqual(FocusTimerEngine(plannedMinutes: 0).plannedMinutes, 1)
        XCTAssertEqual(FocusTimerEngine(plannedMinutes: 999).plannedMinutes, 180)
    }

    func testStateSurvivesEncodingLikeAnAppRelaunch() throws {
        var engine = FocusTimerEngine(plannedMinutes: 25)
        engine.start(at: t0)
        let data = try JSONEncoder().encode(engine)
        let restored = try JSONDecoder().decode(FocusTimerEngine.self, from: data)
        XCTAssertEqual(restored, engine)
        // Five minutes "later", the restored timer has kept counting.
        XCTAssertEqual(restored.elapsed(at: t0.addingTimeInterval(300)), 300)
    }

    func testRecordableAfterOneMinute() {
        var engine = FocusTimerEngine(plannedMinutes: 25)
        engine.start(at: t0)
        XCTAssertFalse(engine.isRecordable(at: t0.addingTimeInterval(59)))
        XCTAssertTrue(engine.isRecordable(at: t0.addingTimeInterval(60)))
    }

    func testFormatting() {
        XCTAssertEqual(FocusTimerEngine.format(25 * 60), "25:00")
        XCTAssertEqual(FocusTimerEngine.format(59.2), "01:00")   // rounds up
        XCTAssertEqual(FocusTimerEngine.format(0), "00:00")
        XCTAssertEqual(FocusTimerEngine.format(3_900), "1:05:00")
    }
}
