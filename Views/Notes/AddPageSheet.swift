//
//  AddPageSheet.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import SwiftUI
import CoreData

// MARK: - Add Page Sheet

struct AddPageSheet: View {
    @ObservedObject var note: Note
    @Environment(\.dismiss) private var dismiss
    @State private var cameraManager = CameraManager()

    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            if let image = capturedImage {
                // Preview captured image
                previewView(image: image)
            } else {
                // Camera view
                cameraView
            }

            // Processing overlay
            if isProcessing {
                processingOverlay
            }

            // Success overlay
            if showSuccess {
                successOverlay
            }
        }
        .onChange(of: cameraManager.capturedImage) { _, newImage in
            if let image = newImage {
                capturedImage = image
            }
        }
    }

    // MARK: - Camera View

    private var cameraView: some View {
        ZStack {
            if cameraManager.isAuthorized && !cameraManager.isCameraUnavailable {
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Camera access required")
                        .font(.serifBody(16, weight: .medium))
                        .foregroundColor(.gray)
                }
            }

            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Page count indicator
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                        Text("Adding page \(note.pageCount + 1)")
                            .font(.serifCaption(12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(16)

                    Spacer()

                    // Placeholder for symmetry
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Capture button
                VStack(spacing: 20) {
                    Text("Position the next page")
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    Button(action: {
                        cameraManager.capturePhoto()
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 70, height: 70)

                            Circle()
                                .fill(Color.white)
                                .frame(width: 58, height: 58)
                        }
                    }
                    .disabled(!cameraManager.isAuthorized || cameraManager.isCameraUnavailable)
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Preview View

    private func previewView(image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()

            VStack {
                HStack {
                    // Retake button
                    Button(action: { capturedImage = nil }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Retake")
                        }
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                    }

                    Spacer()

                    // Cancel button
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.serifBody(14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                    }
                }
                .padding()

                Spacer()

                // Add page button
                Button(action: { addPage(image: image) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                        Text("Add Page")
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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Processing page...")
                    .font(.serifBody(16, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)

                Text("Page Added!")
                    .font(.serifHeadline(20, weight: .semibold))
                    .foregroundColor(.white)

                Text("Page \(note.pageCount) added successfully")
                    .font(.serifBody(14, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .onAppear {
            // Auto-dismiss after 1.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }

    // MARK: - Actions

    private func addPage(image: UIImage) {
        isProcessing = true

        Task {
            do {
                let context = CoreDataStack.shared.persistentContainer.viewContext

                _ = try await MultiPageService.shared.addPage(
                    image: image,
                    to: note,
                    context: context
                )

                try context.save()

                await MainActor.run {
                    isProcessing = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AddPageSheet(note: Note())
}
