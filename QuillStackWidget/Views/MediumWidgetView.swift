//
//  MediumWidgetView.swift
//  QuillStackWidget
//
//  Created on 2026-01-02.
//

import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: NotesEntry

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "F5F1E8"), Color(hex: "E8DCC8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 0) {
                // Left side: Capture buttons
                VStack(spacing: 10) {
                    // Voice button
                    Link(destination: URL(string: "quillstack://capture/voice")!) {
                        VStack(spacing: 4) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "2D5F4F"), Color(hex: "1E4335")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text("Voice")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(hex: "1E4335"))
                        }
                    }

                    // Scan button
                    Link(destination: URL(string: "quillstack://capture/camera")!) {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "2D5F4F"), Color(hex: "1E4335")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text("Scan")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(hex: "1E4335"))
                        }
                    }

                    // Note count
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 10))
                        Text("\(entry.todayStats.totalNotes) today")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "1E4335").opacity(0.7))
                }
                .frame(width: 90)
                .padding(.leading, 12)

                // Divider
                Rectangle()
                    .fill(Color(hex: "1E4335").opacity(0.1))
                    .frame(width: 1)
                    .padding(.vertical, 12)

                // Right side: Recent notes
                VStack(alignment: .leading, spacing: 0) {
                    Text("Recent Notes")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "1E4335").opacity(0.6))
                        .padding(.bottom, 8)

                    if entry.recentNotes.isEmpty {
                        Text("No notes yet")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "1E4335").opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(entry.recentNotes.prefix(3)) { note in
                                Link(destination: URL(string: "quillstack://note/\(note.id.uuidString)")!) {
                                    HStack(spacing: 6) {
                                        // Type badge
                                        Circle()
                                            .fill(note.badgeColor)
                                            .frame(width: 6, height: 6)

                                        // Note preview
                                        Text(note.displayContent)
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundColor(Color(hex: "1E4335"))
                                            .lineLimit(1)

                                        Spacer(minLength: 0)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
        }
    }
}
