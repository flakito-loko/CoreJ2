import Foundation

/// A Java ME game entry in the user's library.
struct Game: Identifiable, Equatable, Hashable {
    let id: UUID
    let title: String
}
