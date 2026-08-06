import CryptoKit
import Foundation

/// Permanent game identity derived from JAR bytes (SHA-256), never from filename.
enum GameIdentity {
    /// Lowercase hex SHA-256 of file contents at `url`.
    static func sha256Hex(ofFileAt url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return sha256Hex(of: data)
    }

    static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// Maps stable content hashes to install UUIDs so RMS paths survive Delete Game → reimport
/// without changing the emulator/RMS implementation (which keys saves by install UUID).
final class GameIdentityRegistry: @unchecked Sendable {

    static let shared = GameIdentityRegistry()

    private let lock = NSLock()
    private let fileManager: FileManager
    private var map: [String: String]
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = documents
            .appendingPathComponent("JavaOne", isDirectory: true)
            .appendingPathComponent("Identity", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("index.json", isDirectory: false)
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.map = decoded
        } else {
            self.map = [:]
        }
    }

    /// Returns the install UUID bound to `contentHash`, creating and persisting one if needed.
    func installID(forContentHash contentHash: String) -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let key = contentHash.lowercased()
        if let existing = map[key], let uuid = UUID(uuidString: existing) {
            return uuid
        }
        let created = UUID()
        map[key] = created.uuidString
        persistLocked()
        return created
    }

    /// Ensures `installID` is the permanent binding for `contentHash`.
    func bind(contentHash: String, installID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        map[contentHash.lowercased()] = installID.uuidString
        persistLocked()
    }

    func installIDIfPresent(forContentHash contentHash: String) -> UUID? {
        lock.lock()
        defer { lock.unlock() }
        guard let raw = map[contentHash.lowercased()] else { return nil }
        return UUID(uuidString: raw)
    }

    /// Removes the hash → UUID binding (Delete Everything only).
    func removeBinding(forContentHash contentHash: String) {
        lock.lock()
        defer { lock.unlock() }
        map.removeValue(forKey: contentHash.lowercased())
        persistLocked()
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(map) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
