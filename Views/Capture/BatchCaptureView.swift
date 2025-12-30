//
//  BatchCaptureView.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import SwiftUI
import AVFoundation
import CoreData

// MARK: - Batch Capture View

struct BatchCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var batchState = BatchCaptureState()
    @State private var cameraManager = CameraManager()

    @State private var showingPreview = false
    @State private var isProcessing = false
    @State private var processingMessage = "Processing pages..."

    var body: some View {
        ZStack {
            // Camera preview
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

            // Overlay UI
            VStack {
                // Top bar
                topBar

                Spacer()

                // Bottom controls
                bottomControls
            }

            // Processing overlay
            if isProcessing {
                processingOverlay
            }
        }
        .onChange(of: cameraManager.capturedImage) { _, newImage in
            if let image = newImage {
                batchState.addImage(image)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Cancel button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }

            Spacer()

            // Page counter
            if batchState.imageCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                    Text("\(batchState.imageCount) page\(batchState.imageCount == 1 ? "" : "s")")
                        .font(.serifBody(14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(20)
            }

            Spacer()

            // Placeholder for symmetry
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Thumbnail strip
            if batchState.imageCount > 0 {
                thumbnailStrip
            }

            // Capture buttons
            HStack(spacing: 40) {
                // Preview button (if has images)
                if batchState.imageCount > 0 {
                    Button(action: { showingPreview = true }) {
                        VStack(spacing: 4) {
                            Image(systemName: "eye")
                                .font(.system(size: 20))
                            Text("Preview")
                                .font(.serifCaption(11, weight: .medium))
                        }
                        .foregroundColor(.white)
                    }
                } else {
                    Color.clear.frame(width: 60)
                }

                // Capture button
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

                        if batchState.imageCount > 0 {
                            Text("+")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundColor(.forestDark)
                        }
                    }
                }
                .disabled(!cameraManager.isAuthorized || cameraManager.isCameraUnavailable)

                // Done button (if has images)
                if batchState.imageCount > 0 {
                    Button(action: processBatch) {
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .bold))
                            Text("Done")
                                .font(.serifCaption(11, weight: .medium))
                        }
                        .foregroundColor(.green)
                    }
                } else {
                    Color.clear.frame(width: 60)
                }
            }
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 16)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .sheet(isPresented: $showingPreview) {
            BatchPreviewSheet(batchState: batchState)
        }
    }

    // MARK: - Thumbnail Strip

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(batchState.capturedImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )

                        // Page number
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .offset(x: -4, y: 4)

                        // Remove button
                        Button(action: { batchState.removeImage(at: index) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                                .background(Color.white.clipShape(Circle()))
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 90)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
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

                Text(processingMessage)
                    .font(.serifBody(16, weight: .medium))
                    .foregroundColor(.white)

                Text("Processing \(batchState.imageCount) pages...")
                    .font(.serifCaption(13, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Actions

    private func processBatch() {
        guard !batchState.capturedImages.isEmpty else { return }

        isProcessing = true
        processingMessage = "Processing pages..."

        Task {
            do {
                let context = CoreDataStack.shared.persistentContainer.viewContext

                // Create note
                let note = Note(context: context)
                note.noteType = "general"

                // Process all pages
                _ = try await MultiPageService.shared.processPages(
                    images: batchState.capturedImages,
                    for: note,
                    context: context
                )

                // Save
                try context.save()

                await MainActor.run {
                    isProcessing = false
                    batchState.clear()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    batchState.error = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Batch Preview Sheet

struct BatchPreviewSheet: View {
    @ObservedObject var batchState: BatchCaptureState
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                TabView(selection: $currentPage) {
                    ForEach(Array(batchState.capturedImages.enumerated()), id: \.offset) { index, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
            .navigationTitle("Page \(currentPage + 1) of \(batchState.imageCount)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: { batchState.removeImage(at: currentPage) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(batchState.imageCount == 0)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.9), for: .navigationBar)
        }
    }
}

// MARK: - Preview

#Preview {
    BatchCaptureView()
}
