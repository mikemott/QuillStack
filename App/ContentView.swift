//
//  ContentView.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NoteListView()
                .tabItem {
                    Label("Notes", systemImage: "doc.text")
                }
                .tag(0)

            MeetingListView()
                .tabItem {
                    Label("Meetings", systemImage: "calendar")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .tint(.forestDark) // Tab bar accent color
        .onAppear {
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
    }
}

#Preview {
    ContentView()
}
