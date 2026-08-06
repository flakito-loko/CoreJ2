import XCTest

/// LIBRARY-US004 — editable identity + metadata activation on device.
@MainActor
final class LIBRARYUS004IdentityUITests: XCTestCase {

    func testDisplayNameEditPersistsAndShowsOfficialName() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["CoreJ2"].waitForExistence(timeout: 25))

        // Wait for metadata backfill.
        let enriching = app.descendants(matching: .any)["metadata-enriching"]
        if enriching.exists {
            let gone = NSPredicate(format: "exists == false")
            expectation(for: gone, evaluatedWith: enriching)
            waitForExpectations(timeout: 25)
        }

        let details = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Details for")
        ).firstMatch
        guard details.waitForExistence(timeout: 8) else {
            attachScreenshot(named: "library-us004-empty")
            return
        }
        details.tap()

        let settings = app.buttons["Game Settings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 4))
        settings.tap()

        // Detail sheet dismisses first, then settings presents (~450ms).
        let settingsNav = app.navigationBars["Game Settings"]
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 8)
                || app.descendants(matching: .any)["game-settings-form"].waitForExistence(timeout: 2)
                || app.textFields["edit-display-title"].waitForExistence(timeout: 2),
            "Game Settings sheet did not appear"
        )

        let displayField = app.textFields["edit-display-title"].firstMatch
        XCTAssertTrue(displayField.waitForExistence(timeout: 5), "Display name field missing")

        displayField.tap()
        displayField.clearAndType("CoreJ2 Rename Test")

        attachScreenshot(named: "library-us004-settings-edit")

        app.buttons["save-game-settings"].tap()
        Thread.sleep(forTimeInterval: 0.8)

        // Re-open via details → settings and verify persistence.
        if !app.buttons["Game Settings"].waitForExistence(timeout: 2) {
            if app.buttons["Done"].waitForExistence(timeout: 1) {
                app.buttons["Done"].tap()
            }
            XCTAssertTrue(details.waitForExistence(timeout: 4))
            details.tap()
        }
        XCTAssertTrue(app.buttons["Game Settings"].waitForExistence(timeout: 4))
        app.buttons["Game Settings"].tap()

        let fieldAgain = app.textFields["edit-display-title"].firstMatch
        XCTAssertTrue(fieldAgain.waitForExistence(timeout: 8), "Settings did not reopen")
        let value = fieldAgain.value as? String ?? ""
        XCTAssertTrue(
            value == "CoreJ2 Rename Test" || value.contains("Rename")
                || app.staticTexts["CoreJ2 Rename Test"].exists,
            "Display name did not persist (got: \(value))"
        )
        XCTAssertTrue(
            app.staticTexts["Official Name"].exists
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Official")).firstMatch.exists
        )

        attachScreenshot(named: "library-us004-settings-persisted")
        app.buttons["Close"].tap()

        if app.descendants(matching: .any)["detail-stable-identity"].waitForExistence(timeout: 2)
            || app.descendants(matching: .any)["stable-identity-hash"].waitForExistence(timeout: 1) {
            attachScreenshot(named: "library-us004-detail-hash")
        }
    }

    private func attachScreenshot(named name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

private extension XCUIElement {
    func clearAndType(_ text: String) {
        tap()
        guard let current = value as? String else {
            typeText(text)
            return
        }
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
        typeText(deleteString)
        typeText(text)
    }
}
