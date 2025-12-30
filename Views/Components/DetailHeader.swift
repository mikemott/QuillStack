//
//  DetailHeader.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI

// MARK: - Detail Header

/// Reusable header component for note detail views
/// Provides consistent styling across NoteDetailView, TodoDetailView, MeetingDetailView, etc.
struct DetailHeader: View {
    let title: String
    let date: Date
    let noteType: String
    let onBack: () -> Void

    // Optional metadata
    var wordCount: Int?
    var ocrConfidence: Float?
    var completedCount: Int?
    var totalCount: Int?

    var body: some View {
        VStack(spacing: 0) {
            // Top row: back, title, badge
            HStack(alignment: .center, spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.forestLight)
                }
                .accessibilityLabel("Back to notes")

                Text(title)
                    .font(.serifBody(17, weight: .semibold))
                    .foregroundColor(.forestLight)
                    .lineLimit(1)

                Spacer()

                noteTypeBadge
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // Metadata row
            HStack(spacing: 12) {
                Text(date.formattedForNotes())
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textLight.opacity(0.8))

                if let count = wordCount {
                    Text("•")
                        .foregroundColor(.textLight.opacity(0.5))
                    Text("\(count) words")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textLight.opacity(0.8))
                }

                if let completed = completedCount, let total = totalCount {
                    Text("•")
                        .foregroundColor(.textLight.opacity(0.5))
                    Text("\(completed)/\(total) complete")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textLight.opacity(0.8))
                }

                if let confidence = ocrConfidence, confidence > 0 {
                    Text("•")
                        .foregroundColor(.textLight.opacity(0.5))
                    Text("\(Int(confidence * 100))%")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textLight.opacity(0.8))
                }

                Spacer()

                // Progress bar for todos
                if let completed = completedCount, let total = totalCount, total > 0 {
                    progressBar(completed: completed, total: total)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(headerBackground)
    }

    // MARK: - Subviews

    private var noteTypeBadge: some View {
        HStack(spacing: 4) {
            if noteType.lowercased() == "todo" {
                Image(systemName: "checkmark.square")
                    .font(.system(size: 10, weight: .bold))
            }
            Text(displayType.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
        }
        .foregroundColor(.white)
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

    private var headerBackground: some View {
        LinearGradient(
            colors: [Color.forestMedium, Color.forestDark],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(edges: .top)
    }

    private func progressBar(completed: Int, total: Int) -> some View {
        let percent = CGFloat(completed) / CGFloat(total)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.forestLight.opacity(0.3))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.forestLight)
                    .frame(width: geo.size.width * percent, height: 4)
            }
        }
        .frame(width: 60, height: 4)
    }

    // MARK: - Helpers

    private var displayType: String {
        switch noteType.lowercased() {
        case "todo": return "TO-DO"
        default: return noteType
        }
    }

    private var badgeColor: Color {
        switch noteType.lowercased() {
        case "todo": return .badgeTodo
        case "meeting": return .badgeMeeting
        case "email": return .badgeEmail
        default: return .badgeGeneral
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        DetailHeader(
            title: "Weekly Team Standup Notes",
            date: Date(),
            noteType: "meeting",
            onBack: {}
        )

        Spacer()
    }
    .background(Color.creamLight)
}
