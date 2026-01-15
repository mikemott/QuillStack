//
//  TagDisplaySection.swift
//  QuillStack
//
//  Created on 2026-01-13.
//  QUI-184: Reusable tag display section for detail views
//

import SwiftUI
import CoreData

/// Reusable tag display section for detail views
/// Shows primary tag badge, secondary tags as chips, and edit button
struct TagDisplaySection: View {
    @ObservedObject var note: Note
    @Binding var showingTagEditor: Bool

    /// Whether to show tags even when empty (shows "Add tags" prompt)
    var showWhenEmpty: Bool = false

    /// Compact mode reduces spacing and uses smaller sizes
    var compact: Bool = false

    var body: some View {
        let hasTags = note.primaryTag != nil || !note.secondaryTags.isEmpty

        if hasTags || showWhenEmpty {
            VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                // Header row with title and edit button
                HStack(spacing: 8) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: compact ? 12 : 14, weight: .medium))
                        .foregroundColor(.textMedium)
                    Text("Tags")
                        .font(.serifBody(compact ? 12 : 14, weight: .semibold))
                        .foregroundColor(.textMedium)

                    Spacer()

                    // Edit tags button
                    Button(action: { showingTagEditor = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: compact ? 11 : 12, weight: .medium))
                            Text("Edit")
                                .font(.system(size: compact ? 11 : 12, weight: .medium))
                        }
                        .foregroundColor(.forestMedium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.forestMedium.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .accessibilityLabel("Edit tags")
                }

                if hasTags {
                    // Tags container - groups primary and secondary tags together
                    VStack(alignment: .leading, spacing: compact ? 8 : 10) {
                        // Primary tag badge
                        if let primaryTag = note.primaryTag {
                            TagBadge(tag: primaryTag, size: compact ? .small : .medium)
                        }

                        // Secondary tags - properly contained within the VStack
                        if !note.secondaryTags.isEmpty {
                            WrapFlowLayout(spacing: compact ? 6 : 8) {
                                ForEach(note.secondaryTags, id: \.id) { tag in
                                    TagChip(tag: tag.name, removable: false, isPrimary: false)
                                }
                            }
                        }
                    }
                } else {
                    // Empty state - prompt to add tags
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.textMedium.opacity(0.6))
                        Text("Tap Edit to add tags")
                            .font(.serifBody(14, weight: .regular))
                            .foregroundColor(.textMedium.opacity(0.6))
                            .italic()
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(compact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.creamLight.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.forestDark.opacity(0.1), lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilityDescription)
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var description = "Tags section. "
        if let primary = note.primaryTag {
            description += "Primary tag: \(primary.name). "
        }
        if !note.secondaryTags.isEmpty {
            let tagNames = note.secondaryTags.map { $0.name }.joined(separator: ", ")
            description += "Secondary tags: \(tagNames). "
        }
        if note.primaryTag == nil && note.secondaryTags.isEmpty {
            description += "No tags. "
        }
        description += "Double tap Edit to manage tags."
        return description
    }
}

// MARK: - Preview

#Preview("With Tags") {
    let context = CoreDataStack.preview.context
    let note = Note.create(
        in: context,
        content: "Sample note with tags",
        noteType: "general"
    )

    // Add tags
    let workTag = Tag.findOrCreate(name: "work", in: context)
    let projectTag = Tag.findOrCreate(name: "project", in: context)
    let urgentTag = Tag.findOrCreate(name: "urgent", in: context)
    note.addToTagEntities(workTag)
    note.addToTagEntities(projectTag)
    note.addToTagEntities(urgentTag)

    return VStack(spacing: 20) {
        TagDisplaySection(note: note, showingTagEditor: .constant(false))
        TagDisplaySection(note: note, showingTagEditor: .constant(false), compact: true)
    }
    .padding()
    .background(Color.paperBeige)
    .environment(\.managedObjectContext, context)
}

#Preview("Empty") {
    let context = CoreDataStack.preview.context
    let note = Note.create(
        in: context,
        content: "Note without tags",
        noteType: "general"
    )

    return VStack(spacing: 20) {
        TagDisplaySection(note: note, showingTagEditor: .constant(false), showWhenEmpty: true)
        TagDisplaySection(note: note, showingTagEditor: .constant(false), showWhenEmpty: false)
    }
    .padding()
    .background(Color.paperBeige)
    .environment(\.managedObjectContext, context)
}

#Preview("Primary Only") {
    let context = CoreDataStack.preview.context
    let note = Note.create(
        in: context,
        content: "Note with only primary tag",
        noteType: "meeting"
    )

    let meetingTag = Tag.findOrCreate(name: "meeting", in: context)
    note.addToTagEntities(meetingTag)

    return TagDisplaySection(note: note, showingTagEditor: .constant(false))
        .padding()
        .background(Color.paperBeige)
        .environment(\.managedObjectContext, context)
}
