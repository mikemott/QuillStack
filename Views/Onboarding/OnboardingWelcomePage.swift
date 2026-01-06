//
//  OnboardingWelcomePage.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI

struct OnboardingWelcomePage: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo/Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.forestDark, Color.forestMedium],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: .forestDark.opacity(0.3), radius: 20, x: 0, y: 10)

                Image(systemName: "pencil.line")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(.forestLight)
            }
            .padding(.bottom, 40)

            // Title
            Text("Welcome to QuillStack")
                .font(.serifTitle(32, weight: .bold))
                .foregroundColor(.forestDark)
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)

            // Subtitle
            Text("Turn handwritten notes into\norganized, searchable text")
                .font(.serifBody(18, weight: .regular))
                .foregroundColor(.textMedium)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 40)
                .padding(.bottom, 32)

            // Features preview
            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "camera.fill", text: "Capture notes with your camera")
                featureRow(icon: "text.viewfinder", text: "Instant OCR text recognition")
                featureRow(icon: "sparkles", text: "Automatically detects what you capture")
            }
            .padding(.horizontal, 40)

            Spacer()

            // Get Started Button
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.serifBody(18, weight: .semibold))
                    .foregroundColor(.forestLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.forestDark, Color.forestMedium.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: .forestDark.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.forestDark)
                .frame(width: 32)

            Text(text)
                .font(.serifBody(16, weight: .regular))
                .foregroundColor(.textDark)
        }
    }
}

#Preview {
    OnboardingWelcomePage(onContinue: {})
}
