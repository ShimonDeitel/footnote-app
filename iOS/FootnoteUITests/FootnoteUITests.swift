import XCTest

/// Smoke UI tests that tap through every tab without requiring microphone access.
final class FootnoteUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launch(pro: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FOOTNOTE_NO_SK"] = "1"   // no StoreKit sign-in prompt
        app.launchEnvironment["FOOTNOTE_SEED"] = "1"    // one structured note in the archive
        if pro { app.launchEnvironment["FOOTNOTE_FORCE_PRO"] = "1" }
        app.launch()
        return app
    }

    func testTabsExistAndSwitch() {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Record"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Notes"].tap()
        app.tabBars.buttons["Ask"].tap()
        app.tabBars.buttons["Commitments"].tap()
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }

    func testSeededNoteOpens() {
        let app = launch()
        app.tabBars.buttons["Notes"].tap()
        // The seeded note title should appear and open into the detail.
        let cell = app.staticTexts["Q3 Pricing Review"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        XCTAssertTrue(app.staticTexts["Decisions"].waitForExistence(timeout: 3)
                      || app.navigationBars.element.waitForExistence(timeout: 3))
    }

    func testCommitmentsProShowsRollup() {
        let app = launch(pro: true)
        app.tabBars.buttons["Commitments"].tap()
        XCTAssertTrue(app.navigationBars["Commitments"].waitForExistence(timeout: 5))
    }

    /// Drives a REAL local StoreKit sandbox purchase (Footnote.storekit config, zero real money):
    /// Settings -> Footnote Pro row -> paywall -> Subscribe -> confirm the system purchase sheet
    /// -> assert the "Footnote Pro is active" state is reached.
    func testPurchaseFlowUnlocksPro() {
        let app = XCUIApplication()
        // Deliberately do NOT set FOOTNOTE_NO_SK so the app fetches the real product from the
        // .storekit config, and do NOT force pro — this exercises the actual purchase() call.
        app.launchEnvironment["FOOTNOTE_SEED"] = "1"
        app.launch()

        addUIInterruptionMonitor(withDescription: "StoreKit purchase sheet") { alert in
            for label in ["Subscribe", "Confirm", "OK"] {
                let button = alert.buttons[label]
                if button.exists { button.tap(); return true }
            }
            return false
        }

        app.tabBars.buttons["Settings"].tap()
        let proRow = app.staticTexts["Footnote Pro"]
        XCTAssertTrue(proRow.waitForExistence(timeout: 5))
        proRow.tap()

        let subscribeButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Subscribe'")).firstMatch
        XCTAssertTrue(subscribeButton.waitForExistence(timeout: 10), "Subscribe button never appeared — product likely failed to load from Footnote.storekit")
        subscribeButton.tap()

        // Nudge the interruption monitor — XCUITest only checks it on the next interaction.
        app.tap()
        sleep(2)
        app.tap()

        let activeLabel = app.staticTexts["Footnote Pro is active"]
        XCTAssertTrue(activeLabel.waitForExistence(timeout: 15), "Pro was not unlocked after completing the sandbox purchase")
    }
}
