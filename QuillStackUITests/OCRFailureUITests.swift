import XCTest

/// Before this, a failed OCR was completely invisible: no error, no badge, and
/// no way to re-run. The capture was permanently dead.
final class OCRFailureUITests: XCTestCase {

    private func launch(_ extraArgs: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"] + extraArgs
        app.launch()
        return app
    }

    private func openCard(_ app: XCUIApplication) {
        let card = app.buttons["capture-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Seeded capture should render")
        card.tap()
    }

    // MARK: - Retryable failure

    func testFailedCaptureShowsBadgeOnCard() {
        let app = launch(["--seed-ocr-failure"])
        let card = app.buttons["capture-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("Text recognition failed"),
                      "Card should announce the failure; got: \(card.label)")
    }

    func testFailedCaptureShowsMessageAndRetry() {
        let app = launch(["--seed-ocr-failure"])
        openCard(app)

        let message = app.staticTexts["ocr-status-message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertEqual(message.label, "Text recognition didn't finish.")
        XCTAssertTrue(app.buttons["ocr-retry"].exists, "A transient failure must offer Retry")
    }

    /// The seeded image is blank grey, so re-running Vision yields .noTextFound —
    /// a non-retryable outcome. A working Retry therefore removes its own button.
    func testRetryActuallyReprocessesAndUpdatesState() {
        let app = launch(["--seed-ocr-failure"])
        openCard(app)

        let retry = app.buttons["ocr-retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        retry.tap()

        let message = app.staticTexts["ocr-status-message"]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "No text recognized in this image."),
            object: message
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 20), .completed,
                       "Retry should re-run OCR and record the new outcome")
        XCTAssertFalse(app.buttons["ocr-retry"].exists,
                       "A deterministic outcome must not offer a Retry that cannot work")
    }

    // MARK: - Non-error outcome

    func testNoTextFoundIsInformationalNotAnError() {
        let app = launch(["--seed-no-text"])

        let card = app.buttons["capture-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertFalse(card.label.contains("Text recognition failed"),
                       "A photo with no readable text is not a failure")

        card.tap()
        let message = app.staticTexts["ocr-status-message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertEqual(message.label, "No text recognized in this image.")
        XCTAssertFalse(app.buttons["ocr-retry"].exists,
                       "Re-running Vision on the same bytes cannot find text that isn't there")
    }

    // MARK: - Healthy capture

    func testSuccessfulCaptureShowsNoStatusSection() {
        let app = launch(["--seed-ocr-capture"])
        openCard(app)

        XCTAssertTrue(app.buttons["ocr-text-toggle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["ocr-status-message"].exists,
                       "A healthy capture should show no error chrome")
    }
}
