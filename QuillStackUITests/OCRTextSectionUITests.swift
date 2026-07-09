import XCTest

final class OCRTextSectionUITests: XCTestCase {

    private let sampleLine = "call Sarah about the lease"

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--seed-ocr-capture"]
        app.launch()
    }

    private func openSeededCapture() {
        let card = app.buttons["capture-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Seeded capture card should render")
        card.tap()
    }

    private var recognizedText: XCUIElement {
        app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", sampleLine)
        ).firstMatch
    }

    func testOCRSectionIsCollapsedByDefault() {
        openSeededCapture()

        let toggle = app.buttons["ocr-text-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "OCR toggle should exist for a capture with ocrText")
        XCTAssertFalse(recognizedText.exists, "Recognized text should be hidden until expanded")
    }

    func testOCRSectionExpandsAndShowsRecognizedText() {
        openSeededCapture()

        let toggle = app.buttons["ocr-text-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()

        XCTAssertTrue(recognizedText.waitForExistence(timeout: 2),
                      "Recognized text should be visible after expanding")
    }

    func testOCRToggleCollapsesAgain() {
        openSeededCapture()

        let toggle = app.buttons["ocr-text-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))

        toggle.tap()
        XCTAssertTrue(recognizedText.waitForExistence(timeout: 2))

        toggle.tap()
        XCTAssertFalse(recognizedText.waitForExistence(timeout: 1),
                       "Recognized text should hide on second tap")
    }

    func testShareButtonIsSeparatelyAddressable() {
        let share = app.buttons["capture-share"]
        XCTAssertTrue(share.waitForExistence(timeout: 5),
                      "Share must remain its own accessibility element, not merged into the card")
        XCTAssertEqual(share.label, "Share capture")
    }
}
