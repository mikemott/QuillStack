//
//  ClassificationBadge.swift
//  QuillStack
//
//  Phase 1.4: Confidence Badge UI
//  Shows classification confidence and method for note types.
//

import SwiftUI

/// Badge showing note type classification confidence
/// Displays different styles based on confidence level:
/// - High (>90%): Solid badge
/// - Medium (70-90%): Outlined badge
/// - Low (<70%): Outlined badge with warning icon
struct ClassificationBadge: View {
    let classification: NoteClassification

    var body: some View {
        HStack(spacing: 4) {
            // Warning icon for low confidence
            if classification.isLowConfidence && classification.method.isAutomatic {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(foregroundColor)
            }

            // Confidence percentage (only show for automatic methods, not explicit/manual)
            if classification.method.isAutomatic {
                Text(classification.confidencePercentage)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(foregroundColor)
            }

            // Method label for debugging/transparency
            if shouldShowMethod {
                Text(classification.method.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(foregroundColor.opacity(0.8))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(borderColor, lineWidth: shouldUseBorder ? 1 : 0)
        )
        .cornerRadius(4)
    }

    // MARK: - Style Helpers

    /// Whether to show the classification method (for transparency)
    private var shouldShowMethod: Bool {
        // Show method for LLM or heuristic classifications
        classification.method == .llm || classification.method == .heuristic
    }

    /// Use outlined style for medium/low confidence
    private var shouldUseBorder: Bool {
        !classification.isHighConfidence && classification.method.isAutomatic
    }

    private var foregroundColor: Color {
        if classification.isHighConfidence {
            return .white
        } else if classification.isLowConfidence {
            return .orange
        } else {
            return .forestMedium
        }
    }

    private var backgroundColor: Color {
        if classification.isHighConfidence {
            return .forestMedium.opacity(0.9)
        } else if classification.isLowConfidence {
            return .orange.opacity(0.15)
        } else {
            return .forestMedium.opacity(0.1)
        }
    }

    private var borderColor: Color {
        if classification.isLowConfidence {
            return .orange.opacity(0.5)
        } else {
            return .forestMedium.opacity(0.4)
        }
    }
}

// MARK: - Preview

#Preview("High Confidence - LLM") {
    VStack(spacing: 12) {
        ClassificationBadge(
            classification: .llm(.contact, confidence: 0.92, reasoning: "Detected business card")
        )

        ClassificationBadge(
            classification: .llm(.todo, confidence: 0.88)
        )
    }
    .padding()
    .background(Color.creamLight)
}

#Preview("Medium Confidence - Heuristic") {
    VStack(spacing: 12) {
        ClassificationBadge(
            classification: .heuristic(.contact, confidence: 0.75)
        )

        ClassificationBadge(
            classification: .heuristic(.meeting, confidence: 0.80)
        )
    }
    .padding()
    .background(Color.creamLight)
}

#Preview("Low Confidence") {
    VStack(spacing: 12) {
        ClassificationBadge(
            classification: .heuristic(.event, confidence: 0.65)
        )

        ClassificationBadge(
            classification: NoteClassification(
                type: .general,
                confidence: 0.55,
                method: .contentAnalysis
            )
        )
    }
    .padding()
    .background(Color.creamLight)
}

#Preview("Explicit/Manual - No Percentage") {
    VStack(spacing: 12) {
        ClassificationBadge(
            classification: .explicit(.todo)
        )

        ClassificationBadge(
            classification: .manual(.meeting)
        )
    }
    .padding()
    .background(Color.creamLight)
}
