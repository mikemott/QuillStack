//
//  TagReviewSheet.swift
//  QuillStack
//
//  Created on 2026-01-09.
//  QUI-162: Tag Review & Editor UI
//

import SwiftUI
import CoreData

/// Sheet for reviewing and accepting suggested tags after capture
struct TagReviewSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var note: Note
    let suggestedTags: [String]

    @State private var selectedTags: Set<String> = []
    @State private var customTag: String = ""
    @State private var tagMetadata: [String: TagMetadata] = [:]
    @FocusState private var isTextFieldFocused: Bool

    private let tagService = TagService.shared

    init(note: Note, suggestedTags: [String]) {
        self.note = note
        self.suggestedTags = suggestedTags
        _selectedTags = State(initialValue: Set(suggestedTags))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.forestMedium)

                            Text("Review Tags")
                                .font(.serifHeadline(24, weight: .bold))
                                .foregroundColor(.forestDark)
                        }

                        Text("Select tags to apply to this note")
                            .font(.serifBody(15, weight: .regular))
                            .foregroundColor(.textMedium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    // Suggested tags section
                    if !suggestedTags.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggested Tags")
                                .font(.serifBody(14, weight: .semibold))
                                .foregroundColor(.forestMedium)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            WrapFlowLayout(spacing: 10) {
                                ForEach(suggestedTags, id: \.self) { tag in
                                    TagChip(
                                        tag: tag,
                                        isPrimary: selectedTags.contains(tag),
                                        usageCount: tagMetadata[tag]?.usageCount,
                                        isNew: tagMetadata[tag]?.isNew ?? false
                                    )
                                    .onTapGesture {
                                        toggleTag(tag)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Custom tag section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Custom Tag")
                            .font(.serifBody(14, weight: .semibold))
                            .foregroundColor(.forestMedium)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        HStack(spacing: 12) {
                            Image(systemName: "tag")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.forestMedium)

                            TextField("Enter tag name", text: $customTag)
                                .font(.serifBody(16, weight: .regular))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isTextFieldFocused)
                                .onSubmit {
                                    addCustomTag()
                                }

                            if !customTag.isEmpty {
                                Button(action: {
                                    addCustomTag()
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.forestMedium)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.forestLight, lineWidth: 1.5)
                        )
                    }
                    .padding(.horizontal, 16)

                    // Custom tags added
                    if !customTags.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            WrapFlowLayout(spacing: 10) {
                                ForEach(Array(customTags), id: \.self) { tag in
                                    TagChip(
                                        tag: tag,
                                        removable: true,
                                        isPrimary: selectedTags.contains(tag),
                                        isNew: true,
                                        onRemove: {
                                            removeCustomTag(tag)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer()
                }
                .background(Color.creamLight)
            }
            .background(Color.creamLight)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        dismiss()
                    }
                    .font(.serifBody(16, weight: .regular))
                    .foregroundColor(.textMedium)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyTags()
                        dismiss()
                    }
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.forestDark)
                }
            }
            .task {
                await loadTagMetadata()
            }
        }
    }

    // MARK: - Computed Properties

    private var customTags: Set<String> {
        selectedTags.subtracting(suggestedTags)
    }

    // MARK: - Tag Management

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    private func addCustomTag() {
        let trimmed = customTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Add to selected tags
        selectedTags.insert(trimmed)
        customTag = ""
    }

    private func removeCustomTag(_ tag: String) {
        selectedTags.remove(tag)
    }

    private func applyTags() {
        // Add all selected tags to the note
        for tag in selectedTags {
            note.addTagEntity(named: tag, in: viewContext)
        }

        // Save
        do {
            try viewContext.save()
        } catch {
            print("Error saving tags: \(error)")
        }
    }

    // MARK: - Metadata Loading

    private func loadTagMetadata() async {
        var metadata: [String: TagMetadata] = [:]

        for tag in suggestedTags {
            if let existingTag = Tag.find(name: tag, in: viewContext) {
                metadata[tag] = TagMetadata(
                    usageCount: existingTag.noteCount,
                    isNew: false
                )
            } else {
                metadata[tag] = TagMetadata(
                    usageCount: 0,
                    isNew: true
                )
            }
        }

        await MainActor.run {
            tagMetadata = metadata
        }
    }
}

// MARK: - Supporting Types

struct TagMetadata {
    let usageCount: Int
    let isNew: Bool
}

// MARK: - Preview

#Preview {
    let context = CoreDataStack.preview.context
    let note = Note.create(
        in: context,
        content: "Meeting notes from Q4 planning session with Sarah",
        noteType: "meeting"
    )

    // Create some existing tags
    let workTag = Tag.create(in: context, name: "work")
    let meetingTag = Tag.create(in: context, name: "meeting")
    let _ = Tag.create(in: context, name: "project")

    // Simulate usage
    let note1 = Note.create(in: context, content: "Test 1", noteType: "general")
    let note2 = Note.create(in: context, content: "Test 2", noteType: "general")
    workTag.addToNotes(note1)
    workTag.addToNotes(note2)
    meetingTag.addToNotes(note1)

    return TagReviewSheet(
        note: note,
        suggestedTags: ["work", "meeting", "q4-planning"]
    )
    .environment(\.managedObjectContext, context)
}
