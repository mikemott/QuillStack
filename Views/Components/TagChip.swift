//
//  TagChip.swift
//  QuillStack
//
//  Created on 2026-01-09.
//  QUI-162: Tag Review & Editor UI
//

import SwiftUI

/// Reusable tag chip component for displaying and managing tags
struct TagChip: View {
    let tag: String
    let removable: Bool
    let isPrimary: Bool
    let onRemove: (() -> Void)?

    // Optional metadata for display
    let usageCount: Int?
    let isNew: Bool

    init(
        tag: String,
        removable: Bool = false,
        isPrimary: Bool = false,
        usageCount: Int? = nil,
        isNew: Bool = false,
        onRemove: (() -> Void)? = nil
    ) {
        self.tag = tag
        self.removable = removable
        self.isPrimary = isPrimary
        self.usageCount = usageCount
        self.isNew = isNew
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: 6) {
            // Tag icon (different for primary tags)
            if isPrimary {
                Image(systemName: "tag.fill")
                    .font(.system(size: 10, weight: .semibold))
            } else if isNew {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .medium))
            } else {
                Image(systemName: "tag")
                    .font(.system(size: 10, weight: .regular))
            }

            // Tag text
            Text(tag)
                .font(.system(size: 13, weight: isPrimary ? .semibold : .medium))

            // Usage count (if provided)
            if let count = usageCount {
                Text("·")
                    .font(.system(size: 10, weight: .regular))
                    .opacity(0.5)
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.7)
            }

            // New tag indicator
            if isNew {
                Text("NEW")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.forestMedium)
                    .cornerRadius(3)
            }

            // Remove button (if removable)
            if removable, let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textLight.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: isPrimary ? 2 : 1)
        )
    }

    // MARK: - Styling

    private var backgroundColor: Color {
        if isPrimary {
            return Color.forestLight.opacity(0.2)
        } else if isNew {
            return Color.forestMedium.opacity(0.1)
        } else {
            return Color.creamLight
        }
    }

    private var foregroundColor: Color {
        if isPrimary {
            return .forestDark
        } else {
            return .textDark
        }
    }

    private var borderColor: Color {
        if isPrimary {
            return .forestMedium
        } else if isNew {
            return .forestMedium.opacity(0.4)
        } else {
            return .textLight.opacity(0.3)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Primary tag
        TagChip(
            tag: "work",
            isPrimary: true
        )

        // Regular tag with usage count
        TagChip(
            tag: "meeting",
            usageCount: 12
        )

        // New tag
        TagChip(
            tag: "q4-planning",
            isNew: true
        )

        // Removable tag
        TagChip(
            tag: "project",
            removable: true,
            onRemove: {
                print("Remove tag")
            }
        )

        // Primary removable tag
        TagChip(
            tag: "urgent",
            removable: true,
            isPrimary: true,
            onRemove: {
                print("Remove primary tag")
            }
        )

        // All tags together
        HStack {
            TagChip(tag: "work", isPrimary: true)
            TagChip(tag: "meeting", usageCount: 8)
            TagChip(tag: "budget", isNew: true)
        }
    }
    .padding()
    .background(Color.paperBeige)
}
