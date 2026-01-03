//
//  VoiceCaptureView.swift
//  QuillStack
//
//  Created on 2026-01-02.
//

import SwiftUI

struct VoiceCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = VoiceViewModel()
    @State private var showPreview = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamLight
                    .ignoresSafeArea()

                if viewModel.isProcessing {
                    processingView
                } else if showPreview, viewModel.recordedAudioURL != nil {
                    AudioPreviewView(viewModel: viewModel) {
                        // On save
                        Task {
                            await viewModel.transcribeAndSave()
                            dismiss()
                        }
                    } onCancel: {
                        // Back to recording
                        showPreview = false
                        viewModel.stopAudio()
                    }
                } else {
                    recordingView
                }
            }
            .navigationTitle("Voice Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelRecording()
                        dismiss()
                    }
                }
            }
            .alert(
                "Error",
                isPresented: .init(
                    get: { viewModel.error != nil },
                    set: { if !$0 { viewModel.clearError() } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
        }
    }

    private var recordingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Waveform visualization
            WaveformView(levels: viewModel.audioLevels, isRecording: viewModel.isRecording)
                .frame(height: 120)
                .padding(.horizontal, 40)

            // Duration display
            Text(formatDuration(viewModel.recordingDuration))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(viewModel.isRecording ? Color.forestDark : .secondary)

            Spacer()

            // Record button
            VStack(spacing: 16) {
                Button {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                        showPreview = true
                    } else {
                        Task {
                            await viewModel.startRecording()
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(viewModel.isRecording ? Color.red : Color.forestDark)
                            .frame(width: 80, height: 80)

                        if viewModel.isRecording {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white)
                                .frame(width: 32, height: 32)
                        } else {
                            Circle()
                                .fill(.red)
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                .buttonStyle(.plain)

                Text(viewModel.isRecording ? "Tap to Stop" : "Tap to Record")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 60)
        }
    }

    private var processingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Transcribing...")
                .font(.headline)
                .foregroundStyle(Color.forestDark)

            Text("Converting your voice to text")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let levels: [CGFloat]
    let isRecording: Bool

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<50, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isRecording ? Color.forestDark.opacity(0.8) : Color.secondary.opacity(0.3))
                        .frame(width: (geometry.size.width / 50) - 2)
                        .frame(height: barHeight(for: index, maxHeight: geometry.size.height))
                }
            }
        }
    }

    private func barHeight(for index: Int, maxHeight: CGFloat) -> CGFloat {
        guard index < levels.count else {
            return 4 // Minimum height for empty bars
        }

        let level = levels[index]
        return max(4, level * maxHeight)
    }
}

#Preview {
    VoiceCaptureView()
}
