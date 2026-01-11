//
//  ContentView.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import SwiftUI

struct ContentView: View {
    @Bindable private var settings = SettingsManager.shared
    @State private var selectedTab = 0
    @State private var showingOnboarding = false

    var body: some View {
        TabView(selection: $selectedTab) {
            CameraView(isEmbeddedInTab: true)
                .tabItem {
                    Label("Capture", systemImage: "camera")
                }
                .tag(0)

            NoteListView()
                .tabItem {
                    Label("Notes", systemImage: "doc.text")
                }
                .tag(1)

            NoteSearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
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
            SimpleOnboardingView()
        }
    }
}

#Preview {
    ContentView()
}
