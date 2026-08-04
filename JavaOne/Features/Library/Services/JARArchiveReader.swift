import Foundation
import zlib

/// Errors produced while reading entries from a JAR/ZIP archive.
enum JARArchiveError: Error, Equatable {
    case unableToReadArchive
}

/// Reads named entries from a JAR (ZIP) archive.
enum JARArchiveReader {

    // MARK: - Public

    /// Returns the uncompressed bytes for `path`, or `nil` if the entry is absent.
    static func data(forEntryNamed path: String, inArchiveAt url: URL) throws -> Data? {
        let archiveData: Data
        do {
            archiveData = try Data(contentsOf: url)
        } catch {
            throw JARArchiveError.unableToReadArchive
        }
        return try data(forEntryNamed: path, in: archiveData)
    }

    /// Returns the uncompressed bytes for `path`, or `nil` if the entry is absent.
    static func data(forEntryNamed path: String, in zipData: Data) throws -> Data? {
        let normalizedPath = normalize(path).lowercased()
        var offset = 0

        while offset + 30 <= zipData.count {
            let signature = try zipData.uint32LE(at: offset)
            if signature == centralDirectorySignature {
                break
            }
            guard signature == localFileHeaderSignature else {
                throw JARArchiveError.unableToReadArchive
            }

            let compressionMethod = try zipData.uint16LE(at: offset + 8)
            let compressedSize = Int(try zipData.uint32LE(at: offset + 18))
            let uncompressedSize = Int(try zipData.uint32LE(at: offset + 22))
            let fileNameLength = Int(try zipData.uint16LE(at: offset + 26))
            let extraFieldLength = Int(try zipData.uint16LE(at: offset + 28))

            let fileNameStart = offset + 30
            let fileNameEnd = fileNameStart + fileNameLength
            let dataStart = fileNameEnd + extraFieldLength
            let dataEnd = dataStart + compressedSize

            guard fileNameEnd <= zipData.count, dataEnd <= zipData.count else {
                throw JARArchiveError.unableToReadArchive
            }

            let fileNameData = zipData.subdata(in: fileNameStart..<fileNameEnd)
            let fileName = String(data: fileNameData, encoding: .utf8)?
                .replacingOccurrences(of: "\\", with: "/")
                .lowercased()

            if fileName == normalizedPath || fileName == "/" + normalizedPath {
                let compressedData = zipData.subdata(in: dataStart..<dataEnd)
                switch compressionMethod {
                case storedMethod:
                    return compressedData
                case deflateMethod:
                    return try inflateRaw(compressedData, uncompressedSize: uncompressedSize)
                default:
                    throw JARArchiveError.unableToReadArchive
                }
            }

            offset = dataEnd
        }

        return nil
    }

    // MARK: - Path Helpers

    static func normalize(_ path: String) -> String {
        var normalized = path
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.hasPrefix("/") {
            normalized = String(normalized.dropFirst())
        }
        return normalized
    }

    // MARK: - Private

    private static let localFileHeaderSignature: UInt32 = 0x04034b50
    private static let centralDirectorySignature: UInt32 = 0x02014b50
    private static let storedMethod: UInt16 = 0
    private static let deflateMethod: UInt16 = 8

    private static func inflateRaw(_ data: Data, uncompressedSize: Int) throws -> Data {
        guard uncompressedSize >= 0 else {
            throw JARArchiveError.unableToReadArchive
        }

        var stream = z_stream()
        let initStatus = inflateInit2_(
            &stream,
            -MAX_WBITS,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initStatus == Z_OK else {
            throw JARArchiveError.unableToReadArchive
        }
        defer { inflateEnd(&stream) }

        let destinationCapacity = max(uncompressedSize, 1)
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationCapacity)
        defer { destinationBuffer.deallocate() }

        let status: Int32 = data.withUnsafeBytes { inputBuffer in
            guard let inputBase = inputBuffer.bindMemory(to: Bytef.self).baseAddress else {
                return Z_DATA_ERROR
            }

            stream.next_in = UnsafeMutablePointer(mutating: inputBase)
            stream.avail_in = uInt(data.count)
            stream.next_out = destinationBuffer
            stream.avail_out = uInt(destinationCapacity)
            return inflate(&stream, Z_FINISH)
        }

        guard status == Z_STREAM_END || status == Z_OK else {
            throw JARArchiveError.unableToReadArchive
        }

        return Data(bytes: destinationBuffer, count: Int(stream.total_out))
    }
}

// MARK: - Data Helpers

private extension Data {
    func uint16LE(at offset: Int) throws -> UInt16 {
        guard offset + 2 <= count else {
            throw JARArchiveError.unableToReadArchive
        }
        return self[offset..<offset + 2].withUnsafeBytes { buffer in
            buffer.loadUnaligned(as: UInt16.self).littleEndian
        }
    }

    func uint32LE(at offset: Int) throws -> UInt32 {
        guard offset + 4 <= count else {
            throw JARArchiveError.unableToReadArchive
        }
        return self[offset..<offset + 4].withUnsafeBytes { buffer in
            buffer.loadUnaligned(as: UInt32.self).littleEndian
        }
    }
}
