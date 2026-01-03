//
//  ContentView.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedTab = 0
    @State private var showingOnboarding = false

    // Deep link handling
    @Environment(DeepLinkManager.self) private var deepLinkManager
    @State private var showingCameraFromDeepLink = false
    @State private var showingVoiceFromDeepLink = false
    @State private var deepLinkNoteId: UUID?

    var body: some View {
        TabView(selection: $selectedTab) {
            NoteListView(
                showingCameraFromDeepLink: $showingCameraFromDeepLink,
                showingVoiceFromDeepLink: $showingVoiceFromDeepLink,
                deepLinkNoteId: $deepLinkNoteId
            )
                .tabItem {
                    Label("Notes", systemImage: "doc.text")
                }
                .tag(0)

            TypeGuideView()
                .tabItem {
                    Label("Type Guide", systemImage: "book.closed")
                }
                .tag(1)

            StatisticsView()
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .tint(.forestDark) // Tab bar accent color
        .onAppear {
            // Show onboarding if not completed
            if !settings.hasCompletedOnboarding {
                showingOnboarding = true
            }

            // Customize tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.creamLight)

            // Customize tab bar item colors
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.textMedium)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(Color.textMedium),
                .font: UIFont.systemFont(ofSize: 10, weight: .medium)
            ]

            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.forestDark)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(Color.forestDark),
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
            ]

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView()
        }
        .onChange(of: deepLinkManager.activeDeepLink) { oldValue, newValue in
            handleDeepLink(newValue)
        }
    }

    private func handleDeepLink(_ deepLink: DeepLink?) {
        guard let deepLink else { return }

        switch deepLink {
        case .captureCamera:
            selectedTab = 0 // Switch to Notes tab
            showingCameraFromDeepLink = true

        case .captureVoice:
            selectedTab = 0 // Switch to Notes tab
            showingVoiceFromDeepLink = true

        case .note(let uuid):
            selectedTab = 0 // Switch to Notes tab
            deepLinkNoteId = uuid

        case .tab(let index):
            if index >= 0 && index < 4 {
                selectedTab = index
            }
        }

        // Reset deep link after handling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            deepLinkManager.reset()
        }
    }
}

#Preview {
    ContentView()
}
