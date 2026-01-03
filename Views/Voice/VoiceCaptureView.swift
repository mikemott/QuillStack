//
//  VoiceCaptureView.swift
//  QuillStack
//
//  Modern voice memo capture sheet with live transcription.
//

import SwiftUI

struct VoiceCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = VoiceMemoViewModel()
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusCard
                    transcriptionEditor
                    classificationSummary

                    if let warning = viewModel.permissionWarningMessage {
                        permissionBanner(text: warning)
                    }

                    if let error = viewModel.errorMessage {
                        permissionBanner(text: error)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .background(Color.creamLight.ignoresSafeArea())
            .navigationTitle("Voice Memo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.stopRecording()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await viewModel.saveTranscript() }
                    } label: {
                        if viewModel.saveState == .saving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .safeAreaInset(edge: .bottom) {
                controls
                    .background(Color.paperBeige.opacity(0.98))
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: -2)
            }
        }
        .task {
            await viewModel.requestPermissions()
        }
        .onDisappear {
            viewModel.stopRecording()
        }
        .onChange(of: viewModel.saveState) { _, newValue in
            if case .success = newValue {
                dismiss()
            }
        }
    }

    // MARK: - UI Components

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(viewModel.isRecording ? "Listening..." : "Ready to record")
                    .font(.serifHeadline(18, weight: .semibold))
            } icon: {
                Image(systemName: viewModel.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(viewModel.isRecording ? .red : .forestDark)
            }
            .foregroundColor(.forestDark)

            Text("QuillStack now keeps the entire memo, not just the last few words. Speak naturally and pause when finished.")
                .font(.serifBody(15))
                .foregroundColor(.textMedium)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.paperBeige)
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        )
    }

    private var transcriptionEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcription")
                    .font(.serifHeadline(17, weight: .semibold))
                    .foregroundColor(.forestDark)
                Spacer()
                if viewModel.isRecording {
                    Label("Recording", systemImage: "record.circle")
                        .font(.serifCaption(13, weight: .medium))
                        .foregroundColor(.red)
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.transcript)
                    .focused($isEditorFocused)
                    .padding(12)
                    .frame(minHeight: 200)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.forestDark.opacity(0.15), lineWidth: 1)
                    )

                if viewModel.transcript.isEmpty {
                    Text("Your transcription will appear here. You can also type to edit or add notes before saving.")
                        .font(.serifBody(15))
                        .foregroundColor(.textLight)
                        .padding(20)
                }
            }
        }
    }

    private var classificationSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected note type")
                .font(.serifHeadline(17, weight: .semibold))
                .foregroundColor(.forestDark)

            let types = viewModel.detectedSections.map(\.noteType)
            if types.isEmpty {
                typeBadge(for: .general)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(types.enumerated()), id: \.offset) { entry in
                            typeBadge(for: entry.element)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Text("Tip: Saying phrases like “create a reminder”, “add a shopping list”, or “schedule a meeting” automatically picks the right note type.")
                .font(.serifCaption(14))
                .foregroundColor(.textMedium)
        }
    }

    private func typeBadge(for type: NoteType) -> some View {
        HStack(spacing: 6) {
            Image(systemName: type.icon)
            Text(type.displayName)
                .font(.serifCaption(13, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(type.badgeColor)
        .cornerRadius(20)
    }

    private func permissionBanner(text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)
            Text(text)
                .font(.serifBody(14))
                .foregroundColor(.forestDark)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.15))
        )
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Button {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
            } label: {
                HStack {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                    Text(viewModel.isRecording ? "Stop Recording" : "Start Recording")
                        .font(.serifBody(17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: viewModel.isRecording ? [Color.red.opacity(0.9), Color.red] : [Color.forestMedium, Color.forestDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .disabled(!viewModel.canStartRecording)
            .opacity(viewModel.canStartRecording ? 1.0 : 0.6)

            HStack {
                Button(role: .destructive) {
                    viewModel.resetTranscript()
                } label: {
                    Text("Clear Transcript")
                        .font(.serifBody(15, weight: .medium))
                }
                .disabled(viewModel.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                if case .failure(let message) = viewModel.saveState {
                    Text(message)
                        .font(.serifCaption(13))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 30)
    }
}

#Preview {
    VoiceCaptureView()
}
