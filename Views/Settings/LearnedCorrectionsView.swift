//
//  LearnedCorrectionsView.swift
//  QuillStack
//
//  Shows all learned OCR corrections with frequency counts.
//

import SwiftUI

struct LearnedCorrectionsView: View {
    @State private var corrections: [(original: String, corrected: String, frequency: Int)] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            } else if corrections.isEmpty {
                emptyState
            } else {
                correctionsList
            }
        }
        .navigationTitle("Learned Corrections")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCorrections()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundColor(.forestDark.opacity(0.3))

            Text("No Corrections Yet")
                .font(.serifHeadline(20, weight: .semibold))
                .foregroundColor(.textDark)

            Text("As you edit OCR text, the app will learn your corrections and apply them automatically to future notes.")
                .font(.serifBody(14, weight: .regular))
                .foregroundColor(.textMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Corrections List

    private var correctionsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(corrections.enumerated()), id: \.offset) { index, correction in
                    correctionRow(correction: correction)
                }
            }
            .padding(20)
        }
    }

    private func correctionRow(correction: (original: String, corrected: String, frequency: Int)) -> some View {
        HStack(spacing: 16) {
            // Original word
            Text(correction.original)
                .font(.serifBody(16, weight: .regular))
                .foregroundColor(.textMedium)
                .strikethrough(true, color: .red.opacity(0.6))
                .frame(minWidth: 80, alignment: .leading)

            // Arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.forestDark.opacity(0.5))

            // Corrected word
            Text(correction.corrected)
                .font(.serifBody(16, weight: .semibold))
                .foregroundColor(.textDark)
                .frame(minWidth: 80, alignment: .leading)

            Spacer()

            // Frequency badge
            if correction.frequency > 1 {
                HStack(spacing: 4) {
                    Image(systemName: "repeat")
                        .font(.system(size: 10))
                    Text("\(correction.frequency)×")
                        .font(.serifCaption(12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.forestDark.opacity(0.8))
                .cornerRadius(6)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
    }

    // MARK: - Data Loading

    private func loadCorrections() {
        isLoading = true

        Task {
            // Simulate async load (HandwritingLearningService is @MainActor)
            let loaded = HandwritingLearningService.shared.recentCorrections(limit: 100)

            await MainActor.run {
                corrections = loaded
                isLoading = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        LearnedCorrectionsView()
    }
}
