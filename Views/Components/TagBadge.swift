//
//  TagBadge.swift
//  QuillStack
//
//  Created on 2026-01-10.
//  QUI-153: Tag-Based Note Cards - Primary tag badge component
//

import SwiftUI
import CoreData

/// Large, prominent badge for displaying a primary tag on note cards
/// Displays tag name, icon, and color-coded styling
struct TagBadge: View {
    let tag: Tag
    let size: BadgeSize

    enum BadgeSize {
        case large  // For note cards
        case medium // For headers
        case small  // For compact displays

        var fontSize: CGFloat {
            switch self {
            case .large: return 14
            case .medium: return 12
            case .small: return 10
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .large: return 14
            case .medium: return 12
            case .small: return 10
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .large: return 14
            case .medium: return 12
            case .small: return 10
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .large: return 8
            case .medium: return 6
            case .small: return 5
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .large: return 8
            case .medium: return 6
            case .small: return 5
            }
        }
    }

    init(tag: Tag, size: BadgeSize = .large) {
        self.tag = tag
        self.size = size
    }

    var body: some View {
        HStack(spacing: 6) {
            // Icon
            Image(systemName: tag.iconName)
                .font(.system(size: size.iconSize, weight: .semibold))
                .foregroundColor(.white)

            // Tag name
            Text(tag.name.uppercased())
                .font(.system(size: size.fontSize, weight: .bold, design: .default))
                .foregroundColor(.white)
                .tracking(0.5)
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(
            LinearGradient(
                colors: [tagColor, tagColor.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(size.cornerRadius)
        .shadow(color: tagColor.opacity(0.3), radius: 2, x: 0, y: 1)
    }

    private var tagColor: Color {
        tag.colorForDisplay()
    }
}

// MARK: - Preview

#Preview("Primary Tags - Large") {
    VStack(spacing: 12) {
        // Contact
        TagBadge(
            tag: {
                let tag = Tag(context: CoreDataStack.preview.viewContext)
                tag.name = "contact"
                return tag
            }(),
            size: .large
        )

        // Event
        TagBadge(
            tag: {
                let tag = Tag(context: CoreDataStack.preview.viewContext)
                tag.name = "event"
                return tag
            }(),
            size: .large
        )

        // Todo
        TagBadge(
            tag: {
                let tag = Tag(context: CoreDataStack.preview.viewContext)
                tag.name = "todo"
                return tag
            }(),
            size: .large
        )

        // Meeting
        TagBadge(
            tag: {
                let tag = Tag(context: CoreDataStack.preview.viewContext)
                tag.name = "meeting"
                return tag
            }(),
            size: .large
        )

        // Recipe
        TagBadge(
            tag: {
                let tag = Tag(context: CoreDataStack.preview.viewContext)
                tag.name = "recipe"
                return tag
            }(),
            size: .large
        )

        // General
        TagBadge(
            tag: {
                let tag = Tag(context: CoreDataStack.preview.viewContext)
                tag.name = "general"
                return tag
            }(),
            size: .large
        )
    }
    .padding()
    .background(Color.paperBeige)
}

#Preview("Size Variants") {
    VStack(spacing: 16) {
        // Large
        TagBadge(
            tag: {
                let tag = Tag(context: CoreDataStack.preview.viewContext)
                tag.name = "meeting"
                return tag
            }(),
            size: .large
        )

        // Medium
        TagBadge(
            tag: {
                let tag = Tag(context: CoreDataStack.preview.viewContext)
                tag.name = "meeting"
                return tag
            }(),
            size: .medium
        )

        // Small
        TagBadge(
            tag: {
                let tag = Tag(context: CoreDataStack.preview.viewContext)
                tag.name = "meeting"
                return tag
            }(),
            size: .small
        )
    }
    .padding()
    .background(Color.paperBeige)
}
