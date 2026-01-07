//
//  NoteListView.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import SwiftUI

struct NoteListView: View {
    @State private var viewModel = NoteViewModel()
    @State private var showingCamera = false
    @State private var showingVoice = false
    @State private var showingSearch = false
    @State private var selectedNote: Note?

    // Multi-select state
    @State private var isEditing = false
    @State private var selectedNotes: Set<Note> = []
    @State private var showingBulkExport = false
    @State private var showingDeleteConfirmation = false

    // Deep link bindings (optional, for widget support)
    @Binding var showingCameraFromDeepLink: Bool
    @Binding var showingVoiceFromDeepLink: Bool
    @Binding var deepLinkNoteId: UUID?

    init(
        showingCameraFromDeepLink: Binding<Bool> = .constant(false),
        showingVoiceFromDeepLink: Binding<Bool> = .constant(false),
        deepLinkNoteId: Binding<UUID?> = .constant(nil)
    ) {
        self._showingCameraFromDeepLink = showingCameraFromDeepLink
        self._showingVoiceFromDeepLink = showingVoiceFromDeepLink
        self._deepLinkNoteId = deepLinkNoteId
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background with subtle gradient
                Color.creamLight.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom Navigation Bar
                    customNavigationBar

                    // Content
                    if viewModel.notes.isEmpty {
                        emptyStateView
                    } else {
                        noteGridContent
                    }

                    // Bulk action toolbar (shown during edit mode with selections)
                    if isEditing {
                        bulkActionToolbar
                    }
                }

                // Floating Action Button (FAB) for camera
                if !isEditing {
                    cameraFAB
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCamera) {
                CameraView()
            }
            .sheet(isPresented: $showingVoice) {
                VoiceCaptureView()
            }
            .fullScreenCover(isPresented: $showingSearch) {
                NoteSearchView()
            }
            .sheet(isPresented: $showingBulkExport) {
                BulkExportSheet(notes: Array(selectedNotes)) {
                    exitEditMode()
                }
            }
            .navigationDestination(item: $selectedNote) { note in
                destinationView(for: note)
            }
            .onChange(of: showingCameraFromDeepLink) { _, newValue in
                if newValue {
                    showingCamera = true
                    showingCameraFromDeepLink = false
                }
            }
            .onChange(of: showingVoiceFromDeepLink) { _, newValue in
                if newValue {
                    showingVoice = true
                    showingVoiceFromDeepLink = false
                }
            }
            .onChange(of: deepLinkNoteId) { _, newValue in
                if let noteId = newValue,
                   let note = viewModel.notes.first(where: { $0.id == noteId }) {
                    selectedNote = note
                    deepLinkNoteId = nil
                }
            }
            .confirmationDialog(
                "Delete \(selectedNotes.count) note\(selectedNotes.count == 1 ? "" : "s")?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    withAnimation {
                        viewModel.deleteNotes(selectedNotes)
                        exitEditMode()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    private func exitEditMode() {
        isEditing = false
        selectedNotes.removeAll()
    }

    // MARK: - Custom Navigation Bar

    private var customNavigationBar: some View {
        ZStack(alignment: .bottom) {
            // Dark green gradient background
            LinearGradient(
                colors: [Color.forestMedium, Color.forestDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)

            HStack(alignment: .bottom) {
                // Edit/Done button (left side in edit mode)
                if isEditing {
                    Button("Done") {
                        withAnimation {
                            exitEditMode()
                        }
                    }
                    .font(.serifBody(17, weight: .semibold))
                    .foregroundColor(.forestLight)
                }

                // Logo + Title
                if isEditing {
                    Text("\(selectedNotes.count) Selected")
                        .font(.serifTitle(24, weight: .bold))
                        .foregroundColor(.forestLight)
                } else {
                    HStack(spacing: 12) {
                        // Logo
                        Image("Logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                        // App name
                        Text("QuillStack")
                            .font(.serifTitle(28, weight: .bold))
                            .foregroundColor(.forestLight)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    if isEditing {
                        // Select All button
                        Button(action: {
                            if selectedNotes.count == viewModel.notes.count {
                                selectedNotes.removeAll()
                            } else {
                                selectedNotes = Set(viewModel.notes)
                            }
                        }) {
                            Text(selectedNotes.count == viewModel.notes.count ? "Deselect All" : "Select All")
                                .font(.serifBody(15, weight: .medium))
                                .foregroundColor(.forestLight)
                        }
                    } else {
                        // Edit button
                        if !viewModel.notes.isEmpty {
                            Button(action: {
                                withAnimation {
                                    isEditing = true
                                }
                            }) {
                                Text("Edit")
                                    .font(.serifBody(17, weight: .medium))
                                    .foregroundColor(.forestLight)
                            }
                        }

                        // Search button
                        Button(action: { showingSearch = true }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.forestLight)
                                .frame(width: 44, height: 44)
                                .background(
                                    LinearGradient(
                                        colors: [Color.forestDark.opacity(0.9), Color.forestMedium.opacity(0.95)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .accessibilityLabel("Search notes")

                        // Voice button
                        Button(action: { showingVoice = true }) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.forestLight)
                                .frame(width: 44, height: 44)
                                .background(
                                    LinearGradient(
                                        colors: [Color.forestDark.opacity(0.9), Color.forestMedium.opacity(0.95)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .accessibilityLabel("Record voice note")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(height: 110)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Logo
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)

            // Text
            VStack(spacing: 12) {
                Text("No notes yet")
                    .font(.serifHeadline(26, weight: .bold))
                    .foregroundColor(.forestDark)

                Text("Capture your first handwritten note with your camera.\nWe'll convert it to text instantly.")
                    .font(.serifBody(16, weight: .regular))
                    .foregroundColor(.textMedium)
                    .multilineTextAlignment(.center)
                    .italic()
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }

            // Button
            Button(action: { showingCamera = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "camera")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Capture Note")
                        .font(.serifBody(17, weight: .semibold))
                }
                .foregroundColor(.forestLight)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.forestDark.opacity(0.95), Color.forestMedium.opacity(0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Note Grid

    private var noteGridContent: some View {
        List {
            ForEach(viewModel.notes, id: \.objectID) { note in
                HStack(spacing: 12) {
                    // Selection indicator (shown in edit mode)
                    if isEditing {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if selectedNotes.contains(note) {
                                    selectedNotes.remove(note)
                                } else {
                                    selectedNotes.insert(note)
                                }
                            }
                        }) {
                            Image(systemName: selectedNotes.contains(note) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24))
                                .foregroundColor(selectedNotes.contains(note) ? .forestDark : .textLight)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }

                    NoteCardView(note: note, isSelected: isEditing && selectedNotes.contains(note))
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isEditing {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if selectedNotes.contains(note) {
                                selectedNotes.remove(note)
                            } else {
                                selectedNotes.insert(note)
                            }
                        }
                    } else {
                        selectedNote = note
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: !isEditing) {
                    if !isEditing {
                        Button(role: .destructive) {
                            withAnimation {
                                viewModel.deleteNote(note)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: !isEditing) {
                    if !isEditing {
                        Button {
                            withAnimation {
                                viewModel.archiveNote(note)
                            }
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .tint(.orange)
                    }
                }
                .contextMenu {
                    if !isEditing {
                        Button(role: .destructive) {
                            viewModel.deleteNote(note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            viewModel.archiveNote(note)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }

    // MARK: - Bulk Action Toolbar

    private var bulkActionToolbar: some View {
        HStack(spacing: 0) {
            // Export button
            Button(action: {
                if !selectedNotes.isEmpty {
                    showingBulkExport = true
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                    Text("Export")
                        .font(.serifCaption(11, weight: .medium))
                }
                .foregroundColor(selectedNotes.isEmpty ? .textLight : .forestDark)
                .frame(maxWidth: .infinity)
            }
            .disabled(selectedNotes.isEmpty)

            // Archive button
            Button(action: {
                if !selectedNotes.isEmpty {
                    withAnimation {
                        viewModel.archiveNotes(selectedNotes)
                        exitEditMode()
                    }
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 20))
                    Text("Archive")
                        .font(.serifCaption(11, weight: .medium))
                }
                .foregroundColor(selectedNotes.isEmpty ? .textLight : .orange)
                .frame(maxWidth: .infinity)
            }
            .disabled(selectedNotes.isEmpty)

            // Delete button
            Button(action: {
                if !selectedNotes.isEmpty {
                    showingDeleteConfirmation = true
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                    Text("Delete")
                        .font(.serifCaption(11, weight: .medium))
                }
                .foregroundColor(selectedNotes.isEmpty ? .textLight : .red)
                .frame(maxWidth: .infinity)
            }
            .disabled(selectedNotes.isEmpty)
        }
        .padding(.vertical, 12)
        .background(
            Color.paperBeige
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Floating Action Button

    private var cameraFAB: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: { showingCamera = true }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: [Color.forestMedium, Color.forestDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: .forestDark.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .accessibilityLabel("Capture new note")
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private func archiveNote(_ note: Note) {
        viewModel.archiveNote(note)
    }

    /// Routes to the appropriate detail view using the factory pattern.
    private func destinationView(for note: Note) -> some View {
        DetailViewFactory.makeView(for: note)
    }
}

// MARK: - Note Card View

struct NoteCardView: View {
    let note: Note
    var isSelected: Bool = false
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Badge + Annotation Indicator + Date
            HStack {
                noteTypeBadge

                // Annotation indicator
                if note.hasAnnotations {
                    Image(systemName: "pencil.tip.crop.circle.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.forestDark)
                        .accessibilityLabel("Has annotations")
                }

                Spacer()
                dateText
            }

            // Preview text (cleaned of OCR artifacts - QUI-146)
            Text(note.cleanContent)
                .font(.serifBody(15, weight: .regular))
                .foregroundColor(.textDark)
                .lineSpacing(6)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            // Footer: Word count + Confidence bar
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: footerIcon)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.textMedium)
                    Text(footerText)
                        .font(.serifCaption(13, weight: .regular))
                        .foregroundColor(.textMedium)
                }

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
                                    colors: [Color.forestDark.opacity(0.8), Color.forestMedium.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(note.ocrConfidence), height: 3)
                            .cornerRadius(2)
                    }
                }
                .frame(height: 3)

                Text("\(Int(note.ocrConfidence * 100))%")
                    .font(.serifCaption(13, weight: .regular))
                    .foregroundColor(.textMedium)
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

                // Left border (appears on press or selection)
                Rectangle()
                    .fill(badgeColor)
                    .frame(width: (isPressed || isSelected) ? 4 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isPressed)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.forestDark : Color.forestDark.opacity(0.15), lineWidth: isSelected ? 2 : 1)
                .animation(.easeInOut(duration: 0.15), value: isSelected)
        )
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    // MARK: - Badge

    private var noteTypeBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: badgeIcon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)

            Text(note.noteType.uppercased())
                .font(.system(size: 11, weight: .bold, design: .default))
                .foregroundColor(.white)
                .tracking(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [badgeColor, badgeColor.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(6)
        .shadow(color: badgeColor.opacity(0.3), radius: 2, x: 0, y: 1)
    }

    private var badgeIcon: String {
        note.type.icon
    }

    private var badgeColor: Color {
        note.type.badgeColor
    }

    // MARK: - Date

    private var dateText: some View {
        Text(formattedDate)
            .font(.serifCaption(13, weight: .medium))
            .foregroundColor(.textMedium)
            .italic()
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

    // MARK: - Footer

    private var footerIcon: String {
        note.type.footerIcon
    }

    private var footerText: String {
        switch note.type {
        case .todo:
            let count = note.todoItems?.count ?? 0
            return "\(count) task\(count == 1 ? "" : "s")"
        case .meeting:
            let count = note.meeting?.attendees?.components(separatedBy: ",").count ?? 0
            return "\(count) attendee\(count == 1 ? "" : "s")"
        case .email:
            return "Draft"
        case .claudePrompt:
            return note.summary != nil ? "Issue created" : "Ready to export"
        case .reminder:
            return "Reminder"
        case .contact:
            return "Contact"
        case .expense:
            return "Expense"
        case .shopping:
            return "Shopping list"
        case .recipe:
            return "Recipe"
        case .event:
            return "Event"
        case .journal:
            return "Journal"
        case .idea:
            return "Idea"
        case .general:
            let wordCount = note.content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            return "\(wordCount) words"
        }
    }
}

#Preview {
    NavigationStack {
        NoteListView()
    }
}
