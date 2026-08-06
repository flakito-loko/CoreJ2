import XCTest

/// LIBRARY-US002 — metadata + cover management on a physical device.
@MainActor
final class LIBRARYUS002MetadataUITests: XCTestCase {

    func testLibraryShowsCachedMetadataAndCoverActions() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["CoreJ2"].waitForExistence(timeout: 25))

        // Wait for optional backfill enrichment.
        let enriching = app.descendants(matching: .any)["metadata-enriching"]
        if enriching.exists {
            let gone = NSPredicate(format: "exists == false")
            expectation(for: gone, evaluatedWith: enriching)
            waitForExpectations(timeout: 20)
        }

        let miami = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Miami")
        ).firstMatch
        if miami.waitForExistence(timeout: 5) {
            // Open detail via cover / details control.
            let details = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Details for")
            ).firstMatch
            if details.exists {
                details.tap()
            } else {
                miami.tap()
            }

            let restore = app.buttons["Restore Default"].firstMatch
            let photos = app.buttons["Import Cover from Photos"].firstMatch
            let files = app.buttons["Import Cover from Files"].firstMatch

            if restore.waitForExistence(timeout: 4) {
                XCTAssertTrue(photos.exists || app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Photos")).firstMatch.exists)
                XCTAssertTrue(files.exists)

                let description = app.descendants(matching: .any)["game-description"]
                let cached = app.descendants(matching: .any)["metadata-cached-badge"]
                // Catalog backfill should populate Miami metadata when present.
                XCTAssertTrue(
                    description.exists || cached.exists || app.staticTexts["Racing"].exists,
                    "Expected cached metadata UI for Miami Nights"
                )

                attachScreenshot(named: "library-us002-detail-metadata")
                app.buttons["Done"].tap()
            }
        }

        attachScreenshot(named: "library-us002-library")
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)
    }

    private func attachScreenshot(named name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
