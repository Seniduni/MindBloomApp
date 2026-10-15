import XCTest
@testable import MindBloom

/// Checks that the focus timer is saved and restored across "relaunches"
/// (a new model reading the same UserDefaults).
@MainActor
final class FocusTimerModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "MindBloomTests.FocusTimer"

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRunningTimerIsRestored() {
        let first = FocusTimerModel(defaults: defaults)
        first.setPlannedMinutes(15)
        first.start()

        let relaunched = FocusTimerModel(defaults: defaults)
        XCTAssertEqual(relaunched.state, .running)
        XCTAssertEqual(relaunched.plannedMinutes, 15)
    }

    func testTimerThatEndedWhileClosedFinishesOnFirstRefresh() throws {
        let first = FocusTimerModel(defaults: defaults)
        first.setPlannedMinutes(1)
        first.start()

        let relaunched = FocusTimerModel(defaults: defaults)
        XCTAssertTrue(relaunched.refresh(at: Date.now.addingTimeInterval(120)))
        XCTAssertEqual(relaunched.state, .finished)
        XCTAssertFalse(relaunched.refresh(at: Date.now.addingTimeInterval(180)))
    }

    func testPauseAndResetArePersisted() {
        let model = FocusTimerModel(defaults: defaults)
        model.start()
        model.pause()
        XCTAssertEqual(FocusTimerModel(defaults: defaults).state, .paused)
        model.reset()
        XCTAssertEqual(FocusTimerModel(defaults: defaults).state, .idle)
    }
}
