//
//  LargeWidgetView.swift
//  QuillStackWidget
//
//  Created on 2026-01-02.
//

import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: NotesEntry

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "F5F1E8"), Color(hex: "E8DCC8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("QuillStack")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "1E4335"))

                    Spacer()

                    // Capture buttons
                    HStack(spacing: 8) {
                        Link(destination: URL(string: "quillstack://capture/voice")!) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "2D5F4F"), Color(hex: "1E4335")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Link(destination: URL(string: "quillstack://capture/camera")!) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "2D5F4F"), Color(hex: "1E4335")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Divider
                Rectangle()
                    .fill(Color(hex: "1E4335").opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                // Recent notes section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recent Notes")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "1E4335").opacity(0.6))

                        Spacer()

                        // Filter indicator (static for now)
                        Text("All")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "1E4335").opacity(0.5))
                    }
                    .padding(.bottom, 4)

                    if entry.recentNotes.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "1E4335").opacity(0.2))
                            Text("No notes yet")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "1E4335").opacity(0.4))
                            Text("Tap to capture your first note")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "1E4335").opacity(0.3))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(entry.recentNotes.prefix(6)) { note in
                                Link(destination: URL(string: "quillstack://note/\(note.id.uuidString)")!) {
                                    HStack(spacing: 8) {
                                        // Type badge
                                        Circle()
                                            .fill(note.badgeColor)
                                            .frame(width: 8, height: 8)

                                        // Note preview
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(note.displayContent)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(Color(hex: "1E4335"))
                                                .lineLimit(1)

                                            Text(note.relativeTime)
                                                .font(.system(size: 10, weight: .regular))
                                                .foregroundColor(Color(hex: "1E4335").opacity(0.5))
                                        }

                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Divider
                Rectangle()
                    .fill(Color(hex: "1E4335").opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                // Stats footer
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 11))
                        Text("\(entry.todayStats.totalNotes) notes")
                            .font(.system(size: 11, weight: .medium))
                    }

                    if entry.todayStats.todoCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                            Text("\(entry.todayStats.todoCount) todos")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }

                    if entry.todayStats.meetingCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 11))
                            Text("\(entry.todayStats.meetingCount) meetings")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }

                    Spacer()

                    Text("Today")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(Color(hex: "1E4335").opacity(0.4))
                }
                .foregroundColor(Color(hex: "1E4335").opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
}
