//
//  TagEditorSheet.swift
//  QuillStack
//
//  Created on 2026-01-09.
//  QUI-162: Tag Review & Editor UI
//

import SwiftUI
import CoreData
import OSLog

/// Sheet for editing tags on a note
struct TagEditorSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var note: Note

    @State private var newTagText: String = ""
    @State private var suggestedTags: [TagSuggestionItem] = []
    @State private var isLoading: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @FocusState private var isTextFieldFocused: Bool

    private let tagService = TagService.shared
    private let logger = Logger(subsystem: "com.quillstack", category: "TagEditor")

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Current tags section
                    if !currentTags.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current Tags")
                                .font(.serifHeadline(18, weight: .semibold))
                                .foregroundColor(.forestDark)

                            WrapFlowLayout(spacing: 8) {
                                ForEach(currentTags, id: \.self) { tagName in
                                    TagChip(
                                        tag: tagName,
                                        removable: true,
                                        isPrimary: tagName == primaryTag,
                                        onRemove: {
                                            removeTag(tagName)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Add new tag section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Tags")
                            .font(.serifHeadline(18, weight: .semibold))
                            .foregroundColor(.forestDark)

                        HStack(spacing: 12) {
                            Image(systemName: "tag")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.forestMedium)

                            TextField("Enter tag name", text: $newTagText)
                                .font(.serifBody(16, weight: .regular))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isTextFieldFocused)
                                .onSubmit {
                                    addTag(newTagText)
                                }

                            if !newTagText.isEmpty {
                                Button(action: {
                                    addTag(newTagText)
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

                    // Suggested tags section
                    if !suggestedTags.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.forestMedium)

                                Text("Suggested Tags")
                                    .font(.serifHeadline(18, weight: .semibold))
                                    .foregroundColor(.forestDark)
                            }

                            WrapFlowLayout(spacing: 8) {
                                ForEach(suggestedTags, id: \.tag) { suggestion in
                                    if !currentTags.contains(suggestion.tag) {
                                        TagChip(
                                            tag: suggestion.tag,
                                            usageCount: suggestion.usageCount,
                                            isNew: suggestion.isNew
                                        )
                                        .onTapGesture {
                                            addTag(suggestion.tag)
                                        }
                                    }
                                }
                            }

                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .forestMedium))
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                .background(Color.creamLight)
            }
            .background(Color.creamLight)
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.forestDark)
                }
            }
            .task {
                await loadSuggestions()
                isTextFieldFocused = true
            }
            .alert("Error Saving Tag", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Computed Properties

    private var currentTags: [String] {
        note.sortedTagEntities.map { $0.name }
    }

    private var primaryTag: String? {
        currentTags.first
    }

    // MARK: - Tag Management

    private func addTag(_ tagName: String) {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Check if tag already exists
        guard !currentTags.contains(where: { $0.lowercased() == trimmed.lowercased() }) else {
            newTagText = ""
            return
        }

        // Add tag to note
        note.addTagEntity(named: trimmed, in: viewContext)

        // Save immediately
        do {
            try viewContext.save()
            logger.info("Successfully added tag: \(trimmed)")
            newTagText = ""

            // Reload suggestions
            Task {
                await loadSuggestions()
            }
        } catch {
            logger.error("Failed to save tag: \(error.localizedDescription)")
            errorMessage = "Failed to add tag. Please try again."
            showErrorAlert = true
        }
    }

    private func removeTag(_ tagName: String) {
        note.removeTagEntity(named: tagName)

        // Save immediately
        do {
            try viewContext.save()
            logger.info("Successfully removed tag: \(tagName)")

            // Reload suggestions
            Task {
                await loadSuggestions()
            }
        } catch {
            logger.error("Failed to remove tag: \(error.localizedDescription)")
            errorMessage = "Failed to remove tag. Please try again."
            showErrorAlert = true
        }
    }

    // MARK: - Suggestions

    private func loadSuggestions() async {
        isLoading = true
        defer { isLoading = false }

        // Get all existing tags sorted by usage
        let allTags = await tagService.getAllTagNames(context: viewContext)

        // Build suggestions based on:
        // 1. Most frequently used tags (top 20)
        // 2. Tags not already applied to this note
        let topTags = Array(allTags.prefix(20))

        // Batch fetch all tags
        let existingTags = Tag.find(names: topTags, in: viewContext)
        let suggestions = existingTags.map {
            TagSuggestionItem(
                tag: $0.name,
                usageCount: $0.noteCount,
                isNew: false
            )
        }.sorted { $0.usageCount > $1.usageCount }

        await MainActor.run {
            suggestedTags = suggestions
        }
    }
}

// MARK: - Tag Suggestion Model

struct TagSuggestionItem: Hashable {
    let tag: String
    let usageCount: Int
    let isNew: Bool
}

// MARK: - Preview

#Preview {
    let context = CoreDataStack.preview.context
    let note = Note.create(
        in: context,
        content: "Sample note with tags",
        noteType: "general"
    )

    // Add some existing tags
    note.addTagEntity(named: "work", in: context)
    note.addTagEntity(named: "important", in: context)

    // Create some sample tags in the database
    let _ = Tag.create(in: context, name: "meeting")
    let _ = Tag.create(in: context, name: "project")
    let _ = Tag.create(in: context, name: "urgent")

    return TagEditorSheet(note: note)
        .environment(\.managedObjectContext, context)
}
