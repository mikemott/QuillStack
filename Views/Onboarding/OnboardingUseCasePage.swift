//
//  OnboardingUseCasePage.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI

struct OnboardingUseCasePage: View {
    @Binding var selectedFeatures: Set<OnboardingFeature>
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Text("What would you like to do?")
                    .font(.serifHeadline(26, weight: .bold))
                    .foregroundColor(.forestDark)
                    .multilineTextAlignment(.center)

                Text("Select the features you want to set up.\nYou can always change these later in Settings.")
                    .font(.serifBody(15, weight: .regular))
                    .foregroundColor(.textMedium)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.top, 40)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)

            // Feature cards
            ScrollView {
                VStack(spacing: 12) {
                    // Always-on OCR feature (not toggleable)
                    baseFeatureCard

                    // Toggleable features
                    ForEach(OnboardingFeature.allCases, id: \.self) { feature in
                        featureCard(for: feature)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }

            // Continue Button
            Button(action: onContinue) {
                Text(selectedFeatures.isEmpty ? "Skip Setup" : "Continue")
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

    // MARK: - Base Feature Card (Always On)

    private var baseFeatureCard: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.forestDark.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "text.viewfinder")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.forestDark)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text("Scan & Organize Notes")
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.textDark)

                Text("Camera capture with OCR")
                    .font(.serifCaption(13, weight: .regular))
                    .foregroundColor(.textMedium)
            }

            Spacer()

            // Always enabled badge
            Text("Always On")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.forestDark)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.forestDark.opacity(0.1))
                .cornerRadius(6)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.forestDark.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Feature Card

    private func featureCard(for feature: OnboardingFeature) -> some View {
        let isSelected = selectedFeatures.contains(feature)

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isSelected {
                    selectedFeatures.remove(feature)
                } else {
                    selectedFeatures.insert(feature)
                }
            }
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.forestDark : Color.forestDark.opacity(0.08))
                        .frame(width: 44, height: 44)

                    Image(systemName: feature.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? .white : .forestDark)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(feature.title)
                        .font(.serifBody(16, weight: .semibold))
                        .foregroundColor(.textDark)

                    Text(feature.description)
                        .font(.serifCaption(13, weight: .regular))
                        .foregroundColor(.textMedium)
                }

                Spacer()

                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.forestDark : Color.textLight, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.forestDark)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(16)
            .background(isSelected ? Color.forestDark.opacity(0.05) : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.forestDark.opacity(0.3) : Color.forestDark.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0.04), radius: isSelected ? 6 : 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingUseCasePage(
        selectedFeatures: .constant([.aiEnhancement]),
        onContinue: {}
    )
}
