import XCTest
@testable import JavaOne

@MainActor
final class EditableIdentityTests: XCTestCase {

    func testDisplayTitleTakesPriorityOverOfficial() {
        let game = InstalledGame(
            id: UUID(),
            title: "Miami Nights",
            jarURL: URL(fileURLWithPath: "/tmp/m.jar"),
            importedAt: Date(),
            contentHash: "abc",
            officialTitle: "Miami Nights",
            displayTitle: "MN Custom",
            isDisplayTitleCustom: true
        )
        XCTAssertEqual(game.title, "MN Custom")
        XCTAssertEqual(game.officialTitle, "Miami Nights")
    }

    func testEnricherPreservesCustomDisplayFields() async {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("edit-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let jar = temp.appendingPathComponent("game.jar")
        try! Data("x".utf8).write(to: jar)

        let game = InstalledGame(
            id: UUID(),
            title: "Miami Nights",
            jarURL: jar,
            importedAt: Date(),
            contentHash: "deadbeef",
            publisher: "My Pub",
            genre: "My Genre",
            releaseYear: 1999,
            officialTitle: "Miami Nights",
            displayTitle: "Neon Cruise",
            officialPublisher: "Gameloft",
            officialGenre: "Racing",
            officialReleaseYear: 2005,
            isDisplayTitleCustom: true,
            isPublisherCustom: true,
            isGenreCustom: true,
            isReleaseYearCustom: true
        )

        let enricher = GameMetadataEnricher(
            provider: CatalogMetadataProvider(entries: CatalogEntry.seedEntries)
        )
        let enriched = await enricher.enrich(game)

        XCTAssertEqual(enriched.displayTitle, "Neon Cruise")
        XCTAssertEqual(enriched.title, "Neon Cruise")
        XCTAssertEqual(enriched.officialTitle, "Miami Nights")
        XCTAssertEqual(enriched.publisher, "My Pub")
        XCTAssertEqual(enriched.officialPublisher, "Gameloft")
        XCTAssertEqual(enriched.genre, "My Genre")
        XCTAssertEqual(enriched.releaseYear, 1999)
        XCTAssertTrue(enriched.hasCachedMetadata)
    }

    func testProductionConfigurationResolvesDefaultCatalogURL() {
        let url = ProductionMetadataConfiguration.resolvedCatalogURL(
            defaults: UserDefaults(suiteName: "test.corej2.meta.\(UUID().uuidString)")!
        )
        XCTAssertEqual(url, ProductionMetadataConfiguration.defaultCatalogURL)
        XCTAssertTrue(url.absoluteString.contains("catalog.json"))
    }
}
