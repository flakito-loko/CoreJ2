import XCTest
@testable import JavaOne

@MainActor
final class GameIdentityTests: XCTestCase {

    func testSHA256IsStableForSameBytes() throws {
        let data = Data("corej2-identity".utf8)
        let a = GameIdentity.sha256Hex(of: data)
        let b = GameIdentity.sha256Hex(of: data)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 64)
    }

    func testIdentityRegistryReusesInstallID() {
        let registry = GameIdentityRegistry()
        let hash = "abc123def456"
        let first = registry.installID(forContentHash: hash)
        let second = registry.installID(forContentHash: hash)
        XCTAssertEqual(first, second)
    }

    func testDeleteGameKeepsBindingDeleteEverythingRemovesIt() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("id-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        // Point documents via custom paths by using real Documents — use installation manager on temp library layout.
        let registry = GameIdentityRegistry()
        let hash = GameIdentity.sha256Hex(of: Data("jar-bytes".utf8))
        let installID = registry.installID(forContentHash: hash)

        let libraryDir = temp.appendingPathComponent(installID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: libraryDir, withIntermediateDirectories: true)
        let jar = libraryDir.appendingPathComponent("game.jar")
        try Data("jar-bytes".utf8).write(to: jar)
        try Data("{}".utf8).write(to: libraryDir.appendingPathComponent("metadata.json"))

        let game = InstalledGame(
            id: installID,
            title: "Demo",
            jarURL: jar,
            importedAt: Date(),
            contentHash: hash
        )

        let manager = GameInstallationManager(identityRegistry: registry)
        try manager.delete(game, mode: .gameOnly)
        XCTAssertFalse(FileManager.default.fileExists(atPath: libraryDir.path))
        XCTAssertEqual(registry.installIDIfPresent(forContentHash: hash), installID)

        // Recreate payload then wipe everything.
        try FileManager.default.createDirectory(at: libraryDir, withIntermediateDirectories: true)
        try Data("jar-bytes".utf8).write(to: jar)
        try manager.delete(game, mode: .everything)
        XCTAssertNil(registry.installIDIfPresent(forContentHash: hash))
    }

    func testRepositoryDeleteRemovesGame() {
        let game = InstalledGame(
            id: UUID(),
            title: "X",
            jarURL: URL(fileURLWithPath: "/tmp/x.jar"),
            importedAt: Date(),
            contentHash: "hash"
        )
        let repo = InMemoryGameLibraryRepository(games: [game])
        repo.delete(game)
        XCTAssertTrue(repo.fetchGames().isEmpty)
        XCTAssertNil(repo.game(withContentHash: "hash"))
    }
}
