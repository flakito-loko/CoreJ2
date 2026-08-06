import Foundation

/// Shared library management actions for context menus and detail sheets.
enum LibraryGameAction: String, Identifiable, CaseIterable {
    case play
    case settings
    case favorite
    case changeCover
    case shareJAR
    case showSaveData
    case delete

    var id: String { rawValue }

    func title(isFavorite: Bool) -> String {
        switch self {
        case .play: return "Play"
        case .settings: return "Game Settings"
        case .favorite: return isFavorite ? "Remove Favorite" : "Favorite"
        case .changeCover: return "Change Cover"
        case .shareJAR: return "Share JAR"
        case .showSaveData: return "Show Save Data"
        case .delete: return "Delete Game"
        }
    }

    var systemImage: String {
        switch self {
        case .play: return "play.fill"
        case .settings: return "gearshape"
        case .favorite: return "heart"
        case .changeCover: return "photo"
        case .shareJAR: return "square.and.arrow.up"
        case .showSaveData: return "folder"
        case .delete: return "trash"
        }
    }

    var isDestructive: Bool { self == .delete }
}
