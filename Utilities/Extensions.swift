//
//  Extensions.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import Foundation
import SwiftUI

// MARK: - Date Extensions

extension Date {
    /// Formats date as "Today", "Yesterday", or date string
    var relativeFormat: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: self)
        }
    }

    /// Returns a short time ago format (e.g., "2h ago", "5m ago")
    var timeAgoFormat: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Formats date for note display with smart relative formatting
    /// Returns "Today, 2:30 PM", "Yesterday", or "Dec 30, 2025"
    func formattedForNotes(includeTime: Bool = true) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(self) {
            if includeTime {
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                return "Today, \(formatter.string(from: self))"
            }
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: self)
        }
    }

    /// Short format for compact displays: "Today", "Yesterday", or "Dec 30"
    var shortFormat: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
        }
    }
}

// MARK: - String Extensions

extension String {
    /// Trims whitespace and newlines
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Checks if string is empty or only whitespace
    var isBlank: Bool {
        trimmed.isEmpty
    }

    /// Truncates string to specified length with ellipsis
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count > length {
            return String(self.prefix(length)) + trailing
        }
        return self
    }

    /// Returns first N lines of text
    func firstLines(_ count: Int) -> String {
        let lines = components(separatedBy: .newlines)
        return lines.prefix(count).joined(separator: "\n")
    }
}

// MARK: - Color Extensions

extension Color {
    /// Mockup-based color scheme (vintage/literary theme)

    // Primary forest green colors
    static let forestDark = Color(red: 30/255, green: 77/255, blue: 47/255)        // #1e4d2f
    static let forestMedium = Color(red: 20/255, green: 61/255, blue: 35/255)      // #143d23
    static let forestLight = Color(red: 232/255, green: 240/255, blue: 232/255)    // #e8f0e8

    // Background colors
    static let creamLight = Color(red: 244/255, green: 248/255, blue: 244/255)     // #f4f8f4
    static let creamMedium = Color(red: 238/255, green: 245/255, blue: 238/255)    // #eef5ee
    static let paperBeige = Color(red: 250/255, green: 245/255, blue: 240/255)     // #faf5f0
    static let paperTan = Color(red: 248/255, green: 240/255, blue: 228/255)       // #f8f0e4

    // Text colors
    static let textDark = Color(red: 45/255, green: 74/255, blue: 47/255)          // #2d4a2f
    static let textMedium = Color(red: 74/255, green: 107/255, blue: 79/255)       // #4a6b4f
    static let textLight = Color(red: 212/255, green: 224/255, blue: 212/255)      // #d4e0d4

    // Badge colors for note types
    static let badgeTodo = Color(red: 184/255, green: 134/255, blue: 11/255)       // #b8860b - golden
    static let badgeMeeting = Color(red: 20/255, green: 100/255, blue: 100/255)    // #146464 - teal
    static let badgeGeneral = Color(red: 30/255, green: 77/255, blue: 47/255)      // #1e4d2f - forest
    static let badgeEmail = Color(red: 139/255, green: 69/255, blue: 119/255)      // #8b4577 - plum
    static let badgePrompt = Color(red: 91/255, green: 77/255, blue: 153/255)      // #5b4d99 - purple
    static let badgeReminder = Color(red: 220/255, green: 88/255, blue: 88/255)    // #dc5858 - coral red
    static let badgeContact = Color(red: 52/255, green: 120/255, blue: 180/255)    // #3478b4 - blue

    // App-wide theme colors (for compatibility)
    static let appPrimary = forestDark
    static let appAccent = forestDark
    static let appSuccess = Color(red: 0.15, green: 0.68, blue: 0.38)
    static let appBackground = creamLight
    static let appText = textDark

    /// Priority colors
    static let priorityHigh = Color.red
    static let priorityMedium = Color.orange
    static let priorityNormal = Color.secondary
}

// MARK: - Font Extensions

extension Font {
    /// Serif fonts matching mockup aesthetic (using iOS system serif fonts)
    static func serifTitle(_ size: CGFloat = 34, weight: Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func serifHeadline(_ size: CGFloat = 26, weight: Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func serifBody(_ size: CGFloat = 17, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func serifCaption(_ size: CGFloat = 13, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies standard card styling
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    /// Conditional view modifier
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    /// Resizes image to fit within max dimensions
    func resized(maxSize: CGFloat) -> UIImage? {
        let size = self.size
        let scale = min(maxSize / size.width, maxSize / size.height)

        if scale >= 1 {
            return self
        }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    /// Compresses image to JPEG with quality
    func compressed(quality: CGFloat = 0.8) -> Data? {
        jpegData(compressionQuality: quality)
    }
}

// MARK: - Array Extensions

extension Array where Element: Identifiable {
    /// Removes duplicates based on id
    func removingDuplicates() -> [Element] {
        var seen = Set<Element.ID>()
        return filter { seen.insert($0.id).inserted }
    }
}

// MARK: - Error Extensions

extension Error {
    /// User-friendly error description
    var friendlyDescription: String {
        if let localizedError = self as? LocalizedError {
            return localizedError.errorDescription ?? localizedDescription
        }
        return localizedDescription
    }
}
