//
//  SimpleOnboardingView.swift
//  QuillStack
//
//  Created for QUI-150: API Key Onboarding Flow
//  Simplified 2-screen onboarding: Welcome → API Key Setup
//

import SwiftUI

struct SimpleOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = SettingsManager.shared

    @State private var currentScreen: OnboardingScreen = .welcome

    enum OnboardingScreen {
        case welcome
        case apiKeySetup
    }

    var body: some View {
        ZStack {
            // Background
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                // Screen content
                Group {
                    switch currentScreen {
                    case .welcome:
                        SimpleWelcomeView(onContinue: {
                            withAnimation {
                                currentScreen = .apiKeySetup
                            }
                        })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))

                    case .apiKeySetup:
                        SimpleAPIKeySetupView(
                            onContinue: completeOnboarding,
                            onSkip: completeOnboarding
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: currentScreen)
            }
        }
        .interactiveDismissDisabled()
    }

    private func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        dismiss()
    }
}

#Preview {
    SimpleOnboardingView()
}
