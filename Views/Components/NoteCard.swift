//
//  NoteCard.swift
//  QuillStack
//
//  Created on 2026-01-10.
//  QUI-153: Tag-Based Note Cards - Main card component for displaying notes
//

import SwiftUI
import CoreData

/// Modern note card with tag-based visual system
/// Features:
/// - Primary tag badge (large, colored)
/// - Secondary tags (small chips)
/// - Preview text (first 2-3 lines)
/// - Metadata (date, word count, related count)
/// - Enhanced indicator (✨)
/// - Processing state indicator (⏳)
/// - Color-coded borders based on primary tag
struct NoteCard: View {
    @ObservedObject var note: Note
    var isSelected: Bool = false
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Primary tag badge + State indicators
            HStack(spacing: 8) {
                // Primary tag badge
                if let primaryTag = note.primaryTag {
                    TagBadge(tag: primaryTag, size: .large)
                } else {
                    // Fallback for notes without tags
                    fallbackBadge
                }

                // Enhanced indicator
                if note.isLlmEnhanced {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.forestMedium)
                        .accessibilityLabel("Enhanced with AI")
                }

                // Processing state indicator
                if note.processingState == .ocrOnly {
                    HStack(spacing: 4) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 11, weight: .medium))
                        Text("Offline")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(4)
                    .accessibilityLabel("Note captured offline")
                } else if note.processingState == .pendingEnhancement || note.processingState == .processing {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11, weight: .medium))
                        Text("Queued")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(4)
                    .accessibilityLabel("Note queued for enhancement")
                }

                Spacer()

                // Date
                Text(formattedDate)
                    .font(.serifCaption(13, weight: .medium))
                    .foregroundColor(.textMedium)
                    .italic()
            }

            // Secondary tags (if any)
            if !note.secondaryTags.isEmpty {
                secondaryTagsView
            }

            // Preview text (first 2-3 lines)
            Text(note.previewText.isEmpty ? note.content : note.previewText)
                .font(.serifBody(15, weight: .regular))
                .foregroundColor(.textDark)
                .lineSpacing(6)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            // Footer: Metadata
            HStack(spacing: 16) {
                // Word count
                metadataItem(
                    icon: "text.word.spacing",
                    text: "\(note.wordCount) words"
                )

                // Related notes count (if any)
                if note.relatedNotesCount > 0 {
                    metadataItem(
                        icon: "link",
                        text: "\(note.relatedNotesCount) linked"
                    )
                }

                Spacer()

                // OCR confidence
                HStack(spacing: 6) {
                    Text("\(Int(note.ocrConfidence * 100))%")
                        .font(.serifCaption(12, weight: .medium))
                        .foregroundColor(.textMedium)

                    // Confidence bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color.forestDark.opacity(0.15))
                                .frame(height: 3)
                                .cornerRadius(2)

                            // Fill
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [note.primaryTagColor, note.primaryTagColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(note.ocrConfidence), height: 3)
                                .cornerRadius(2)
                        }
                    }
                    .frame(width: 60, height: 3)
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(
            ZStack(alignment: .leading) {
                // Paper-like background
                LinearGradient(
                    colors: [Color.paperBeige.opacity(0.95), Color.paperTan.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Color-coded left border (based on primary tag)
                Rectangle()
                    .fill(note.primaryTagColor)
                    .frame(width: (isPressed || isSelected) ? 4 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isPressed)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? note.primaryTagColor : note.primaryTagColor.opacity(0.2),
                    lineWidth: isSelected ? 2 : 1
                )
                .animation(.easeInOut(duration: 0.15), value: isSelected)
        )
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    // MARK: - Subviews

    private var fallbackBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Text("GENERAL")
                .font(.system(size: 14, weight: .bold, design: .default))
                .foregroundColor(.white)
                .tracking(0.5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.forestMedium, Color.forestMedium.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(8)
        .shadow(color: Color.forestMedium.opacity(0.3), radius: 2, x: 0, y: 1)
    }

    private var secondaryTagsView: some View {
        WrapFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(note.secondaryTags, id: \.id) { tag in
                TagChip(tag: tag.name, removable: false, isPrimary: false)
            }
        }
    }

    private func metadataItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.textMedium)
            Text(text)
                .font(.serifCaption(12, weight: .regular))
                .foregroundColor(.textMedium)
        }
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(note.createdAt) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today, \(formatter.string(from: note.createdAt))"
        } else if calendar.isDateInYesterday(note.createdAt) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: note.createdAt)
        }
    }
}

// MARK: - Preview

#Preview("Note Card with Tags") {
    let context = CoreDataStack.preview.viewContext

    // Create a sample note with tags
    let note = Note(context: context)
    note.content = "Discussed Q4 planning with the team. Key action items:\n- Finalize budget proposal\n- Review hiring plan\n- Set OKRs for next quarter"
    note.createdAt = Date()
    note.ocrConfidence = 0.92
    note.processingState = .enhanced

    // Add tags
    let meetingTag = Tag.findOrCreate(name: "meeting", in: context)
    let workTag = Tag.findOrCreate(name: "work", in: context)
    note.addToTagEntities(meetingTag)
    note.addToTagEntities(workTag)

    return VStack(spacing: 16) {
        NoteCard(note: note)
        NoteCard(note: note, isSelected: true)
    }
    .padding()
    .background(Color.creamLight)
}

#Preview("Note Card - Processing States") {
    let context = CoreDataStack.preview.viewContext

    // Offline note
    let offlineNote = Note(context: context)
    offlineNote.content = "Quick meeting notes captured offline. Will enhance when back online."
    offlineNote.createdAt = Date()
    offlineNote.processingState = .ocrOnly
    offlineNote.ocrConfidence = 0.85
    let todoTag1 = Tag.findOrCreate(name: "todo", in: context)
    offlineNote.addToTagEntities(todoTag1)

    // Queued note
    let queuedNote = Note(context: context)
    queuedNote.content = "Event details that are waiting to be processed and enhanced."
    queuedNote.createdAt = Date().addingTimeInterval(-3600)
    queuedNote.processingState = .pendingEnhancement
    queuedNote.ocrConfidence = 0.88
    let eventTag = Tag.findOrCreate(name: "event", in: context)
    queuedNote.addToTagEntities(eventTag)

    return VStack(spacing: 16) {
        NoteCard(note: offlineNote)
        NoteCard(note: queuedNote)
    }
    .padding()
    .background(Color.creamLight)
}

#Preview("Different Tag Types") {
    let context = CoreDataStack.preview.viewContext

    // Contact note
    let contactNote = Note(context: context)
    contactNote.content = "John Smith\njohn@example.com\n(555) 123-4567"
    contactNote.createdAt = Date()
    contactNote.ocrConfidence = 0.95
    let contactTag = Tag.findOrCreate(name: "contact", in: context)
    contactNote.addToTagEntities(contactTag)

    // Recipe note
    let recipeNote = Note(context: context)
    recipeNote.content = "Grandma's Chocolate Chip Cookies\n\nIngredients:\n- 2 cups flour\n- 1 cup butter"
    recipeNote.createdAt = Date().addingTimeInterval(-86400)
    recipeNote.processingState = .enhanced
    recipeNote.ocrConfidence = 0.90
    let recipeTag = Tag.findOrCreate(name: "recipe", in: context)
    let favoriteTag = Tag.findOrCreate(name: "favorite", in: context)
    recipeNote.addToTagEntities(recipeTag)
    recipeNote.addToTagEntities(favoriteTag)

    return VStack(spacing: 16) {
        NoteCard(note: contactNote)
        NoteCard(note: recipeNote)
    }
    .padding()
    .background(Color.creamLight)
}
