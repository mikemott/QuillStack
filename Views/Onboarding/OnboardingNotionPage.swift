//
//  OnboardingNotionPage.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI

struct OnboardingNotionPage: View {
    @ObservedObject private var settings = SettingsManager.shared

    var onContinue: () -> Void
    var onSkip: () -> Void

    @State private var apiKeyInput: String = ""
    @State private var showingAPIKey = false
    @State private var isConnecting = false
    @State private var testResult: TestResult?
    @State private var databases: [NotionDatabase] = []
    @State private var selectedDatabaseId: String = ""

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.08))
                            .frame(width: 80, height: 80)

                        Image(systemName: "doc.text")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.black.opacity(0.8))
                    }

                    Text("Notion Export")
                        .font(.serifHeadline(26, weight: .bold))
                        .foregroundColor(.forestDark)

                    Text("Sync your notes to Notion\ndatabases automatically")
                        .font(.serifBody(15, weight: .regular))
                        .foregroundColor(.textMedium)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.top, 32)

                // API Key Input
                VStack(alignment: .leading, spacing: 16) {
                    Text("Integration Token")
                        .font(.serifBody(14, weight: .semibold))
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
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.forestDark.opacity(0.2), lineWidth: 1)
                    )

                    Link(destination: URL(string: "https://www.notion.so/my-integrations")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12))
                            Text("Create integration at notion.so/my-integrations")
                                .font(.serifCaption(12, weight: .medium))
                        }
                        .foregroundColor(.forestDark)
                    }

                    // Connect button
                    Button(action: connectAndLoad) {
                        HStack(spacing: 10) {
                            if isConnecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(isConnecting ? "Connecting..." : "Connect & Load Databases")
                                .font(.serifBody(14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(apiKeyInput.isEmpty ? Color.gray.opacity(0.5) : Color.forestDark)
                        .cornerRadius(10)
                    }
                    .disabled(apiKeyInput.isEmpty || isConnecting)

                    // Test result
                    if let result = testResult {
                        HStack(spacing: 8) {
                            switch result {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Connected!")
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
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                .padding(.horizontal, 24)

                // Database Selection
                if !databases.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Default Database")
                            .font(.serifBody(14, weight: .semibold))
                            .foregroundColor(.textDark)

                        VStack(spacing: 8) {
                            ForEach(databases) { database in
                                Button(action: { selectedDatabaseId = database.id }) {
                                    HStack {
                                        Image(systemName: selectedDatabaseId == database.id ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedDatabaseId == database.id ? .forestDark : .textLight)

                                        Text(database.name)
                                            .font(.serifBody(14, weight: .medium))
                                            .foregroundColor(.textDark)

                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(selectedDatabaseId == database.id ? Color.forestDark.opacity(0.05) : Color.clear)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 20)

                // Save Button
                Button(action: saveAndContinue) {
                    Text("Save & Continue")
                        .font(.serifBody(18, weight: .semibold))
                        .foregroundColor(.forestLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(saveButtonBackground)
                        .cornerRadius(14)
                }
                .disabled(databases.isEmpty || selectedDatabaseId.isEmpty)
                .padding(.horizontal, 32)

                // Skip button
                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(.serifBody(15, weight: .medium))
                        .foregroundColor(.textMedium)
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            apiKeyInput = settings.notionAPIKey ?? ""
            selectedDatabaseId = settings.notionDefaultDatabaseId ?? ""
        }
    }

    private var saveButtonBackground: some ShapeStyle {
        if databases.isEmpty || selectedDatabaseId.isEmpty {
            return AnyShapeStyle(Color.gray.opacity(0.5))
        } else {
            return AnyShapeStyle(LinearGradient(
                colors: [Color.forestDark, Color.forestMedium.opacity(0.9)],
                startPoint: .leading,
                endPoint: .trailing
            ))
        }
    }

    private func connectAndLoad() {
        isConnecting = true
        testResult = nil

        settings.notionAPIKey = apiKeyInput

        Task {
            do {
                let apiClient = NotionAPIClient()
                let fetchedDatabases = try await apiClient.listDatabases()

                await MainActor.run {
                    databases = fetchedDatabases
                    if selectedDatabaseId.isEmpty, let first = fetchedDatabases.first {
                        selectedDatabaseId = first.id
                    }
                    testResult = .success
                    isConnecting = false
                }
            } catch {
                await MainActor.run {
                    testResult = .failure("Connection failed")
                    isConnecting = false
                }
            }
        }
    }

    private func saveAndContinue() {
        settings.notionDefaultDatabaseId = selectedDatabaseId
        onContinue()
    }
}

#Preview {
    OnboardingNotionPage(onContinue: {}, onSkip: {})
}
