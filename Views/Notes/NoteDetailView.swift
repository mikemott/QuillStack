//
//  NoteDetailView.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import SwiftUI
import CoreData

struct NoteDetailView: View {
    @ObservedObject var note: Note
    @State private var editedContent: String = ""
    @State private var originalContent: String = "" // Track original for learning
    @State private var showingEnhanceSheet: Bool = false
    @State private var showingExportSheet: Bool = false
    @State private var showingSummarySheet: Bool = false
    @State private var showingAddPageSheet: Bool = false
    @State private var showingPageNavigator: Bool = false
    @State private var isEnhancing: Bool = false
    @State private var enhanceError: String?
    @State private var hasPendingEnhancement: Bool = false
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                // Slim Header
                slimHeader

                // Content area - always editable
                TextEditor(text: $editedContent)
                    .font(.serifBody(17, weight: .regular))
                    .foregroundColor(.textDark)
                    .lineSpacing(8)
                    .scrollContentBackground(.hidden)
                    .padding(20)
                    .background(contentBackground)

                // Bottom action bar
                bottomBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            editedContent = note.content
            originalContent = note.content // Track for learning
            checkPendingEnhancement()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NoteEnhancementCompleted"))) { notification in
            // Refresh content when enhancement completes
            if let noteId = notification.userInfo?["noteId"] as? UUID,
               noteId == note.id {
                // Refresh the note content from Core Data
                note.managedObjectContext?.refresh(note, mergeChanges: true)
                editedContent = note.content
                hasPendingEnhancement = false
            }
        }
        .onChange(of: editedContent) { _, newValue in
            // Auto-save on every change
            if newValue != note.content {
                saveChanges()
            }
        }
        .sheet(isPresented: $showingEnhanceSheet) {
            enhanceSheet
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportSheet(note: note)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingSummarySheet) {
            SummarySheet(note: note)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showingAddPageSheet) {
            AddPageSheet(note: note)
        }
        .fullScreenCover(isPresented: $showingPageNavigator) {
            PageNavigatorView(note: note)
        }
    }

    private var contentBackground: some View {
        LinearGradient(
            colors: [Color.paperBeige.opacity(0.98), Color.paperTan.opacity(0.98)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func saveChanges() {
        // Detect corrections for handwriting learning before saving
        if editedContent != originalContent {
            HandwritingLearningService.shared.detectCorrections(
                original: originalContent,
                edited: editedContent
            )
            // Update original to current for next comparison
            originalContent = editedContent
        }

        note.content = editedContent
        note.updatedAt = Date()
        try? CoreDataStack.shared.saveViewContext()
    }

    private func checkPendingEnhancement() {
        Task {
            hasPendingEnhancement = await OfflineQueueService.shared.hasPendingEnhancement(for: note.id)
        }
    }

    // MARK: - Slim Header

    private var slimHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Back button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.forestLight)
                }
                .accessibilityLabel("Back to notes")

                // Title
                Text(noteTitle)
                    .font(.serifBody(17, weight: .semibold))
                    .foregroundColor(.forestLight)
                    .lineLimit(1)

                Spacer()

                // Pending enhancement indicator
                if hasPendingEnhancement {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12))
                        Text("Enhancing...")
                            .font(.serifCaption(11, weight: .medium))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)
                }

                // Badge
                noteTypeBadge
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // Metadata row
            HStack(spacing: 12) {
                Text(formattedDate)
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textLight.opacity(0.8))

                Text("•")
                    .foregroundColor(.textLight.opacity(0.5))

                Text("\(wordCount) words")
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textLight.opacity(0.8))

                if note.ocrConfidence > 0 {
                    Text("•")
                        .foregroundColor(.textLight.opacity(0.5))

                    Text("\(Int(note.ocrConfidence * 100))%")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textLight.opacity(0.8))
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
            // AI menu (only show if API key configured)
            if settings.hasAPIKey {
                Menu {
                    Button(action: { showingEnhanceSheet = true }) {
                        Label("Enhance Text", systemImage: "wand.and.stars")
                    }
                    Button(action: { showingSummarySheet = true }) {
                        Label("Summarize", systemImage: "text.quote")
                    }
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.forestDark)
                }
            }

            // Multi-page menu
            Menu {
                Button(action: { showingAddPageSheet = true }) {
                    Label("Add Page", systemImage: "plus.rectangle.on.rectangle")
                }
                if note.pageCount > 0 {
                    Button(action: { showingPageNavigator = true }) {
                        Label("View Pages (\(note.pageCount))", systemImage: "doc.on.doc")
                    }
                }
            } label: {
                Image(systemName: note.pageCount > 1 ? "doc.on.doc.fill" : "doc.on.doc")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.forestDark)
            }

            Spacer()

            // Export
            Button(action: { showingExportSheet = true }) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            // Share
            Button(action: shareNote) {
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

    // MARK: - Enhance Sheet

    private var enhanceSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isEnhancing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Enhancing text with AI...")
                            .font(.serifBody(15, weight: .medium))
                            .foregroundColor(.textMedium)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = enhanceError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("Enhancement Failed")
                            .font(.serifHeadline(18, weight: .semibold))
                            .foregroundColor(.textDark)
                        Text(error)
                            .font(.serifBody(14, weight: .regular))
                            .foregroundColor(.textMedium)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            enhanceError = nil
                            performEnhancement()
                        }
                        .font(.serifBody(15, weight: .semibold))
                        .foregroundColor(.forestDark)
                    }
                    .padding(20)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AI Enhancement")
                            .font(.serifHeadline(20, weight: .semibold))
                            .foregroundColor(.textDark)

                        Text("Use Claude AI to clean up OCR errors and improve text quality. This will analyze your text and fix common recognition mistakes.")
                            .font(.serifBody(14, weight: .regular))
                            .foregroundColor(.textMedium)

                        Spacer()

                        Button(action: performEnhancement) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Enhance Text")
                            }
                            .font(.serifBody(16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.forestDark)
                            .cornerRadius(10)
                        }
                    }
                    .padding(20)
                }
            }
            .background(Color.creamLight)
            .navigationTitle("AI Enhancement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingEnhanceSheet = false
                        enhanceError = nil
                    }
                    .foregroundColor(.forestDark)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func performEnhancement() {
        isEnhancing = true
        enhanceError = nil

        Task {
            do {
                let result = try await LLMService.shared.enhanceOCRText(editedContent, noteType: note.noteType)
                await MainActor.run {
                    editedContent = result.enhancedText
                    saveChanges()
                    isEnhancing = false
                    showingEnhanceSheet = false
                }
            } catch {
                await MainActor.run {
                    enhanceError = error.localizedDescription
                    isEnhancing = false
                }
            }
        }
    }

    // MARK: - Badge

    private var noteTypeBadge: some View {
        Text(note.noteType.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .tracking(0.5)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [badgeColor, badgeColor.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(4)
            .shadow(color: badgeColor.opacity(0.3), radius: 2, x: 0, y: 1)
    }

    // MARK: - Helpers

    private var noteTitle: String {
        let firstLine = editedContent.components(separatedBy: .newlines).first ?? "Note"
        return firstLine.truncated(to: 30)
    }

    private var wordCount: Int {
        editedContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }

    private var formattedDate: String {
        note.createdAt.formattedForNotes()
    }

    private var badgeColor: Color {
        switch note.noteType.lowercased() {
        case "todo": return .badgeTodo
        case "meeting": return .badgeMeeting
        default: return .badgeGeneral
        }
    }

    private func shareNote() {
        let activityVC = UIActivityViewController(
            activityItems: [editedContent],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    private func copyContent() {
        UIPasteboard.general.string = editedContent
    }
}

#Preview {
    NoteDetailView(note: Note())
}
