import Foundation

/// A Java ME game owned by JavaOne's internal library.
struct InstalledGame: Identifiable, Equatable, Hashable {
    let id: UUID
    let title: String
    let jarURL: URL
    let importedAt: Date
    /// SHA-256 digest of the JAR contents, as a lowercase hexadecimal string.
    let contentHash: String
}
