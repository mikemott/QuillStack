import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var name: String
    var colorHex: String
    var createdAt: Date
    var captures: [Capture]

    init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
        self.createdAt = .now
        self.captures = []
    }

    var captureCount: Int { captures.count }
}

extension Tag {
    static let defaults: [(name: String, hex: String)] = [
        ("Receipt", "#D4910A"),
        ("Event", "#4682B4"),
        ("Note", "#5A8F5A"),
        ("Work", "#6B7280"),
        ("Personal", "#9CA3AF"),
        ("Ticket", "#7C3AED"),
        ("Document", "#0D9488"),
        ("Reference", "#EA8B2D"),
    ]
}
