import CryptoKit
import XCTest
@testable import JavaOne

@MainActor
final class HashStepTests: XCTestCase {

    // MARK: - Tests

    func testHashStepStoresLowercaseSHA256OfImportedJAR() throws {
        let jarURL = try makeTemporaryFile(
            named: "sample.jar",
            contents: Data("javaone-hash-fixture".utf8)
        )
        defer { try? FileManager.default.removeItem(at: jarURL.deletingLastPathComponent()) }

        let context = ImportContext(sourceURL: jarURL)
        context.importedJarURL = jarURL
        context.installedGame = InstalledGame(
            id: UUID(),
            title: "sample",
            jarURL: jarURL,
            importedAt: Date(),
            contentHash: ""
        )

        try HashStep().run(on: context)

        let expectedHash = SHA256.hash(data: Data("javaone-hash-fixture".utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        XCTAssertEqual(context.contentHash, expectedHash)
        XCTAssertEqual(context.installedGame?.contentHash, expectedHash)
        XCTAssertEqual(context.contentHash, context.contentHash?.lowercased())
        XCTAssertTrue(context.warnings.isEmpty)
    }

    func testHashStepAddsWarningWhenImportedJARIsUnavailable() throws {
        let sourceURL = URL(fileURLWithPath: "/tmp/missing-source.jar")
        let context = ImportContext(sourceURL: sourceURL)

        try HashStep().run(on: context)

        XCTAssertNil(context.contentHash)
        XCTAssertEqual(context.warnings.count, 1)
        XCTAssertTrue(context.warnings[0].contains("unavailable"))
    }

    func testPipelineStillImportsWhenHashStepIsRegistered() throws {
        let jarURL = try makeTemporaryJAR(
            fileName: "pipeline-hash.jar",
            manifest: """
            Manifest-Version: 1.0
            MIDlet-Name: Hashed Game
            """
        )
        defer { try? FileManager.default.removeItem(at: jarURL.deletingLastPathComponent()) }

        let pipeline = DefaultImportPipeline(
            importService: PassthroughImportService(),
            steps: [
                ManifestStep(manifestService: JARManifestService()),
                HashStep()
            ]
        )

        let game = try pipeline.run(from: jarURL)

        XCTAssertEqual(game.title, "Hashed Game")
        XCTAssertFalse(game.contentHash.isEmpty)
        XCTAssertFalse(game.jarURL.path.isEmpty)
    }

    // MARK: - Helpers

    private func makeTemporaryFile(named fileName: String, contents: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(fileName, isDirectory: false)
        try contents.write(to: fileURL)
        return fileURL
    }

    private func makeTemporaryJAR(fileName: String, manifest: String?) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let jarURL = directory.appendingPathComponent(fileName, isDirectory: false)
        let zipData = try TestJARBuilder.makeJAR(manifestText: manifest)
        try zipData.write(to: jarURL)
        return jarURL
    }
}

// MARK: - Shared test doubles used by HashStepTests

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

    static func makeJAR(manifestText: String?) throws -> Data {
        var entries: [(name: String, data: Data)] = [
            ("placeholder.txt", Data("ok".utf8))
        ]

        if let manifestText {
            entries.insert(
                ("META-INF/MANIFEST.MF", Data(manifestText.utf8)),
                at: 0
            )
        }

        return try makeStoredZIP(entries: entries)
    }

    private static func makeStoredZIP(entries: [(name: String, data: Data)]) throws -> Data {
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
