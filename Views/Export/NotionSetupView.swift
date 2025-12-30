//
//  NotionSetupView.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import SwiftUI

struct NotionSetupView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var apiKeyInput: String = ""
    @State private var showingAPIKey = false
    @State private var testingConnection = false
    @State private var testResult: TestResult?
    @State private var databases: [NotionDatabase] = []
    @State private var selectedDatabaseId: String = ""

    enum TestResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // API Key Section
                    apiKeySection

                    // Database Selection Section
                    if !databases.isEmpty {
                        databaseSection
                    }

                    // Instructions
                    instructionsSection
                }
                .padding(20)
            }
        }
        .navigationTitle("Notion Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            apiKeyInput = settings.notionAPIKey ?? ""
            selectedDatabaseId = settings.notionDefaultDatabaseId ?? ""
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "API Connection", icon: "key")

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Integration Token")
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.textDark)

                    HStack(spacing: 12) {
                        Group {
                            if showingAPIKey {
                                TextField("secret_...", text: $apiKeyInput)
                            } else {
                                SecureField("secret_...", text: $apiKeyInput)
                            }
                        }
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Color.black)
                        .tint(.black)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        Button(action: { showingAPIKey.toggle() }) {
                            Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                                .foregroundColor(.textMedium)
                        }
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.forestDark.opacity(0.2), lineWidth: 1)
                    )

                    Text("Get your token from notion.so/my-integrations")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textMedium)
                }
                .padding(16)

                Divider()

                // Connect & Load Button
                HStack(spacing: 12) {
                    Button(action: connectAndLoad) {
                        HStack(spacing: 8) {
                            if testingConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "link")
                            }
                            Text(testingConnection ? "Connecting..." : "Connect & Load Databases")
                                .font(.serifBody(14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(apiKeyInput.isEmpty || testingConnection ? Color.gray : Color.forestDark)
                        .cornerRadius(8)
                    }
                    .disabled(apiKeyInput.isEmpty || testingConnection)

                    if settings.hasNotionAPIKey {
                        Button(action: clearAPIKey) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .padding(12)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(16)

                // Test Result
                if let result = testResult {
                    HStack(spacing: 8) {
                        switch result {
                        case .success(let message):
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(message)
                                .font(.serifCaption(13, weight: .medium))
                                .foregroundColor(.green)
                        case .failure(let error):
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.serifCaption(13, weight: .medium))
                                .foregroundColor(.red)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Database Section

    private var databaseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Default Database", icon: "tablecells")

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select a database for new notes")
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.textDark)

                    ForEach(databases) { database in
                        Button(action: {
                            selectedDatabaseId = database.id
                            settings.notionDefaultDatabaseId = database.id
                        }) {
                            HStack {
                                Image(systemName: selectedDatabaseId == database.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedDatabaseId == database.id ? .forestDark : .textLight)

                                Text(database.name)
                                    .font(.serifBody(15, weight: .regular))
                                    .foregroundColor(.textDark)

                                Spacer()
                            }
                            .padding(.vertical, 12)
                        }

                        if database.id != databases.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Instructions

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "How to Set Up Notion", icon: "questionmark.circle")

            VStack(alignment: .leading, spacing: 12) {
                instructionStep(number: 1, text: "Go to notion.so/my-integrations")
                instructionStep(number: 2, text: "Click \"New integration\"")
                instructionStep(number: 3, text: "Name it \"QuillStack\" and select your workspace")
                instructionStep(number: 4, text: "Copy the \"Internal Integration Token\"")
                instructionStep(number: 5, text: "Open a Notion database and share it with your integration")

                Text("Important: You must share each database with your integration for it to appear here.")
                    .font(.serifCaption(12, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.top, 8)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.forestDark)
            Text(title)
                .font(.serifHeadline(18, weight: .semibold))
                .foregroundColor(.textDark)
        }
    }

    private func instructionStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.serifCaption(12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.forestDark)
                .clipShape(Circle())

            Text(text)
                .font(.serifBody(14, weight: .regular))
                .foregroundColor(.textDark)
        }
    }

    // MARK: - Actions

    private func connectAndLoad() {
        testingConnection = true
        testResult = nil

        settings.notionAPIKey = apiKeyInput

        Task {
            do {
                let apiClient = NotionAPIClient()
                let loadedDatabases = try await apiClient.listDatabases()

                await MainActor.run {
                    databases = loadedDatabases
                    testResult = .success("Found \(loadedDatabases.count) database(s)")
                    testingConnection = false

                    // Auto-select first database if none selected
                    if selectedDatabaseId.isEmpty && !loadedDatabases.isEmpty {
                        selectedDatabaseId = loadedDatabases[0].id
                        settings.notionDefaultDatabaseId = loadedDatabases[0].id
                    }
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                    testingConnection = false
                    databases = []
                }
            }
        }
    }

    private func clearAPIKey() {
        apiKeyInput = ""
        settings.notionAPIKey = nil
        settings.notionDefaultDatabaseId = nil
        databases = []
        selectedDatabaseId = ""
        testResult = nil
    }
}

#Preview {
    NavigationStack {
        NotionSetupView()
    }
}
