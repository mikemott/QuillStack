import XCTest

final class QuillStackUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    // MARK: - App Launch

    func testAppLaunches() {
        XCTAssertTrue(app.staticTexts["QUILLSTACK"].exists)
    }

    func testHeaderControlsExist() {
        XCTAssertTrue(app.buttons["toggle-layout"].exists)
        XCTAssertTrue(app.buttons["search-button"].exists)
        XCTAssertTrue(app.buttons["settings-button"].exists)
    }

    func testCaptureButtonExists() {
        XCTAssertTrue(app.buttons["capture-button"].exists)
    }

    func testTagFilterBarVisible() {
        // Tag filter bar renders as a ScrollView — look for tag chips directly
        let expectedTags = ["Receipt", "Event", "Work", "Contact", "Food", "To-Do", "Project", "Ticket", "Reference", "Quote"]
        var foundAny = false
        for tagName in expectedTags {
            let chip = app.staticTexts["#\(tagName.uppercased())"]
            if chip.exists {
                foundAny = true
                break
            }
        }
        XCTAssertTrue(foundAny, "At least one default tag chip should be visible")
    }

    // MARK: - Layout Toggle

    func testToggleLayoutMode() {
        let toggle = app.buttons["toggle-layout"]

        // Default is card mode — toggle to drawer
        toggle.tap()

        // Toggle back to card mode
        toggle.tap()

        // App should still be responsive
        XCTAssertTrue(app.staticTexts["QUILLSTACK"].exists)
    }

    // MARK: - Search

    func testSearchFieldAppearsOnTap() {
        app.buttons["search-button"].tap()

        let searchField = app.textFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
    }

    func testSearchFieldDismisses() {
        app.buttons["search-button"].tap()
        let searchField = app.textFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))

        // Tap search button again to dismiss
        app.buttons["search-button"].tap()

        // Field should disappear
        XCTAssertFalse(searchField.waitForExistence(timeout: 0.5))
    }

    // MARK: - Tag Filtering

    func testMultipleTagsVisible() {
        let expectedTags = ["Receipt", "Event", "Work", "Contact", "Food", "To-Do", "Project", "Ticket", "Reference", "Quote"]
        var count = 0
        for tagName in expectedTags {
            let chip = app.staticTexts["#\(tagName.uppercased())"]
            if chip.exists { count += 1 }
        }
        XCTAssertGreaterThanOrEqual(count, 5, "Most default tags should be visible")
    }

    // MARK: - Settings Navigation

    func testSettingsNavigation() {
        app.buttons["settings-button"].tap()

        // Settings view should appear — check for back button
        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 2))

        backButton.tap()

        // Should be back on main screen
        XCTAssertTrue(app.staticTexts["QUILLSTACK"].waitForExistence(timeout: 2))
    }

    // MARK: - Empty State

    func testEmptyStateShowsNoCards() {
        // In UI testing mode with in-memory store, there should be no captures
        let card = app.otherElements["capture-card"]
        XCTAssertFalse(card.exists)
    }
}
