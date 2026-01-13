//
//  NoteDetailView.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import SwiftUI
import CoreData
import PencilKit
import os.log

struct NoteDetailView: View, NoteDetailViewProtocol {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuillStack", category: "NoteDetail")
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
    @State private var saveTask: Task<Void, Never>?
    @State private var showingTypePicker = false
    @State private var showingAnnotationMode = false
    @State private var showingTagEditor = false // QUI-184
    @State private var annotationDrawing = PKDrawing()
    @Bindable private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    /// Debounce delay for auto-save (in nanoseconds)
    private let saveDebounceDelay: UInt64 = 500_000_000 // 500ms

    var body: some View {
        ZStack {
            // Background
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header using shared component
                DetailHeader(
                    title: noteTitle,
                    date: note.createdAt,
                    noteType: note.noteType,
                    onBack: { dismiss() },
                    wordCount: wordCount,
                    ocrConfidence: note.ocrConfidence,
                    hasPendingEnhancement: hasPendingEnhancement,
                    classification: note.classification
                )

                // Content area - scrollable with related notes
                ScrollView {
                    VStack(spacing: 0) {
                        // Tags section (QUI-184)
                        TagDisplaySection(note: note, showingTagEditor: $showingTagEditor)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 12)

                        // Editable content
                        TextEditor(text: $editedContent)
                            .font(.serifBody(17, weight: .regular))
                            .foregroundColor(.textDark)
                            .lineSpacing(8)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 300)
                            .padding(20)
                            .background(contentBackground)

                        // Related notes section (QUI-161)
                        if note.linkCount > 0 {
                            RelatedNotesSection(note: note) { selectedNote in
                                // TODO: Navigate to selected note
                                // For now, just log it
                                print("Selected related note: \(selectedNote.id)")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }

                // Bottom action bar
                bottomBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            editedContent = note.content
            originalContent = note.content // Track for learning
            checkPendingEnhancement()
            loadAnnotation()
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
            // Debounced auto-save to prevent excessive saves on every keystroke
            if newValue != note.content {
                debouncedSave()
            }
        }
        .onDisappear {
            // Cancel pending save and save immediately on dismiss
            saveTask?.cancel()
            if editedContent != note.content {
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
        .sheet(isPresented: $showingTypePicker) {
            NoteTypePickerSheet(note: note)
        }
        .sheet(isPresented: $showingTagEditor) {
            TagEditorSheet(note: note)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showingAnnotationMode) {
            AnnotationModeView(
                note: note,
                drawing: $annotationDrawing,
                onSave: saveAnnotation,
                onCancel: { loadAnnotation() }
            )
        }
    }

    private var contentBackground: some View {
        LinearGradient(
            colors: [Color.paperBeige.opacity(0.98), Color.paperTan.opacity(0.98)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Debounced save - waits for user to stop typing before saving
    private func debouncedSave() {
        // Cancel any pending save
        saveTask?.cancel()

        // Schedule new save with debounce delay
        saveTask = Task {
            do {
                try await Task.sleep(nanoseconds: saveDebounceDelay)
                // Check if cancelled during sleep
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    saveChanges()
                }
            } catch {
                // Task was cancelled - no action needed
            }
        }
    }

    func saveChanges() {
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

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 20) {
            Spacer()

            // Share button (kept prominent)
            Button(action: shareNote) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }
            .accessibilityLabel("Share note")

            // More menu (consolidated actions)
            Menu {
                // AI actions (only show if API key configured)
                if settings.hasAPIKey {
                    Section {
                        Button(action: { showingEnhanceSheet = true }) {
                            Label("Enhance Text", systemImage: "wand.and.stars")
                        }
                        Button(action: { showingSummarySheet = true }) {
                            Label("Summarize", systemImage: "text.quote")
                        }
                    }
                }

                // Annotate (only show if note has original image)
                if note.originalImageData != nil {
                    Section {
                        Button(action: { showingAnnotationMode = true }) {
                            Label(
                                note.hasAnnotations ? "Edit Annotations" : "Annotate",
                                systemImage: note.hasAnnotations ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle"
                            )
                        }
                    }
                }

                Section {
                    // Change Type
                    Button(action: { showingTypePicker = true }) {
                        Label("Change Type", systemImage: "arrow.left.arrow.right.circle")
                    }

                    // Multi-page actions
                    Button(action: { showingAddPageSheet = true }) {
                        Label("Add Page", systemImage: "plus.rectangle.on.rectangle")
                    }
                    if note.pageCount > 0 {
                        Button(action: { showingPageNavigator = true }) {
                            Label(
                                "View Pages (\(note.pageCount))",
                                systemImage: note.pageCount > 1 ? "doc.on.doc.fill" : "doc.on.doc"
                            )
                        }
                    }
                }

                Section {
                    // Copy
                    Button(action: copyContent) {
                        Label("Copy Text", systemImage: "doc.on.clipboard")
                    }

                    // Export
                    Button(action: { showingExportSheet = true }) {
                        Label("Export", systemImage: "arrow.up.doc")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }
            .accessibilityLabel("More actions")
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

    // MARK: - Helpers

    private var noteTitle: String {
        let firstLine = editedContent.components(separatedBy: .newlines).first ?? "Note"
        return firstLine.truncated(to: 30)
    }

    private var wordCount: Int {
        editedContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
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

    // MARK: - Annotation Helpers

    private func loadAnnotation() {
        Task {
            do {
                if let drawing = try await AnnotationService.shared.loadAnnotation(for: note) {
                    await MainActor.run {
                        annotationDrawing = drawing
                    }
                }
            } catch {
                Self.logger.error("Failed to load annotation for note \(self.note.id): \(error.localizedDescription)")
            }
        }
    }

    private func saveAnnotation(_ drawing: PKDrawing) {
        Task {
            do {
                try await AnnotationService.shared.saveAnnotation(for: note, drawing: drawing)
                await MainActor.run {
                    annotationDrawing = drawing
                }
            } catch {
                Self.logger.error("Failed to save annotation for note \(self.note.id): \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    NoteDetailView(note: Note())
}
