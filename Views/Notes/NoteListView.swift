//
//  NoteListView.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import SwiftUI

struct NoteListView: View {
    @StateObject private var viewModel = NoteViewModel()
    @State private var showingCamera = false
    @State private var selectedNote: Note?

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
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCamera) {
                CameraView()
            }
            .navigationDestination(item: $selectedNote) { note in
                destinationView(for: note)
            }
        }
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
                // Title
                Text("Notes")
                    .font(.serifTitle(34, weight: .bold))
                    .foregroundColor(.forestLight)

                Spacer()

                // Camera button
                Button(action: { showingCamera = true }) {
                    Image(systemName: "camera")
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
                .accessibilityLabel("Capture new note")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(height: 110)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.forestDark.opacity(0.15), Color.forestMedium.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.forestDark.opacity(0.25), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

                Image(systemName: "pencil.line")
                    .font(.system(size: 60, weight: .regular))
                    .foregroundColor(.forestDark)
            }

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
                NoteCardView(note: note)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .onTapGesture {
                        selectedNote = note
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation {
                                viewModel.deleteNote(note)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            withAnimation {
                                viewModel.archiveNote(note)
                            }
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .tint(.orange)
                    }
                    .contextMenu {
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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func archiveNote(_ note: Note) {
        viewModel.archiveNote(note)
    }

    @ViewBuilder
    private func destinationView(for note: Note) -> some View {
        switch note.noteType.lowercased() {
        case "todo":
            TodoDetailView(note: note)
        case "email":
            EmailDetailView(note: note)
        case "meeting":
            MeetingDetailView(note: note)
        default:
            NoteDetailView(note: note)
        }
    }
}

// MARK: - Note Card View

struct NoteCardView: View {
    let note: Note
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Badge + Date
            HStack {
                noteTypeBadge
                Spacer()
                dateText
            }

            // Preview text
            Text(note.content)
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

                // Left border (appears on press)
                Rectangle()
                    .fill(badgeColor)
                    .frame(width: isPressed ? 4 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isPressed)
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.forestDark.opacity(0.15), lineWidth: 1)
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
        switch note.noteType.lowercased() {
        case "todo": return "checkmark.square"
        case "meeting": return "calendar"
        case "email": return "envelope"
        default: return "doc.text"
        }
    }

    private var badgeColor: Color {
        switch note.noteType.lowercased() {
        case "todo": return .badgeTodo
        case "meeting": return .badgeMeeting
        case "email": return .badgeEmail
        default: return .badgeGeneral
        }
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
        switch note.noteType.lowercased() {
        case "todo":
            return "checkmark.square"
        case "meeting":
            return "person.2"
        case "email":
            return "paperplane"
        default:
            return "text.alignleft"
        }
    }

    private var footerText: String {
        switch note.noteType.lowercased() {
        case "todo":
            let count = note.todoItems?.count ?? 0
            return "\(count) task\(count == 1 ? "" : "s")"
        case "meeting":
            let count = note.meeting?.attendees?.components(separatedBy: ",").count ?? 0
            return "\(count) attendee\(count == 1 ? "" : "s")"
        case "email":
            return "Draft"
        default:
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
