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

    // Optional status indicators
    var hasPendingEnhancement: Bool = false
    var customLabel: String? = nil

    // Optional classification info
    var classification: NoteClassification? = nil

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

                // Pending enhancement indicator
                if hasPendingEnhancement {
                    PendingEnhancementBadge()
                }

                // Classification confidence badge (if available and automatic)
                if let classification = classification,
                   classification.method.isAutomatic {
                    ClassificationBadge(classification: classification)
                }

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

                if let count = wordCount {
                    metadataSeparator
                    Text("\(count) words")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textLight.opacity(0.8))
                }

                if let completed = completedCount, let total = totalCount {
                    metadataSeparator
                    Text("\(completed)/\(total) complete")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textLight.opacity(0.8))
                }

                if let confidence = ocrConfidence, confidence > 0 {
                    metadataSeparator
                    Text("\(Int(confidence * 100))%")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textLight.opacity(0.8))
                }

                if let label = customLabel {
                    metadataSeparator
                    Text(label)
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textLight.opacity(0.8))
                }

                Spacer()

                // Progress bar for todos (fixed width, no GeometryReader)
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

    private var metadataSeparator: some View {
        Text("\u{2022}")
            .foregroundColor(.textLight.opacity(0.5))
    }

    private var noteTypeBadge: some View {
        HStack(spacing: 4) {
            if let icon = badgeIcon {
                Image(systemName: icon)
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

    /// Fixed-width progress bar without GeometryReader
    private func progressBar(completed: Int, total: Int) -> some View {
        let percent = min(1.0, CGFloat(completed) / CGFloat(total))
        let barWidth: CGFloat = 60

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.forestLight.opacity(0.3))
                .frame(width: barWidth, height: 4)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.forestLight)
                .frame(width: barWidth * percent, height: 4)
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        // Use appropriate format based on note type
        if noteType.lowercased() == "meeting" {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return "Captured today"
            } else if calendar.isDateInYesterday(date) {
                return "Captured yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return "Captured \(formatter.string(from: date))"
            }
        }
        return date.formattedForNotes()
    }

    private var displayType: String {
        switch noteType.lowercased() {
        case "todo": return "TO-DO"
        case "claudeprompt": return "ISSUE"
        default: return noteType
        }
    }

    private var badgeIcon: String? {
        switch noteType.lowercased() {
        case "todo": return "checkmark.square"
        case "meeting": return "calendar"
        case "email": return "envelope"
        case "claudeprompt": return "chevron.left.forwardslash.chevron.right"
        case "reminder": return "bell"
        case "contact": return "person.crop.circle"
        default: return nil
        }
    }

    private var badgeColor: Color {
        switch noteType.lowercased() {
        case "todo": return .badgeTodo
        case "meeting": return .badgeMeeting
        case "email": return .badgeEmail
        case "claudeprompt": return .forestDark
        case "reminder": return .badgeReminder
        case "contact": return .badgeContact
        default: return .badgeGeneral
        }
    }
}

// MARK: - Pending Enhancement Badge

/// Small badge shown when a note has pending LLM enhancement
struct PendingEnhancementBadge: View {
    var body: some View {
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
