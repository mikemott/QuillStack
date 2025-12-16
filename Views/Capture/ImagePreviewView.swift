//
//  ImagePreviewView.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import SwiftUI

struct ImagePreviewView: View {
    let image: UIImage
    let onConfirm: () -> Void
    let onRetake: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                // Zoomable image preview
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 4)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    withAnimation(.spring()) {
                                        if scale < 1.2 {
                                            scale = 1.0
                                        }
                                    }
                                }
                        )
                }

                // Action buttons overlay
                VStack {
                    Spacer()

                    HStack(spacing: 60) {
                        // Retake button
                        Button(action: onRetake) {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title)
                                    .frame(width: 56, height: 56)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())

                                Text("Retake")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                        }
                        .accessibilityLabel("Retake photo")

                        // Use photo button
                        Button(action: onConfirm) {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 32))
                                    .frame(width: 72, height: 72)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Circle())
                                    .shadow(color: Color.appAccent.opacity(0.5), radius: 12, x: 0, y: 4)

                                Text("Use Photo")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                        }
                        .accessibilityLabel("Use photo")
                        .accessibilityHint("Process this image with OCR")
                    }
                    .padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(Color.black.opacity(0.5), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

#Preview {
    ImagePreviewView(
        image: UIImage(systemName: "photo")!,
        onConfirm: {},
        onRetake: {}
    )
}
