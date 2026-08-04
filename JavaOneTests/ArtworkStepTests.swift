import XCTest
@testable import JavaOne

@MainActor
final class ArtworkStepTests: XCTestCase {

    // MARK: - Tests

    func testIconExtracted() throws {
        let iconBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01, 0x02])
        let jarURL = try makeGameJAR(
            fileName: "with-icon.jar",
            manifest: """
            Manifest-Version: 1.0
            MIDlet-Name: Icon Game
            MIDlet-1: Icon Game, /icons/app.png, com.example.IconGame
            """,
            extraEntries: [("icons/app.png", iconBytes)]
        )
        defer { try? FileManager.default.removeItem(at: jarURL.deletingLastPathComponent()) }

        let context = try makeContext(from: jarURL)
        try ArtworkStep().run(on: context)

        let artworkURL = try XCTUnwrap(context.artworkURL)
        XCTAssertEqual(artworkURL.lastPathComponent, "icon.png")
        XCTAssertEqual(artworkURL.deletingLastPathComponent().lastPathComponent, "artwork")
        XCTAssertEqual(try Data(contentsOf: artworkURL), iconBytes)
        XCTAssertTrue(context.warnings.isEmpty)
    }

    func testIconMissingContinuesWithWarning() throws {
        let jarURL = try makeGameJAR(
            fileName: "no-icon.jar",
            manifest: """
            Manifest-Version: 1.0
            MIDlet-Name: Plain Game
            """,
            extraEntries: []
        )
        defer { try? FileManager.default.removeItem(at: jarURL.deletingLastPathComponent()) }

        let context = try makeContext(from: jarURL)
        try ArtworkStep().run(on: context)

        XCTAssertNil(context.artworkURL)
        XCTAssertEqual(context.warnings.count, 1)
        XCTAssertTrue(context.warnings[0].localizedCaseInsensitiveContains("icon"))
    }

    func testInvalidIconPathContinuesWithWarning() throws {
        let jarURL = try makeGameJAR(
            fileName: "bad-icon-path.jar",
            manifest: """
            Manifest-Version: 1.0
            MIDlet-Name: Broken Icon Game
            MIDlet-Icon: /missing/icon.png
            """,
            extraEntries: []
        )
        defer { try? FileManager.default.removeItem(at: jarURL.deletingLastPathComponent()) }

        let context = try makeContext(from: jarURL)
        try ArtworkStep().run(on: context)

        XCTAssertNil(context.artworkURL)
        XCTAssertEqual(context.warnings.count, 1)
        XCTAssertTrue(context.warnings[0].localizedCaseInsensitiveContains("not found"))
    }

    func testImportContinuesWithoutArtwork() throws {
        let jarURL = try makeGameJAR(
            fileName: "pipeline-no-art.jar",
            manifest: """
            Manifest-Version: 1.0
            MIDlet-Name: No Artwork
            """,
            extraEntries: []
        )
        defer { try? FileManager.default.removeItem(at: jarURL.deletingLastPathComponent()) }

        let pipeline = DefaultImportPipeline(
            importService: PassthroughImportService(),
            steps: [
                ManifestStep(manifestService: JARManifestService()),
                HashStep(),
                DuplicateDetectionStep(repository: InMemoryGameLibraryRepository()),
                ArtworkStep()
            ]
        )

        let game = try pipeline.run(from: jarURL)

        XCTAssertEqual(game.title, "No Artwork")
        XCTAssertFalse(game.contentHash.isEmpty)
    }

    // MARK: - Helpers

    private func makeContext(from jarURL: URL) throws -> ImportContext {
        let context = ImportContext(sourceURL: jarURL)
        context.importedJarURL = jarURL
        context.installedGame = InstalledGame(
            id: UUID(),
            title: jarURL.deletingPathExtension().lastPathComponent,
            jarURL: jarURL,
            importedAt: Date(),
            contentHash: ""
        )
        context.manifest = try JARManifestService().readManifest(from: jarURL)
        return context
    }

    private func makeGameJAR(
        fileName: String,
        manifest: String,
        extraEntries: [(String, Data)]
    ) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let jarURL = directory.appendingPathComponent(fileName, isDirectory: false)
        var entries: [(name: String, data: Data)] = [
            ("META-INF/MANIFEST.MF", Data(manifest.utf8))
        ]
        entries.append(contentsOf: extraEntries.map { (name: $0.0, data: $0.1) })
        try TestJARBuilder.makeStoredZIP(entries: entries).write(to: jarURL)
        return jarURL
    }
}

// MARK: - Test Doubles

private final class PassthroughImportService: ImportService {
    func importJAR(from sourceURL: URL) throws -> InstalledGame {
        InstalledGame(
            id: UUID(),
            title: sourceURL.deletingPathExtension().lastPathComponent,
            jarURL: sourceURL,
            importedAt: Date(),
            contentHash: ""
        )
    }
}

private enum TestJARBuilder {
    private static let localFileHeaderSignature: UInt32 = 0x04034b50
    private static let centralDirectorySignature: UInt32 = 0x02014b50
    private static let endOfCentralDirectorySignature: UInt32 = 0x06054b50

    static func makeStoredZIP(entries: [(name: String, data: Data)]) throws -> Data {
        var localFiles = Data()
        var centralDirectory = Data()
        var offsets: [UInt32] = []

        for entry in entries {
            let nameData = Data(entry.name.utf8)
            offsets.append(UInt32(localFiles.count))

            var localHeader = Data()
            localHeader.appendUInt32(localFileHeaderSignature)
            localHeader.appendUInt16(20)
            localHeader.appendUInt16(0)
            localHeader.appendUInt16(0)
            localHeader.appendUInt16(0)
            localHeader.appendUInt16(0)
            localHeader.appendUInt32(0)
            localHeader.appendUInt32(UInt32(entry.data.count))
            localHeader.appendUInt32(UInt32(entry.data.count))
            localHeader.appendUInt16(UInt16(nameData.count))
            localHeader.appendUInt16(0)
            localHeader.append(nameData)
            localHeader.append(entry.data)
            localFiles.append(localHeader)

            var centralHeader = Data()
            centralHeader.appendUInt32(centralDirectorySignature)
            centralHeader.appendUInt16(20)
            centralHeader.appendUInt16(20)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt32(0)
            centralHeader.appendUInt32(UInt32(entry.data.count))
            centralHeader.appendUInt32(UInt32(entry.data.count))
            centralHeader.appendUInt16(UInt16(nameData.count))
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt32(0)
            centralHeader.appendUInt32(offsets[offsets.count - 1])
            centralHeader.append(nameData)
            centralDirectory.append(centralHeader)
        }

        var endRecord = Data()
        endRecord.appendUInt32(endOfCentralDirectorySignature)
        endRecord.appendUInt16(0)
        endRecord.appendUInt16(0)
        endRecord.appendUInt16(UInt16(entries.count))
        endRecord.appendUInt16(UInt16(entries.count))
        endRecord.appendUInt32(UInt32(centralDirectory.count))
        endRecord.appendUInt32(UInt32(localFiles.count))
        endRecord.appendUInt16(0)

        var zip = Data()
        zip.append(localFiles)
        zip.append(centralDirectory)
        zip.append(endRecord)
        return zip
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var littleEndian = value.littleEndian
        append(Data(bytes: &littleEndian, count: 2))
    }

    mutating func appendUInt32(_ value: UInt32) {
        var littleEndian = value.littleEndian
        append(Data(bytes: &littleEndian, count: 4))
    }
}
