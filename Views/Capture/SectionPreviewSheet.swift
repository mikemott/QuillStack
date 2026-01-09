//
//  SectionPreviewSheet.swift
//  QuillStack
//
//  Created on 2026-01-09.
//

import SwiftUI

/// Sheet that previews detected sections and allows the user to choose
/// whether to split into multiple notes or keep as a single note
struct SectionPreviewSheet: View {
    let sections: [DetectedSection]
    let detectionMethod: SectionDetectionResult.DetectionMethod
    let onSplit: () -> Void
    let onKeepSingle: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.split.3x1")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.appAccent)
                        .padding(.top, 20)

                    Text("I found \(sections.count) sections")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Would you like to split this into \(sections.count) separate notes?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.bottom, 24)

                // Section previews
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                            SectionPreviewCard(
                                section: section,
                                index: index + 1
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100) // Space for buttons
                }

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                        onKeepSingle()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Action buttons
                VStack(spacing: 12) {
                    // Split button (primary action)
                    Button(action: {
                        dismiss()
                        onSplit()
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Split into \(sections.count) notes")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .accessibilityLabel("Split into \(sections.count) separate notes")

                    // Keep single button (secondary action)
                    Button(action: {
                        dismiss()
                        onKeepSingle()
                    }) {
                        Text("Keep as 1 note")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .accessibilityLabel("Keep as a single note")
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(
                    Color(.systemBackground)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
                )
            }
        }
    }
}

// MARK: - Section Preview Card

private struct SectionPreviewCard: View {
    let section: DetectedSection
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with index and type
            HStack {
                Text("Section \(index)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                // Note type badge
                HStack(spacing: 4) {
                    Image(systemName: section.suggestedType.iconName)
                        .font(.caption2)
                    Text(section.suggestedType.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(badgeColor.opacity(0.15))
                .foregroundColor(badgeColor)
                .cornerRadius(8)
            }

            // Content preview (truncated)
            Text(section.content)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)

            // Tags
            if !section.suggestedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(section.suggestedTags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Image(systemName: "number")
                                    .font(.caption2)
                                Text(tag)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .foregroundColor(.secondary)
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var badgeColor: Color {
        switch section.suggestedType {
        case .todo:
            return .badgeTodo
        case .meeting:
            return .badgeMeeting
        case .email:
            return .badgeEmail
        case .contact:
            return .badgeContact
        case .recipe:
            return .badgeRecipe
        case .journal:
            return .badgeJournal
        case .code:
            return .badgeCode
        case .project:
            return .badgeProject
        default:
            return .forestMedium
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleSections = [
        DetectedSection(
            content: """
            #todo#
            - Buy groceries
            - Pick up dry cleaning
            - Call dentist
            #shopping#
            """,
            suggestedType: .todo,
            suggestedTags: ["shopping"],
            confidence: 1.0,
            startIndex: "sample".startIndex,
            endIndex: "sample".endIndex
        ),
        DetectedSection(
            content: """
            #meeting#
            Team sync - Q4 Planning
            Discussed budget allocation
            Action items:
            - Sarah to review proposals
            - John to schedule follow-up
            #work# #q4#
            """,
            suggestedType: .meeting,
            suggestedTags: ["work", "q4"],
            confidence: 0.92,
            startIndex: "sample".startIndex,
            endIndex: "sample".endIndex
        )
    ]

    return SectionPreviewSheet(
        sections: sampleSections,
        detectionMethod: .explicitMarkers,
        onSplit: { print("Split") },
        onKeepSingle: { print("Keep single") }
    )
}
