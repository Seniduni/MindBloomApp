import XCTest

/// End-to-end UI tests. Every launch passes `-ui-testing`, which makes the app
/// use an in-memory database and clear its preferences, so tests never touch
/// real data and always start from the same state.
final class MindBloomUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ extra: [String] = []) {
        app.launchArguments = ["-ui-testing"] + extra
        app.launch()
    }

    /// Scrolls until the element is hittable (or gives up after a few swipes).
    private func scrollTo(_ element: XCUIElement, maxSwipes: Int = 6) {
        var swipes = 0
        while !element.isHittable && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
    }

    /// Finds any element whose accessibility label contains `text` (rows and cards
    /// combine their child texts into one label for VoiceOver).
    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func openTab(_ name: String) {
        let button = app.tabBars.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Tab \(name) not found")
        button.tap()
    }

    // MARK: Onboarding

    func testOnboardingRequiresAcknowledgementThenShowsToday() {
        launch()
        let continueButton = app.buttons["onboarding.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()
        continueButton.tap()

        let begin = app.buttons["onboarding.begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 3))
        XCTAssertFalse(begin.isEnabled, "Begin must stay disabled until the disclaimer is acknowledged")

        let acknowledge = app.buttons["onboarding.acknowledge"]
        scrollTo(acknowledge)
        acknowledge.tap()
        XCTAssertTrue(begin.isEnabled)
        begin.tap()

        XCTAssertTrue(app.descendants(matching: .any)["today.bloom"].waitForExistence(timeout: 5))
    }

    // MARK: Navigation

    func testAllTabsAreReachable() {
        launch(["-skip-onboarding"])
        for (tab, title) in [("Journal", "Journal"), ("Habits", "Habits"), ("Insights", "Insights"),
                             ("Settings", "Settings"), ("Today", "Today")] {
            openTab(tab)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 3), "\(title) screen did not appear")
        }
    }

    // MARK: Creating records

    func testCreateMoodCheckIn() {
        launch(["-skip-onboarding"])
        let checkIn = app.buttons["today.action.checkin"]
        XCTAssertTrue(checkIn.waitForExistence(timeout: 5))
        checkIn.tap()

        let save = app.buttons["mood.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        XCTAssertFalse(save.isEnabled, "Save is disabled until a feeling is chosen")

        app.buttons["emotion.calm"].tap()
        scrollTo(save)
        XCTAssertTrue(save.isEnabled)
        save.tap()

        // Back on Today, the latest check-in card shows the feeling.
        XCTAssertTrue(element(containing: "Latest check-in").waitForExistence(timeout: 3))
    }

    func testCreateJournalEntry() {
        launch(["-skip-onboarding"])
        openTab("Journal")
        app.buttons["journal.add"].tap()

        let body = app.textViews["journal.body"]
        XCTAssertTrue(body.waitForExistence(timeout: 3))
        body.tap()
        body.typeText("Finished my lab report and went for a walk.")
        app.buttons["journal.save"].tap()

        XCTAssertTrue(element(containing: "Finished my lab report").waitForExistence(timeout: 3))
    }

    func testAddHabitAndMarkDone() {
        launch(["-skip-onboarding"])
        openTab("Habits")
        app.buttons["habits.add"].tap()

        let name = app.textFields["habit.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Stretch")
        app.buttons["habit.save"].tap()

        let toggle = app.buttons["habit.toggle.Stretch"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.tap()
        XCTAssertEqual(toggle.label, "Mark Stretch not done")
    }

    func testDuplicateHabitShowsValidationError() {
        launch(["-skip-onboarding"])
        openTab("Habits")
        for attempt in 0..<2 {
            app.buttons["habits.add"].tap()
            let name = app.textFields["habit.name"]
            XCTAssertTrue(name.waitForExistence(timeout: 3))
            name.tap()
            name.typeText("Water")
            app.buttons["habit.save"].tap()
            if attempt == 1 {
                XCTAssertTrue(app.staticTexts["habit.error"].waitForExistence(timeout: 3))
            }
        }
    }

    // MARK: Sessions

    func testFocusTimerStartPauseResumeReset() {
        launch(["-skip-onboarding"])
        app.buttons["today.action.focus"].tap()

        let start = app.buttons["focus.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        start.tap()

        let pause = app.buttons["focus.pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 3))
        pause.tap()

        let resume = app.buttons["focus.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 3))
        resume.tap()
        XCTAssertTrue(pause.waitForExistence(timeout: 3))

        // Under one minute, reset happens immediately without a save prompt.
        app.buttons["focus.reset"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 3))
    }

    func testCompleteShortBreathingSession() {
        launch(["-skip-onboarding"])
        app.buttons["today.action.breathe"].tap()

        let shortOption = app.buttons["breathing.duration.12"]   // only offered when -ui-testing is set
        XCTAssertTrue(shortOption.waitForExistence(timeout: 3))
        shortOption.tap()
        app.buttons["breathing.start"].tap()

        XCTAssertTrue(app.staticTexts["breathing.phase"].waitForExistence(timeout: 3))
        let result = app.staticTexts["breathing.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 25))
        XCTAssertEqual(result.label, "Session complete")
    }

    // MARK: Insights with sample data

    func testInsightsShowHighlightsWithSampleData() {
        launch(["-skip-onboarding", "-seed-sample-data"])
        openTab("Insights")
        let highlights = app.descendants(matching: .any)["insights.highlights"]
        scrollTo(highlights)
        XCTAssertTrue(highlights.waitForExistence(timeout: 5))
    }
}
