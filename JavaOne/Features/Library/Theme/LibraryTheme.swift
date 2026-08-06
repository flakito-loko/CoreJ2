import SwiftUI

/// Visual tokens for the CoreJ2 game library.
enum LibraryTheme {

    // MARK: - Brand

    static let brandName = "CoreJ2"

    /// Deep Atlantic navy — primary brand plane.
    static let navy = Color(red: 0.04, green: 0.11, blue: 0.16)

    /// Coastal teal — accent for actions and badges.
    static let teal = Color(red: 0.12, green: 0.62, blue: 0.58)

    /// Soft gold — favorites only (not a page-wide terracotta theme).
    static let gold = Color(red: 0.86, green: 0.70, blue: 0.28)

    /// Mist surface for light mode.
    static let mist = Color(red: 0.91, green: 0.94, blue: 0.96)

    /// Ink for light-mode body text.
    static let ink = Color(red: 0.08, green: 0.14, blue: 0.18)

    // MARK: - Typography

    static func brandFont(relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
        .custom("AvenirNext-Heavy", size: 36, relativeTo: textStyle)
    }

    static func sectionFont(relativeTo textStyle: Font.TextStyle = .title3) -> Font {
        .custom("AvenirNext-DemiBold", size: 20, relativeTo: textStyle)
    }

    static func cardTitleFont(relativeTo textStyle: Font.TextStyle = .headline) -> Font {
        .custom("AvenirNext-DemiBold", size: 16, relativeTo: textStyle)
    }

    static func metaFont(relativeTo textStyle: Font.TextStyle = .caption) -> Font {
        .custom("AvenirNext-Medium", size: 12, relativeTo: textStyle)
    }

    // MARK: - Layout

    static let horizontalPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
    static let gridSpacing: CGFloat = 16
    static let coverCornerRadius: CGFloat = 14

    // MARK: - Atmosphere

    static func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.07, blue: 0.10),
                    Color(red: 0.05, green: 0.12, blue: 0.16),
                    Color(red: 0.04, green: 0.10, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.93, green: 0.96, blue: 0.97),
                Color(red: 0.88, green: 0.93, blue: 0.95),
                Color(red: 0.95, green: 0.97, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Grid vs list presentation for the library.
enum LibraryLayoutMode: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .grid: return "Grid view"
        case .list: return "List view"
        }
    }
}
