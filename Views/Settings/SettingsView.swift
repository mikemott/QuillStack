//
//  SettingsView.swift
//  QuillStack
//
//  Created on 2025-12-15.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var apiKeyInput: String = ""
    @State private var showingAPIKey = false
    @State private var testingAPI = false
    @State private var apiTestResult: APITestResult?

    enum APITestResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamLight.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // AI Enhancement Section
                        aiEnhancementSection

                        // OCR Settings Section
                        ocrSettingsSection

                        // About Section
                        aboutSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                settings.loadSettings()
                apiKeyInput = settings.claudeAPIKey ?? ""
            }
        }
    }

    // MARK: - AI Enhancement Section

    private var aiEnhancementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "AI Enhancement", icon: "sparkles")

            VStack(spacing: 0) {
                // API Key Entry
                VStack(alignment: .leading, spacing: 8) {
                    Text("Claude API Key")
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.textDark)

                    HStack(spacing: 12) {
                        Group {
                            if showingAPIKey {
                                TextField("sk-ant-...", text: $apiKeyInput)
                            } else {
                                SecureField("sk-ant-...", text: $apiKeyInput)
                            }
                        }
                        .font(.system(size: 14, design: .monospaced))
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

                    Text("Get your API key from console.anthropic.com")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textMedium)
                }
                .padding(16)

                Divider()

                // Save & Test Button
                HStack(spacing: 12) {
                    Button(action: saveAndTestAPIKey) {
                        HStack(spacing: 8) {
                            if testingAPI {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle")
                            }
                            Text(testingAPI ? "Testing..." : "Save & Test")
                                .font(.serifBody(14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            apiKeyInput.isEmpty
                                ? Color.gray
                                : Color.forestDark
                        )
                        .cornerRadius(8)
                    }
                    .disabled(apiKeyInput.isEmpty || testingAPI)

                    if settings.hasAPIKey {
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
                if let result = apiTestResult {
                    HStack(spacing: 8) {
                        switch result {
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("API key is valid!")
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

                Divider()

                // Auto-enhance toggle
                Toggle(isOn: $settings.autoEnhanceOCR) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-enhance OCR")
                            .font(.serifBody(15, weight: .medium))
                            .foregroundColor(.textDark)
                        Text("Automatically clean up text after capture")
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textMedium)
                    }
                }
                .tint(.forestDark)
                .padding(16)
                .opacity(settings.hasAPIKey ? 1 : 0.5)
                .disabled(!settings.hasAPIKey)
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - OCR Settings Section

    private var ocrSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Text Recognition", icon: "text.viewfinder")

            VStack(spacing: 0) {
                // Show highlights toggle
                Toggle(isOn: $settings.showLowConfidenceHighlights) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Highlight uncertain words")
                            .font(.serifBody(15, weight: .medium))
                            .foregroundColor(.textDark)
                        Text("Underline words the OCR is unsure about")
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textMedium)
                    }
                }
                .tint(.forestDark)
                .padding(16)

                Divider()

                // Confidence threshold slider
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Confidence threshold")
                            .font(.serifBody(15, weight: .medium))
                            .foregroundColor(.textDark)
                        Spacer()
                        Text("\(Int(settings.lowConfidenceThreshold * 100))%")
                            .font(.serifBody(14, weight: .medium))
                            .foregroundColor(.forestDark)
                    }

                    Slider(value: $settings.lowConfidenceThreshold, in: 0.5...0.95, step: 0.05)
                        .tint(.forestDark)

                    Text("Words below this confidence will be highlighted")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textMedium)
                }
                .padding(16)
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "About", icon: "info.circle")

            VStack(spacing: 0) {
                aboutRow(title: "Version", value: "1.0.0")
                Divider()
                aboutRow(title: "OCR Engine", value: "Apple Vision")
                Divider()
                aboutRow(title: "AI Model", value: "Claude Sonnet 4")
            }
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

    private func aboutRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.serifBody(15, weight: .regular))
                .foregroundColor(.textDark)
            Spacer()
            Text(value)
                .font(.serifBody(14, weight: .medium))
                .foregroundColor(.textMedium)
        }
        .padding(16)
    }

    // MARK: - Actions

    private func saveAndTestAPIKey() {
        testingAPI = true
        apiTestResult = nil

        settings.claudeAPIKey = apiKeyInput

        Task {
            do {
                // Simple test call
                _ = try await LLMService.shared.enhanceOCRText("test")
                await MainActor.run {
                    apiTestResult = .success
                    testingAPI = false
                }
            } catch {
                await MainActor.run {
                    apiTestResult = .failure(error.localizedDescription)
                    testingAPI = false
                }
            }
        }
    }

    private func clearAPIKey() {
        apiKeyInput = ""
        settings.claudeAPIKey = nil
        apiTestResult = nil
    }
}

#Preview {
    SettingsView()
}
