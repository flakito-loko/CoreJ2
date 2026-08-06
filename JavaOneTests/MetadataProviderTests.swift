import UIKit
import XCTest
@testable import JavaOne

@MainActor
final class MetadataProviderTests: XCTestCase {

    func testCatalogProviderResolvesMiamiNights() async {
        let provider = CatalogMetadataProvider(entries: CatalogEntry.seedEntries)
        let record = await provider.lookup(
            GameMetadataQuery(
                title: "Miami Nights",
                vendor: "Gameloft",
                version: "1.0.0",
                contentHash: "abc"
            )
        )

        XCTAssertNotNil(record)
        XCTAssertEqual(record?.genre, "Racing")
        XCTAssertEqual(record?.publisher, "Gameloft")
        XCTAssertEqual(record?.releaseYear, 2005)
        XCTAssertEqual(record?.providerID, "catalog")
    }

    func testCompositePrefersFirstHit() async {
        let first = CatalogMetadataProvider(entries: [
            CatalogEntry(
                title: "Miami Nights",
                vendor: "Gameloft",
                description: "From first",
                publisher: "First",
                developer: "First",
                genre: "Racing",
                releaseYear: 2005,
                resolution: "320 × 240"
            )
        ])
        let second = CatalogMetadataProvider(entries: CatalogEntry.seedEntries)
        let composite = CompositeMetadataProvider(providers: [first, second])

        let record = await composite.lookup(
            GameMetadataQuery(title: "Miami Nights", vendor: nil, version: nil, contentHash: "x")
        )

        XCTAssertEqual(record?.publisher, "First")
        XCTAssertEqual(record?.description, "From first")
    }

    func testEnricherWritesSidecarOffline() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("meta-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let jar = temp.appendingPathComponent("game.jar")
        try Data("jar".utf8).write(to: jar)

        let game = InstalledGame(
            id: UUID(),
            title: "Miami Nights",
            jarURL: jar,
            importedAt: Date(),
            contentHash: "deadbeef",
            publisher: "Gameloft"
        )

        let enricher = GameMetadataEnricher(
            provider: CatalogMetadataProvider(entries: CatalogEntry.seedEntries)
        )
        let enriched = await enricher.enrich(game)

        XCTAssertTrue(enriched.hasCachedMetadata)
        XCTAssertEqual(enriched.genre, "Racing")
        XCTAssertFalse(enriched.gameDescription.isEmpty)

        let sidecar = temp.appendingPathComponent("metadata.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sidecar.path))
    }

    func testCoverStoreCustomAndRestore() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("cover-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let jar = temp.appendingPathComponent("game.jar")
        try Data("jar".utf8).write(to: jar)
        let artwork = temp.appendingPathComponent("artwork", isDirectory: true)
        try FileManager.default.createDirectory(at: artwork, withIntermediateDirectories: true)
        let icon = artwork.appendingPathComponent("icon.png")
        let iconData = solidPNGData()
        try iconData.write(to: icon)

        var game = InstalledGame(
            id: UUID(),
            title: "Demo",
            jarURL: jar,
            importedAt: Date(),
            contentHash: "1",
            coverURL: icon,
            defaultCoverURL: icon
        )

        let store = GameCoverStore()
        game = try store.applyCustomCover(imageData: solidJPEGData(), to: game)
        XCTAssertTrue(game.hasCustomCover)
        XCTAssertEqual(game.coverURL?.lastPathComponent, "custom-cover.jpg")

        game = try store.restoreDefaultCover(for: game)
        XCTAssertFalse(game.hasCustomCover)
        XCTAssertEqual(game.coverURL?.lastPathComponent, "icon.png")
    }

    private func solidJPEGData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return image.jpegData(compressionQuality: 0.9)!
    }

    private func solidPNGData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return image.pngData()!
    }
}
