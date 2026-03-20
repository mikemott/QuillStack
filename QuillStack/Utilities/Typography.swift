import SwiftUI

// ============================================================
// Typography: IBM Plex Sans (display/headlines) + Plex Mono (data/labels)
// Mirrors the document's dual-font editorial strategy.
//
// Rules:
// - Display/headlines: Plex Sans, tighter letter-spacing for editorial feel
// - Body/labels: Plex Sans Regular for readability
// - Data/timestamps: Plex Mono for technical precision
// - NEVER use pure white for body text — use QSColor.onSurfaceVariant
// ============================================================

enum QSFont {
    // MARK: - IBM Plex Sans

    static func sans(size: CGFloat) -> Font {
        .custom("IBMPlexSans-Regular", size: size)
    }

    static func sansLight(size: CGFloat) -> Font {
        .custom("IBMPlexSans-Light", size: size)
    }

    static func sansMedium(size: CGFloat) -> Font {
        .custom("IBMPlexSans-Medium", size: size)
    }

    // MARK: - IBM Plex Mono

    static func mono(size: CGFloat) -> Font {
        .custom("IBMPlexMono-Regular", size: size)
    }

    static func monoLight(size: CGFloat) -> Font {
        .custom("IBMPlexMono-Light", size: size)
    }

    // MARK: - Display (large, editorial — tight tracking)

    static let displayLarge = sansMedium(size: 32)
    static let displayMedium = sansMedium(size: 24)

    // MARK: - Card Styles

    static let cardTitle = sansMedium(size: 18)
    static let cardBody = sans(size: 14)
    static let cardTimestamp = mono(size: 11)
    static let cardPageCount = monoLight(size: 11)
    static let cardLabel = mono(size: 9)

    // MARK: - Timeline / Drawer

    static let dateHeader = sansLight(size: 24)
    static let dateHeaderCount = monoLight(size: 13)

    // MARK: - Tags

    static let tagLabel = mono(size: 10)
    static let tagLabelLarge = mono(size: 11)

    // MARK: - Detail View

    static let detailTitle = sansMedium(size: 22)
    static let detailBody = sans(size: 15)
    static let detailLocation = sans(size: 14)
    static let detailTimestamp = mono(size: 13)
    static let detailPageIndicator = monoLight(size: 12)

    // MARK: - Section Headers (settings, tag picker)

    static let sectionHeader = mono(size: 10)
}
