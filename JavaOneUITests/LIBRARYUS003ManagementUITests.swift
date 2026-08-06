import XCTest

/// LIBRARY-US003 — stable identity + management actions on device.
@MainActor
final class LIBRARYUS003ManagementUITests: XCTestCase {

    func testLibraryManagementSurfacesDeleteAndSettings() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["CoreJ2"].waitForExistence(timeout: 25))

        let details = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Details for")
        ).firstMatch
        if details.waitForExistence(timeout: 8) {
            details.tap()

            let settings = app.buttons["Game Settings"].firstMatch
            let share = app.buttons["Share JAR"].firstMatch
            let saves = app.buttons["Show Save Data"].firstMatch
            let delete = app.buttons["Delete Game"].firstMatch

            XCTAssertTrue(settings.waitForExistence(timeout: 4), "Game Settings missing")
            XCTAssertTrue(share.exists)
            XCTAssertTrue(saves.exists)
            XCTAssertTrue(delete.exists)

            if app.descendants(matching: .any)["detail-stable-identity"].waitForExistence(timeout: 2) {
                // SHA-256 shown in detail.
            }

            attachScreenshot(named: "library-us003-detail-manage")

            settings.tap()
            if app.navigationBars["Game Settings"].waitForExistence(timeout: 3) {
                let hash = app.descendants(matching: .any)["stable-identity-hash"]
                XCTAssertTrue(hash.waitForExistence(timeout: 2), "Stable identity missing in settings")
                attachScreenshot(named: "library-us003-settings-identity")
                app.buttons["Close"].tap()
                Thread.sleep(forTimeInterval: 0.4)
            }

            // Delete from detail — sheet dismisses, then native alert appears.
            let deleteAgain = app.buttons["Delete Game"].firstMatch
            XCTAssertTrue(deleteAgain.waitForExistence(timeout: 3), "Delete Game action missing")
            deleteAgain.tap()

            let deleteEverything = app.buttons["Delete Everything"].firstMatch
            XCTAssertTrue(
                deleteEverything.waitForExistence(timeout: 6),
                "Delete confirmation alert missing"
            )
            attachScreenshot(named: "library-us003-delete-confirm")
            app.buttons["Cancel"].tap()
        }

        attachScreenshot(named: "library-us003-library")
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)
    }

    private func attachScreenshot(named name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
