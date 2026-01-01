//
//  IdeaDetailView.swift
//  QuillStack
//
//  Created on 2025-12-31.
//

import SwiftUI
import CoreData

struct IdeaDetailView: View, NoteDetailViewProtocol {
    @ObservedObject var note: Note
    @State private var editedContent: String = ""
    @State private var expandedIdea: String = ""
    @State private var isExpanding: Bool = false
    @State private var expandError: String?
    @State private var showingExpandSheet: Bool = false
    @State private var showingExportSheet: Bool = false
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                slimHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Original idea section
                        originalIdeaSection

                        // Tags section
                        tagsSection

                        // Expanded idea section (if available)
                        if !expandedIdea.isEmpty {
                            expandedIdeaSection
                        }
                    }
                    .padding(20)
                }
                .background(contentBackground)

                bottomBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            editedContent = note.content
            expandedIdea = note.summary ?? ""
            loadTags()
        }
        .onChange(of: editedContent) { _, newValue in
            if newValue != note.content {
                saveChanges()
            }
        }
        .sheet(isPresented: $showingExpandSheet) {
            expandSheet
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportSheet(note: note)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Content Background

    private var contentBackground: some View {
        LinearGradient(
            colors: [Color.paperBeige.opacity(0.98), Color.paperTan.opacity(0.98)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Original Idea Section

    private var originalIdeaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.badgeIdea)
                Text("Quick Capture")
                    .font(.serifBody(15, weight: .semibold))
                    .foregroundColor(.textMedium)
            }

            TextEditor(text: $editedContent)
                .font(.serifBody(17, weight: .regular))
                .foregroundColor(.textDark)
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(12)
                .background(Color.white.opacity(0.5))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.badgeIdea.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag")
                    .foregroundColor(.textMedium)
                Text("Tags")
                    .font(.serifBody(15, weight: .semibold))
                    .foregroundColor(.textMedium)
            }

            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    tagChip(tag)
                }
                addTagButton
            }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.serifCaption(13, weight: .medium))
                .foregroundColor(.forestDark)

            Button(action: { removeTag(tag) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.forestDark.opacity(0.6))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.forestLight.opacity(0.5))
        .cornerRadius(12)
    }

    private var addTagButton: some View {
        HStack(spacing: 4) {
            if !newTag.isEmpty {
                TextField("Tag", text: $newTag)
                    .font(.serifCaption(13, weight: .medium))
                    .foregroundColor(.forestDark)
                    .frame(width: 80)
                    .onSubmit {
                        addTag()
                    }

                Button(action: addTag) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.forestDark)
                }
            } else {
                Button(action: { newTag = " " }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add Tag")
                            .font(.serifCaption(13, weight: .medium))
                    }
                    .foregroundColor(.forestDark.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.forestDark.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Expanded Idea Section

    private var expandedIdeaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.badgeIdea)
                Text("Expanded Thought")
                    .font(.serifBody(15, weight: .semibold))
                    .foregroundColor(.textMedium)
                Spacer()
                Button(action: { expandedIdea = "" }) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.textMedium.opacity(0.6))
                }
            }

            Text(expandedIdea)
                .font(.serifBody(16, weight: .regular))
                .foregroundColor(.textDark)
                .lineSpacing(6)
                .padding(12)
                .background(Color.badgeIdea.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.badgeIdea.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Slim Header

    private var slimHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.forestLight)
                }
                .accessibilityLabel("Back to notes")

                Text("Idea")
                    .font(.serifBody(17, weight: .semibold))
                    .foregroundColor(.forestLight)
                    .lineLimit(1)

                Spacer()

                noteTypeBadge
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            HStack(spacing: 12) {
                Text(note.createdAt.formattedForNotes())
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textLight.opacity(0.8))

                if !expandedIdea.isEmpty {
                    Text("•")
                        .foregroundColor(.textLight.opacity(0.5))
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                        Text("Expanded")
                            .font(.serifCaption(12, weight: .regular))
                    }
                    .foregroundColor(.badgeIdea)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(
            LinearGradient(
                colors: [Color.forestMedium, Color.forestDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 20) {
            // Expand with AI (main action)
            if settings.hasAPIKey {
                Button(action: { showingExpandSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Expand")
                    }
                    .font(.serifBody(15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.badgeIdea)
                    .cornerRadius(8)
                }
            }

            Spacer()

            // Export
            Button(action: { showingExportSheet = true }) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            // Share
            Button(action: shareIdea) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            // Copy
            Button(action: copyContent) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.creamLight)
        .overlay(
            Rectangle()
                .fill(Color.forestDark.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Expand Sheet

    private var expandSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isExpanding {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Expanding your idea...")
                            .font(.serifBody(15, weight: .medium))
                            .foregroundColor(.textMedium)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = expandError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("Expansion Failed")
                            .font(.serifHeadline(18, weight: .semibold))
                            .foregroundColor(.textDark)
                        Text(error)
                            .font(.serifBody(14, weight: .regular))
                            .foregroundColor(.textMedium)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            expandError = nil
                            performExpansion()
                        }
                        .font(.serifBody(15, weight: .semibold))
                        .foregroundColor(.forestDark)
                    }
                    .padding(20)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Expand Idea")
                            .font(.serifHeadline(20, weight: .semibold))
                            .foregroundColor(.textDark)

                        Text("Use AI to expand your quick note into a fuller thought. Great for capturing fleeting ideas and developing them later.")
                            .font(.serifBody(14, weight: .regular))
                            .foregroundColor(.textMedium)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your idea:")
                                .font(.serifCaption(12, weight: .medium))
                                .foregroundColor(.textMedium)
                            Text(editedContent)
                                .font(.serifBody(15, weight: .regular))
                                .foregroundColor(.textDark)
                                .padding(12)
                                .background(Color.forestLight.opacity(0.3))
                                .cornerRadius(8)
                        }

                        Spacer()

                        Button(action: performExpansion) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Expand Idea")
                            }
                            .font(.serifBody(16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.badgeIdea)
                            .cornerRadius(10)
                        }
                    }
                    .padding(20)
                }
            }
            .background(Color.creamLight)
            .navigationTitle("AI Expansion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingExpandSheet = false
                        expandError = nil
                    }
                    .foregroundColor(.forestDark)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func performExpansion() {
        isExpanding = true
        expandError = nil

        Task {
            do {
                let expanded = try await LLMService.shared.expandIdea(editedContent)
                await MainActor.run {
                    expandedIdea = expanded
                    note.summary = expanded
                    try? CoreDataStack.shared.saveViewContext()
                    isExpanding = false
                    showingExpandSheet = false
                }
            } catch {
                await MainActor.run {
                    expandError = error.localizedDescription
                    isExpanding = false
                }
            }
        }
    }

    func saveChanges() {
        note.content = editedContent
        note.updatedAt = Date()
        saveTags()
        try? CoreDataStack.shared.saveViewContext()
    }

    private func loadTags() {
        // Load tags from note.tags (stored as comma-separated string)
        if let tagString = note.tags, !tagString.isEmpty {
            tags = tagString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
    }

    private func saveTags() {
        note.tags = tags.joined(separator: ",")
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty && !tags.contains(tag) {
            tags.append(tag)
            saveTags()
        }
        newTag = ""
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        saveTags()
    }

    private func shareIdea() {
        var content = editedContent
        if !expandedIdea.isEmpty {
            content += "\n\n---\nExpanded:\n\(expandedIdea)"
        }
        if !tags.isEmpty {
            content += "\n\nTags: " + tags.map { "#\($0)" }.joined(separator: " ")
        }

        let activityVC = UIActivityViewController(
            activityItems: [content],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    private func copyContent() {
        var content = editedContent
        if !expandedIdea.isEmpty {
            content += "\n\n---\nExpanded:\n\(expandedIdea)"
        }
        UIPasteboard.general.string = content
    }

    // MARK: - Badge

    private var noteTypeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "lightbulb")
                .font(.system(size: 10, weight: .bold))
            Text("IDEA")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: [Color.badgeIdea, Color.badgeIdea.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(4)
        .shadow(color: Color.badgeIdea.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

// FlowLayout is defined in ConfidenceTextView.swift

#Preview {
    IdeaDetailView(note: Note())
}
