//
//  OnboardingView.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI

// MARK: - Onboarding Page Type

enum OnboardingPageType: Equatable {
    case welcome
    case useCase
    case claude
    case github
    case obsidian
    case notion
    case calendar
    case complete
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = SettingsManager.shared

    @State private var currentPageIndex: Int = 0
    @State private var selectedFeatures: Set<OnboardingFeature> = []
    @State private var pages: [OnboardingPageType] = [.welcome, .useCase]

    var body: some View {
        ZStack {
            // Background
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPageIndex) {
                    ForEach(pages.indices, id: \.self) { index in
                        let pageType = pages[index]
                        pageView(for: pageType)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPageIndex)

                // Progress dots
                progressDots
                    .padding(.bottom, 20)
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Page View Builder

    @ViewBuilder
    private func pageView(for type: OnboardingPageType) -> some View {
        switch type {
        case .welcome:
            OnboardingWelcomePage(onContinue: nextPage)

        case .useCase:
            OnboardingUseCasePage(
                selectedFeatures: $selectedFeatures,
                onContinue: {
                    buildPageList()
                    nextPage()
                }
            )

        case .claude:
            OnboardingClaudePage(
                onContinue: nextPage,
                onSkip: nextPage
            )

        case .github:
            OnboardingGitHubPage(
                onContinue: nextPage,
                onSkip: nextPage
            )

        case .obsidian:
            OnboardingObsidianPage(
                onContinue: nextPage,
                onSkip: nextPage
            )

        case .notion:
            OnboardingNotionPage(
                onContinue: nextPage,
                onSkip: nextPage
            )

        case .calendar:
            OnboardingCalendarPage(
                onContinue: nextPage,
                onSkip: nextPage
            )

        case .complete:
            OnboardingCompletePage(
                selectedFeatures: selectedFeatures,
                onFinish: completeOnboarding
            )
        }
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Circle()
                    .fill(index == currentPageIndex ? Color.forestDark : Color.forestDark.opacity(0.25))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentPageIndex ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: currentPageIndex)
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Navigation

    private func nextPage() {
        withAnimation {
            if currentPageIndex < pages.count - 1 {
                currentPageIndex += 1
            }
        }
    }

    private func previousPage() {
        withAnimation {
            if currentPageIndex > 0 {
                currentPageIndex -= 1
            }
        }
    }

    private func buildPageList() {
        var newPages: [OnboardingPageType] = [.welcome, .useCase]

        if selectedFeatures.contains(.aiEnhancement) {
            newPages.append(.claude)
        }
        if selectedFeatures.contains(.github) {
            newPages.append(.github)
        }
        if selectedFeatures.contains(.obsidian) {
            newPages.append(.obsidian)
        }
        if selectedFeatures.contains(.notion) {
            newPages.append(.notion)
        }
        if selectedFeatures.contains(.calendar) {
            newPages.append(.calendar)
        }

        newPages.append(.complete)
        pages = newPages
    }

    private func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        settings.selectedOnboardingFeatures = selectedFeatures
        dismiss()
    }
}

#Preview {
    OnboardingView()
}
