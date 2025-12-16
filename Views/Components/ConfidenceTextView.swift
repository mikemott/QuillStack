//
//  ConfidenceTextView.swift
//  QuillStack
//
//  Created on 2025-12-15.
//

import SwiftUI

// MARK: - Confidence Text View

/// Displays text with underlines for low-confidence words
/// Allows tapping on words to see alternatives and make corrections
struct ConfidenceTextView: View {
    @Binding var text: String
    let ocrResult: OCRResult?
    var onTextChanged: (() -> Void)?

    @State private var selectedWord: RecognizedWord?
    @State private var showingCorrection = false
    @State private var customCorrection = ""
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        if let ocrResult = ocrResult, settings.showLowConfidenceHighlights {
            // Rich view with confidence highlighting - uses corrected text with OCR confidence
            correctedTextWithHighlighting(ocrResult: ocrResult)
                .sheet(isPresented: $showingCorrection) {
                    if let word = selectedWord {
                        CorrectionSheet(
                            word: word,
                            customCorrection: $customCorrection,
                            onCorrect: { newText in
                                applyCorrection(original: word.text, replacement: newText)
                                showingCorrection = false
                                selectedWord = nil
                            },
                            onDismiss: {
                                showingCorrection = false
                                selectedWord = nil
                            }
                        )
                        .presentationDetents([.height(300)])
                    }
                }
        } else {
            // Simple text view fallback
            Text(text)
                .font(.serifBody(17, weight: .regular))
                .foregroundColor(.textDark)
                .lineSpacing(8)
        }
    }

    // MARK: - Corrected Text Display

    /// Shows the corrected text from the binding
    /// Spell corrections have already been applied, so we just display the text
    private func correctedTextWithHighlighting(ocrResult: OCRResult) -> some View {
        Text(text)
            .font(.serifBody(17, weight: .regular))
            .foregroundColor(.textDark)
            .lineSpacing(8)
    }

    // MARK: - Correction

    private func applyCorrection(original: String, replacement: String) {
        // Replace first occurrence of the word
        if let range = text.range(of: original) {
            text = text.replacingCharacters(in: range, with: replacement)
            onTextChanged?()
        }
    }
}

// MARK: - Correction Sheet

struct CorrectionSheet: View {
    let word: RecognizedWord
    @Binding var customCorrection: String
    var onCorrect: (String) -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Current word
                VStack(spacing: 8) {
                    Text("Current text")
                        .font(.serifCaption(12, weight: .medium))
                        .foregroundColor(.textMedium)

                    Text(word.text)
                        .font(.serifHeadline(24, weight: .semibold))
                        .foregroundColor(.textDark)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(confidenceColor)
                            .frame(width: 8, height: 8)
                        Text("\(Int(word.confidence * 100))% confidence")
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textMedium)
                    }
                }

                Divider()

                // Alternatives
                if !word.alternatives.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Suggestions")
                            .font(.serifCaption(12, weight: .medium))
                            .foregroundColor(.textMedium)

                        ForEach(word.alternatives, id: \.self) { alternative in
                            Button(action: { onCorrect(alternative) }) {
                                HStack {
                                    Text(alternative)
                                        .font(.serifBody(16, weight: .medium))
                                        .foregroundColor(.forestDark)
                                    Spacer()
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundColor(.forestDark.opacity(0.6))
                                }
                                .padding(12)
                                .background(Color.forestDark.opacity(0.08))
                                .cornerRadius(8)
                            }
                        }
                    }
                }

                // Custom input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or type correction")
                        .font(.serifCaption(12, weight: .medium))
                        .foregroundColor(.textMedium)

                    HStack(spacing: 12) {
                        TextField("Enter correction", text: $customCorrection)
                            .font(.serifBody(16, weight: .regular))
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.forestDark.opacity(0.2), lineWidth: 1)
                            )

                        Button(action: { onCorrect(customCorrection) }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.forestDark)
                                .cornerRadius(8)
                        }
                        .disabled(customCorrection.isEmpty)
                    }
                }

                Spacer()
            }
            .padding(20)
            .background(Color.creamLight)
            .navigationTitle("Correct Word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onDismiss)
                        .foregroundColor(.forestDark)
                }
            }
        }
    }

    private var confidenceColor: Color {
        if word.confidence < 0.5 {
            return .red
        } else if word.confidence < 0.7 {
            return .orange
        } else if word.confidence < 0.85 {
            return .yellow
        } else {
            return .green
        }
    }
}

// MARK: - Flow Layout

/// A custom layout that wraps content to the next line when needed
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, containerWidth: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, containerWidth: bounds.width).offsets

        for (offset, subview) in zip(offsets, subviews) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func layout(sizes: [CGSize], containerWidth: CGFloat) -> (offsets: [CGPoint], size: CGSize) {
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for size in sizes {
            if currentX + size.width > containerWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            offsets.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxWidth = max(maxWidth, currentX)
        }

        return (offsets, CGSize(width: maxWidth, height: currentY + lineHeight))
    }
}

#Preview {
    ConfidenceTextView(
        text: .constant("This is a test with some words"),
        ocrResult: nil
    )
}
