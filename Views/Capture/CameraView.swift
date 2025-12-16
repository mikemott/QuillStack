//
//  CameraView.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @State private var viewModel = CameraViewModel()
    @State private var cameraManager = CameraManager()
    @Environment(\.dismiss) private var dismiss

    @State private var showingImagePreview = false

    var body: some View {
        ZStack {
            // Dark background
            Color(red: 20/255, green: 12/255, blue: 8/255)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Camera header
                cameraHeader
                    .padding(.top, 50)
                    .padding(.horizontal, 20)

                Spacer()

                // Camera preview or live feed
                if cameraManager.isAuthorized && !cameraManager.isCameraUnavailable {
                    // Live camera preview
                    cameraPreviewArea
                } else {
                    // Camera unavailable
                    cameraUnavailableView
                }

                Spacer()

                // Camera controls
                if cameraManager.isAuthorized && !cameraManager.isCameraUnavailable {
                    cameraControls
                        .padding(.bottom, 40)
                }
            }

            // Processing indicator
            if viewModel.isProcessing {
                processingOverlay
            }

            // Error display
            if let error = viewModel.error {
                ErrorBanner(message: error.localizedDescription)
                    .transition(.move(edge: .top))
            }
        }
        .sheet(isPresented: $showingImagePreview) {
            if let image = cameraManager.capturedImage {
                ImagePreviewView(
                    image: image,
                    onConfirm: {
                        showingImagePreview = false
                        Task {
                            await viewModel.processImage(image)
                            dismiss()
                        }
                    },
                    onRetake: {
                        showingImagePreview = false
                        cameraManager.capturedImage = nil
                    }
                )
            }
        }
        .onChange(of: cameraManager.capturedImage) { _, newImage in
            if newImage != nil {
                showingImagePreview = true
            }
        }
        .onAppear {
            if cameraManager.isAuthorized && !cameraManager.isCameraUnavailable {
                cameraManager.startSession()
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }

    // MARK: - Camera Header

    private var cameraHeader: some View {
        HStack {
            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.forestLight)
                    .frame(width: 40, height: 40)
                    .background(Color.forestDark.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.forestMedium.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(10)
            }
            .accessibilityLabel("Close camera")

            Spacer()

            // Title
            Text("Capture Note")
                .font(.serifBody(17, weight: .semibold))
                .foregroundColor(.forestLight)

            Spacer()

            // Placeholder for symmetry
            Color.clear
                .frame(width: 40, height: 40)
        }
    }

    // MARK: - Camera Preview Area

    private var cameraPreviewArea: some View {
        ZStack {
            // Live camera preview
            CameraPreviewView(cameraManager: cameraManager)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.forestDark.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

            // Guide overlay
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.forestDark.opacity(0.4), lineWidth: 2)
                .frame(width: 200, height: 200)
                .shadow(color: .forestDark.opacity(0.2), radius: 10, x: 0, y: 0)

            // Instruction text
            VStack {
                Spacer()
                Text("Point camera at your handwritten notes\nWe'll convert them to text instantly")
                    .font(.serifCaption(15, weight: .regular))
                    .foregroundColor(.forestLight.opacity(0.8))
                    .italic()
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                    .padding(.bottom, -50)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 500)
        .padding(.horizontal, 24)
    }

    // MARK: - Camera Controls

    private var cameraControls: some View {
        HStack(spacing: 40) {
            // Gallery button
            Button(action: {
                // TODO: Open photo library
            }) {
                ZStack {
                    Circle()
                        .fill(Color.forestDark.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(Color.forestMedium.opacity(0.3), lineWidth: 1)
                        )

                    Image(systemName: "photo")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.forestLight)
                }
            }
            .accessibilityLabel("Choose from library")

            // Capture button
            Button(action: {
                cameraManager.capturePhoto()
            }) {
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.forestDark.opacity(0.4), Color.forestMedium.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 80, height: 80)

                    // Main button
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.forestDark.opacity(0.9), Color.forestMedium.opacity(0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)

                    // Inner circle
                    Circle()
                        .stroke(Color.forestLight.opacity(0.3), lineWidth: 2)
                        .frame(width: 60, height: 60)
                }
            }
            .accessibilityLabel("Capture note")
            .accessibilityHint("Takes a photo of your handwritten note")

            // Flash button
            Button(action: {
                // TODO: Toggle flash
            }) {
                ZStack {
                    Circle()
                        .fill(Color.forestDark.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(Color.forestMedium.opacity(0.3), lineWidth: 1)
                        )

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.forestLight)
                }
            }
            .accessibilityLabel("Toggle flash")
        }
    }

    // MARK: - Camera Unavailable View

    private var cameraUnavailableView: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.forestDark.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.forestDark.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    )

                Image(systemName: "camera")
                    .font(.system(size: 60, weight: .thin))
                    .foregroundColor(.textMedium.opacity(0.4))
            }

            if !cameraManager.isAuthorized {
                VStack(spacing: 12) {
                    Text("Camera Access Required")
                        .font(.serifHeadline(26, weight: .bold))
                        .foregroundColor(.forestLight)

                    Text("Please enable camera access in Settings to capture notes")
                        .font(.serifBody(16, weight: .regular))
                        .foregroundColor(.textLight.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .italic()
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                }

                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Open Settings")
                        .font(.serifBody(17, weight: .semibold))
                        .foregroundColor(.forestLight)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.forestDark.opacity(0.95), Color.forestMedium.opacity(0.98)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .padding(.top, 8)
            } else {
                VStack(spacing: 12) {
                    Text("Camera Unavailable")
                        .font(.serifHeadline(26, weight: .bold))
                        .foregroundColor(.forestLight)

                    Text("Camera is not available on this device")
                        .font(.serifBody(16, weight: .regular))
                        .foregroundColor(.textLight.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .italic()
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .forestLight))
                    .scaleEffect(1.5)

                Text("Processing image...")
                    .font(.serifBody(17, weight: .semibold))
                    .foregroundColor(.forestLight)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.forestDark.opacity(0.95))
                    .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
            )
        }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding()
            .background(Color.red)
            .cornerRadius(12)
            .padding()

            Spacer()
        }
    }
}

#Preview {
    CameraView()
}
