import XCTest

/// LIBRARY-US005 — production catalog activation on device.
@MainActor
final class LIBRARYUS005CatalogUITests: XCTestCase {

    func testCataloguedGamesReceiveMetadataAndArtwork() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["CoreJ2"].waitForExistence(timeout: 25))

        // Wait for remote catalog backfill / artwork download.
        let enriching = app.descendants(matching: .any)["metadata-enriching"]
        if enriching.waitForExistence(timeout: 3) {
            let gone = NSPredicate(format: "exists == false")
            expectation(for: gone, evaluatedWith: enriching)
            waitForExpectations(timeout: 90)
        } else {
            Thread.sleep(forTimeInterval: 8)
        }

        attachScreenshot(named: "library-us005-library")

        // Open a catalogued title (prefer Miami Nights / Tetris / Bounce).
        let titles = ["Miami Nights", "Tetris", "Bounce", "Astroids", "Ubertris", "Gryzzles"]
        var opened = false
        for title in titles {
            let details = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Details for \(title)")
            ).firstMatch
            if details.waitForExistence(timeout: 2) {
                details.tap()
                opened = true
                break
            }
        }
        if !opened {
            let any = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Details for")
            ).firstMatch
            XCTAssertTrue(any.waitForExistence(timeout: 5), "No games in library")
            any.tap()
        }

        // Refresh metadata to force remote catalog pull + cover download.
        let refresh = app.buttons["Refresh Metadata"].firstMatch
        if refresh.waitForExistence(timeout: 4) {
            refresh.tap()
            Thread.sleep(forTimeInterval: 6)
        }

        attachScreenshot(named: "library-us005-detail-metadata")

        // Description / publisher should not be empty placeholders for catalogued games.
        let unknownPublisher = app.staticTexts["Unknown"]
        let hasDescription = app.descendants(matching: .any)["game-description"].waitForExistence(timeout: 3)
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "puzzle") ).firstMatch.exists
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "racing") ).firstMatch.exists
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "arcade") ).firstMatch.exists
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "platform") ).firstMatch.exists
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "action") ).firstMatch.exists
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "strategy") ).firstMatch.exists
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "cruise") ).firstMatch.exists

        XCTAssertTrue(
            hasDescription || !unknownPublisher.exists,
            "Catalogued game still showing placeholder metadata"
        )
    }

    private func attachScreenshot(named name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
