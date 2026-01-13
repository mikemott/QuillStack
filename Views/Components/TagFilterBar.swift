//
//  TagFilterBar.swift
//  QuillStack
//
//  QUI-185: Tag filtering for notes list
//

import SwiftUI
import CoreData

/// Horizontal scrolling bar for filtering notes by tags
struct TagFilterBar: View {
    @Binding var selectedTagIds: Set<UUID>
    let availableTags: [Tag]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableTags, id: \.id) { tag in
                    TagFilterChip(
                        tag: tag,
                        isSelected: selectedTagIds.contains(tag.id),
                        onTap: { toggleTag(tag) }
                    )
                }

                // Clear filters button (only shown when filters active)
                if !selectedTagIds.isEmpty {
                    clearFiltersButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.paperBeige.opacity(0.95))
    }

    private func toggleTag(_ tag: Tag) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedTagIds.contains(tag.id) {
                selectedTagIds.remove(tag.id)
            } else {
                selectedTagIds.insert(tag.id)
            }
        }
    }

    private var clearFiltersButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTagIds.removeAll()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                Text("Clear")
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundColor(.textMedium)
            .background(Color.creamLight)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.textLight.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Tag Filter Chip

struct TagFilterChip: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: tag.iconName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))

                Text(tag.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))

                // Note count badge
                Text("\(tag.noteCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .textLight)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? tag.colorForDisplay() : Color.creamLight)
            .foregroundColor(isSelected ? .white : .textDark)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.clear : tag.colorForDisplay().opacity(0.4),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? tag.colorForDisplay().opacity(0.3) : .clear,
                radius: 3,
                x: 0,
                y: 2
            )
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    // Preview requires Core Data context
    Text("TagFilterBar Preview")
        .padding()
}
