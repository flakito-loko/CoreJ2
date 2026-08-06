import Foundation

/// Library-facing compatibility badge for an installed MIDlet.
enum GameCompatibility: String, Codable, Equatable, Hashable, Sendable {
    case ready = "Ready"
    case limited = "Limited"
    case unknown = "Unknown"

    var badgeTitle: String { rawValue }
}
