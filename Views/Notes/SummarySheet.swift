//
//  SummarySheet.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import SwiftUI
import CoreData

// MARK: - Summary Sheet

struct SummarySheet: View {
    @ObservedObject var note: Note
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLength: SummaryLength = .medium
    @State private var generatedSummary: String?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showCopiedToast = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamLight.ignoresSafeArea()

                VStack(spacing: 0) {
                    if isGenerating {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if let summary = generatedSummary ?? note.summary {
                        summaryResultView(summary)
                    } else {
                        summaryOptionsView
                    }
                }
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.forestDark)
                }
            }
            .overlay {
                if showCopiedToast {
                    copiedToast
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.3)

            Text("Generating summary...")
                .font(.serifBody(16, weight: .medium))
                .foregroundColor(.textMedium)

            Text("This may take a moment")
                .font(.serifCaption(13, weight: .regular))
                .foregroundColor(.textLight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Summary Failed")
                .font(.serifHeadline(18, weight: .semibold))
                .foregroundColor(.textDark)

            Text(error)
                .font(.serifBody(14, weight: .regular))
                .foregroundColor(.textMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: {
                errorMessage = nil
            }) {
                Text("Try Again")
                    .font(.serifBody(15, weight: .semibold))
                    .foregroundColor(.forestDark)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Summary Options View

    private var summaryOptionsView: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .font(.system(size: 36))
                    .foregroundColor(.forestDark)

                Text("AI Summary")
                    .font(.serifHeadline(22, weight: .semibold))
                    .foregroundColor(.textDark)

                Text("Generate a concise summary of your note")
                    .font(.serifBody(14, weight: .regular))
                    .foregroundColor(.textMedium)
            }
            .padding(.top, 24)

            // Length selector
            VStack(alignment: .leading, spacing: 12) {
                Text("Summary Length")
                    .font(.serifCaption(13, weight: .semibold))
                    .foregroundColor(.textMedium)

                HStack(spacing: 12) {
                    ForEach(SummaryLength.allCases) { length in
                        lengthOption(length)
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Generate button
            Button(action: generateSummary) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Generate Summary")
                        .font(.serifBody(16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.forestDark, Color.forestMedium],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .forestDark.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func lengthOption(_ length: SummaryLength) -> some View {
        Button(action: { selectedLength = length }) {
            VStack(spacing: 8) {
                Image(systemName: length.icon)
                    .font(.system(size: 20))
                    .foregroundColor(selectedLength == length ? .forestDark : .textMedium)

                Text(length.displayName)
                    .font(.serifBody(14, weight: selectedLength == length ? .semibold : .medium))
                    .foregroundColor(selectedLength == length ? .forestDark : .textDark)

                Text(length.description)
                    .font(.serifCaption(11, weight: .regular))
                    .foregroundColor(.textMedium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedLength == length ? Color.forestLight.opacity(0.2) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedLength == length ? Color.forestDark : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Summary Result View

    private func summaryResultView(_ summary: String) -> some View {
        VStack(spacing: 0) {
            // Summary content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Summary card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "text.quote")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.forestDark)
                            Text("Summary")
                                .font(.serifCaption(13, weight: .semibold))
                                .foregroundColor(.forestDark)
                            Spacer()

                            if let generatedAt = note.summaryGeneratedAt {
                                Text(formattedDate(generatedAt))
                                    .font(.serifCaption(11, weight: .regular))
                                    .foregroundColor(.textLight)
                            }
                        }

                        Text(summary)
                            .font(.serifBody(16, weight: .regular))
                            .foregroundColor(.textDark)
                            .lineSpacing(6)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                }
                .padding(20)
            }

            // Action buttons
            actionBar(summary: summary)
        }
    }

    private func actionBar(summary: String) -> some View {
        HStack(spacing: 16) {
            // Regenerate
            Button(action: {
                generatedSummary = nil
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                    Text("New")
                        .font(.serifCaption(13, weight: .medium))
                }
                .foregroundColor(.forestDark)
            }

            Spacer()

            // Copy
            Button(action: {
                UIPasteboard.general.string = summary
                showCopied()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .medium))
                    Text("Copy")
                        .font(.serifCaption(13, weight: .medium))
                }
                .foregroundColor(.textDark)
            }

            // Save to note
            if generatedSummary != nil && note.summary != generatedSummary {
                Button(action: saveSummary) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14, weight: .medium))
                        Text("Save")
                            .font(.serifCaption(13, weight: .medium))
                    }
                    .foregroundColor(.forestDark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.forestLight.opacity(0.2))
                    .cornerRadius(6)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.creamLight)
        .overlay(
            Rectangle()
                .fill(Color.forestDark.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Copied Toast

    private var copiedToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                Text("Copied to clipboard")
                    .font(.serifBody(14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.forestDark.opacity(0.9))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: showCopiedToast)
    }

    // MARK: - Actions

    private func generateSummary() {
        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let summary = try await LLMService.shared.summarizeNote(
                    note.content,
                    noteType: note.noteType,
                    length: selectedLength
                )
                await MainActor.run {
                    generatedSummary = summary
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }

    private func saveSummary() {
        guard let summary = generatedSummary else { return }
        note.summary = summary
        note.summaryGeneratedAt = Date()
        try? CoreDataStack.shared.saveViewContext()
        showCopied()
    }

    private func showCopied() {
        withAnimation {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    SummarySheet(note: Note())
}
