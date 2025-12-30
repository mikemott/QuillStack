//
//  OnboardingCompletePage.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI
import EventKit

struct OnboardingCompletePage: View {
    let selectedFeatures: Set<OnboardingFeature>
    var onFinish: () -> Void

    @ObservedObject private var settings = SettingsManager.shared
    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Success animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.forestDark.opacity(0.15), Color.forestMedium.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(showCheckmark ? 1.0 : 0.8)

                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.forestDark)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)
                    .opacity(showCheckmark ? 1.0 : 0)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)
            .padding(.bottom, 32)

            // Title
            Text("You're All Set!")
                .font(.serifTitle(32, weight: .bold))
                .foregroundColor(.forestDark)
                .padding(.bottom, 12)

            Text("QuillStack is ready to capture\nyour handwritten notes")
                .font(.serifBody(16, weight: .regular))
                .foregroundColor(.textMedium)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, 32)

            // Configuration summary
            if !selectedFeatures.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configured Features")
                        .font(.serifBody(14, weight: .semibold))
                        .foregroundColor(.textDark)

                    VStack(spacing: 8) {
                        ForEach(OnboardingFeature.allCases, id: \.self) { feature in
                            if selectedFeatures.contains(feature) {
                                configuredFeatureRow(feature)
                            }
                        }
                    }

                    // Skipped features
                    let skippedFeatures = selectedFeatures.filter { !isConfigured($0) }
                    if !skippedFeatures.isEmpty {
                        Divider()
                            .padding(.vertical, 8)

                        Text("Configure Later in Settings")
                            .font(.serifCaption(12, weight: .medium))
                            .foregroundColor(.textMedium)

                        ForEach(Array(skippedFeatures), id: \.self) { feature in
                            skippedFeatureRow(feature)
                        }
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                .padding(.horizontal, 32)
            }

            Spacer()

            // Start button
            Button(action: onFinish) {
                HStack(spacing: 10) {
                    Image(systemName: "camera")
                    Text("Start Capturing Notes")
                        .font(.serifBody(18, weight: .semibold))
                }
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
            .padding(.bottom, 40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showCheckmark = true
            }
        }
    }

    private func configuredFeatureRow(_ feature: OnboardingFeature) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isConfigured(feature) ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundColor(isConfigured(feature) ? .green : .textLight)

            Image(systemName: feature.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.forestDark)
                .frame(width: 24)

            Text(feature.title)
                .font(.serifBody(14, weight: .medium))
                .foregroundColor(.textDark)

            Spacer()

            if isConfigured(feature) {
                Text("Ready")
                    .font(.serifCaption(11, weight: .semibold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }

    private func skippedFeatureRow(_ feature: OnboardingFeature) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 16))
                .foregroundColor(.textLight)

            Image(systemName: feature.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textMedium)
                .frame(width: 24)

            Text(feature.title)
                .font(.serifBody(14, weight: .regular))
                .foregroundColor(.textMedium)

            Spacer()
        }
    }

    private func isConfigured(_ feature: OnboardingFeature) -> Bool {
        switch feature {
        case .aiEnhancement:
            return settings.hasAPIKey && settings.hasAcceptedAIDisclosure
        case .github:
            return GitHubService.shared.isAuthenticated
        case .obsidian:
            return settings.hasObsidianVault
        case .notion:
            return settings.hasNotionAPIKey && settings.hasNotionDatabase
        case .calendar:
            return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        }
    }
}

#Preview {
    OnboardingCompletePage(
        selectedFeatures: [.aiEnhancement, .github],
        onFinish: {}
    )
}
