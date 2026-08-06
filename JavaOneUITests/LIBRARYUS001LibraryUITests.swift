import XCTest

/// LIBRARY-US001 — Modern CoreJ2 library UI on a physical device.
@MainActor
final class LIBRARYUS001LibraryUITests: XCTestCase {

    func testModernLibraryShowsBrandSearchAndLayouts() throws {
        let app = XCUIApplication()
        app.launch()

        let brand = app.staticTexts["CoreJ2"].firstMatch
        XCTAssertTrue(brand.waitForExistence(timeout: 25), "CoreJ2 brand missing from library")

        let search = app.textFields["Search games"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "Search field missing")

        attachScreenshot(named: "library-grid")

        let listButton = app.buttons["List view"].firstMatch
        if listButton.waitForExistence(timeout: 3) {
            listButton.tap()
            Thread.sleep(forTimeInterval: 0.8)
            attachScreenshot(named: "library-list")
        }

        let gridButton = app.buttons["Grid view"].firstMatch
        if gridButton.exists {
            gridButton.tap()
            Thread.sleep(forTimeInterval: 0.6)
        }

        // Favorites / Play affordances when games are installed.
        let play = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Play")).firstMatch
        if play.waitForExistence(timeout: 2) {
            attachScreenshot(named: "library-with-games")
        }

        XCTAssertTrue(
            app.state == .runningForeground || app.state == .runningBackground,
            "App not alive after library UI probe"
        )
    }

    private func attachScreenshot(named name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
