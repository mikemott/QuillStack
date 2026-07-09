import XCTest

/// Drives the store-failure path via --fail-store (DEBUG only). Before this,
/// a failed ModelContainer hit fatalError() and the app died on launch.
final class StorageRecoveryUITests: XCTestCase {

    private func launch(failStore: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = failStore
            ? ["--uitesting", "--fail-store"]
            : ["--uitesting"]
        app.launch()
        return app
    }

    func testAppDoesNotCrashWhenStoreFails() {
        let app = launch(failStore: true)
        XCTAssertTrue(app.staticTexts["storage-unavailable"].waitForExistence(timeout: 5),
                      "Recovery screen should render instead of crashing")
        XCTAssertEqual(app.state, .runningForeground, "App must stay alive")
    }

    func testRecoveryScreenExplainsDataIsSafe() {
        let app = launch(failStore: true)
        XCTAssertTrue(app.staticTexts["Storage unavailable"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS 'have not been deleted'")
            ).firstMatch.exists,
            "User must be told their captures are intact"
        )
    }

    func testRetryButtonExistsAndIsTappable() {
        let app = launch(failStore: true)
        let retry = app.buttons["storage-retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        retry.tap()
        // --fail-store keeps failing, so we stay on the recovery screen rather than crash.
        XCTAssertTrue(app.staticTexts["storage-unavailable"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testDiagnosticsAreCollapsedThenExpandable() {
        let app = launch(failStore: true)
        let toggle = app.buttons["storage-diagnostics-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))

        let detail = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Simulated store failure'")
        ).firstMatch
        XCTAssertFalse(detail.exists, "Diagnostics should start collapsed")

        toggle.tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 2), "Diagnostics should expand")
    }

    func testNormalLaunchShowsNoRecoveryScreen() {
        let app = launch(failStore: false)
        XCTAssertTrue(app.staticTexts["header-title"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["storage-unavailable"].exists)
    }
}
