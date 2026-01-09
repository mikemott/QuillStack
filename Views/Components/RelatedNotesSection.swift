//
//  RelatedNotesSection.swift
//  QuillStack
//
//  Created on 2026-01-09.
//  QUI-161: Automatic Cross-Linking
//

import SwiftUI
import CoreData

/// Displays related notes in a detail view with relationship indicators
struct RelatedNotesSection: View {
    let note: Note
    let onNoteSelected: (Note) -> Void

    @Environment(\.managedObjectContext) private var viewContext

    /// Combined list of all related notes (both incoming and outgoing links)
    private var relatedNotes: [(note: Note, links: [NoteLink])] {
        // Get all unique related notes and their links
        var noteToLinks: [UUID: (note: Note, links: [NoteLink])] = [:]

        // Process outgoing links
        for link in note.typedOutgoingLinks {
            let targetId = link.targetNote.id
            if noteToLinks[targetId] == nil {
                noteToLinks[targetId] = (link.targetNote, [link])
            } else {
                noteToLinks[targetId]?.links.append(link)
            }
        }

        // Process incoming links
        for link in note.typedIncomingLinks {
            let sourceId = link.sourceNote.id
            if noteToLinks[sourceId] == nil {
                noteToLinks[sourceId] = (link.sourceNote, [link])
            } else {
                noteToLinks[sourceId]?.links.append(link)
            }
        }

        // Sort by most recent link creation
        return noteToLinks.values.sorted { first, second in
            let firstDate = first.links.map(\.createdAt).max() ?? .distantPast
            let secondDate = second.links.map(\.createdAt).max() ?? .distantPast
            return firstDate > secondDate
        }
    }

    var body: some View {
        if !relatedNotes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Section header
                HStack {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.forestMedium)

                    Text("Related Notes")
                        .font(.serifBody(16, weight: .semibold))
                        .foregroundColor(.forestDark)

                    Spacer()

                    // Count badge
                    Text("\(relatedNotes.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.forestMedium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.forestMedium.opacity(0.15))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Related notes list
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(relatedNotes, id: \.note.id) { item in
                            RelatedNoteCard(
                                note: item.note,
                                links: item.links,
                                onTap: {
                                    onNoteSelected(item.note)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }
}

// MARK: - Related Note Card

/// Individual card for a related note
struct RelatedNoteCard: View {
    let note: Note
    let links: [NoteLink]
    let onTap: () -> Void

    // Most prominent relationship (highest confidence or manual)
    private var primaryLink: NoteLink {
        links.sorted { first, second in
            // Manual links take precedence
            if first.isAutomatic != second.isAutomatic {
                return !first.isAutomatic
            }
            // Otherwise sort by confidence
            return first.confidence > second.confidence
        }.first!
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Note type badge + relationship icon
                HStack(spacing: 6) {
                    // Relationship type indicator
                    Image(systemName: primaryLink.type.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(linkColor)

                    Text(primaryLink.type.description)
                        .font(.serifCaption(11, weight: .medium))
                        .foregroundColor(linkColor)

                    Spacer()

                    // Automatic link indicator (show confidence)
                    if primaryLink.isAutomatic {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                            Text("\(Int(primaryLink.confidence * 100))%")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.forestMedium.opacity(0.7))
                    }
                }

                // Note content preview
                Text(contentPreview)
                    .font(.serifBody(14, weight: .regular))
                    .foregroundColor(.textDark)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Note metadata
                HStack {
                    // Note type
                    HStack(spacing: 3) {
                        if let icon = noteTypeIcon {
                            Image(systemName: icon)
                                .font(.system(size: 9))
                        }
                        Text(note.noteType.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(noteTypeColor)
                    .cornerRadius(4)

                    Spacer()

                    // Date
                    Text(note.createdAt.formattedForNotes())
                        .font(.serifCaption(10, weight: .regular))
                        .foregroundColor(.textLight.opacity(0.7))
                }
            }
            .padding(12)
            .frame(width: 240, height: 140)
            .background(Color.creamLight)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(linkColor.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helpers

    private var contentPreview: String {
        let preview = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if preview.count > 120 {
            return String(preview.prefix(120)) + "..."
        }
        return preview
    }

    private var linkColor: Color {
        switch primaryLink.type {
        case .mentionsSamePerson:
            return .blue
        case .sameTopic:
            return .purple
        case .temporalRelationship:
            return .orange
        case .semanticSimilarity:
            return .green
        case .related:
            return .forestMedium
        default:
            return .forestLight
        }
    }

    private var noteTypeIcon: String? {
        switch note.noteType.lowercased() {
        case "todo": return "checkmark.square"
        case "meeting": return "calendar"
        case "email": return "envelope"
        case "reminder": return "bell"
        case "contact": return "person.crop.circle"
        default: return nil
        }
    }

    private var noteTypeColor: Color {
        switch note.noteType.lowercased() {
        case "todo": return .badgeTodo
        case "meeting": return .badgeMeeting
        case "email": return .badgeEmail
        case "reminder": return .badgeReminder
        case "contact": return .badgeContact
        default: return .badgeGeneral
        }
    }
}

// MARK: - Preview

#Preview {
    let context = CoreDataStack.preview.context

    // Create sample notes with relationships
    let note1 = Note.create(in: context, content: "Weekly team meeting on Q4 goals and budget planning", noteType: "meeting")
    let note2 = Note.create(in: context, content: "Q4 budget spreadsheet - need to finalize by Friday", noteType: "todo")
    let note3 = Note.create(in: context, content: "Follow-up: Review Q4 goals with Sarah next week", noteType: "meeting")

    // Create links
    let link1 = NoteLink.create(
        in: context,
        from: note1,
        to: note2,
        type: .sameTopic,
        label: "Both about Q4 budget",
        confidence: 0.92,
        isAutomatic: true
    )

    let link2 = NoteLink.create(
        in: context,
        from: note1,
        to: note3,
        type: .temporalRelationship,
        label: "Follow-up meeting",
        confidence: 0.88,
        isAutomatic: true
    )

    return ScrollView {
        VStack(spacing: 20) {
            RelatedNotesSection(note: note1) { selectedNote in
                print("Selected: \(selectedNote.content)")
            }
            .padding()
        }
    }
    .environment(\.managedObjectContext, context)
    .background(Color.paperBeige)
}
