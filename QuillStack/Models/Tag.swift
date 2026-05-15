import Foundation
import SwiftData
import SwiftUI

@Model
final class Tag {
    var name: String = ""
    var colorHex: String = "#6B7280"
    var createdAt: Date = Date.now
    var captures: [Capture] = []

    init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
        self.createdAt = .now
        self.captures = []
    }

    var captureCount: Int { captures.count }

    var iconName: String {
        switch name {
        case "Receipt": return "ph-receipt-duotone"
        case "Event": return "ph-star-duotone"
        case "Note": return "ph-notepad-duotone"
        case "Work": return "ph-briefcase-duotone"
        case "Document": return "ph-file-text-duotone"
        case "Contact": return "ph-address-book-duotone"
        case "Travel": return "ph-airplane-tilt-duotone"
        case "To-Do": return "ph-sparkle-duotone"
        case "Food": return "ph-fork-knife-duotone"
        default: return "ph-tag-duotone"
        }
    }
}

extension Tag {
    static let defaults: [(name: String, hex: String)] = [
        ("Receipt", "#D4FF00"),
        ("Event", "#007AFF"),
        ("Work", "#FFC107"),
        ("Contact", "#64D2FF"),
        ("Food", "#E85D75"),
        ("To-Do", "#90EE90"),
        ("Project", "#FFB6C1"),
        ("Ticket", "#FF7F50"),
        ("Reference", "#008080"),
        ("Quote", "#BB86FC"),
    ]

    // Dark text on light backgrounds, white text on dark backgrounds
    var usesLightText: Bool {
        let hex = colorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        guard scanner.scanHexInt64(&rgb) else { return false }
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance < 0.5
    }
}
