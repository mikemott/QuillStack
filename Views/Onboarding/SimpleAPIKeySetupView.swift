//
//  SimpleAPIKeySetupView.swift
//  QuillStack
//
//  Created for QUI-150: API Key Onboarding Flow
//

import SwiftUI

struct SimpleAPIKeySetupView: View {
    @Bindable private var settings = SettingsManager.shared

    var onContinue: () -> Void
    var onSkip: () -> Void

    @State private var apiKeyInput: String = ""
    @State private var showingAPIKey = false
    @State private var testingAPI = false
    @State private var testResult: TestResult?
    @State private var showingWhyNeeded = false

    enum TestResult {
        case success
        case failure(String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 20)

                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.forestDark.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: "key.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.forestDark)
                    }

                    Text("One More Thing")
                        .font(.serifHeadline(28, weight: .bold))
                        .foregroundColor(.forestDark)

                    Text("QuillStack uses AI to organize your notes automatically")
                        .font(.serifBody(16, weight: .regular))
                        .foregroundColor(.textMedium)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 32)

                // API Key Input Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Claude API Key")
                            .font(.serifBody(15, weight: .semibold))
                            .foregroundColor(.textDark)

                        Spacer()

                        Button(action: { withAnimation { showingWhyNeeded.toggle() }}) {
                            HStack(spacing: 4) {
                                Text("Why do I need this?")
                                    .font(.serifCaption(12, weight: .medium))
                                Image(systemName: showingWhyNeeded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.forestDark)
                        }
                    }

                    // Why needed explanation
                    if showingWhyNeeded {
                        VStack(alignment: .leading, spacing: 8) {
                            explanationBullet("Cleans up OCR errors in handwriting")
                            explanationBullet("Automatically tags and organizes notes")
                            explanationBullet("Extracts structured data (contacts, events, todos)")
                            explanationBullet("Runs directly with your API key - no middleman")

                            Text("OCR works without this, but you'll miss the magic.")
                                .font(.serifCaption(13, weight: .medium))
                                .foregroundColor(.textMedium)
                                .italic()
                                .padding(.top, 4)
                        }
                        .padding(14)
                        .background(Color.forestDark.opacity(0.05))
                        .cornerRadius(8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // API Key Input
                    HStack(spacing: 12) {
                        Group {
                            if showingAPIKey {
                                TextField("sk-ant-...", text: $apiKeyInput)
                                    .onChange(of: apiKeyInput) { _, _ in
                                        testResult = nil
                                    }
                            } else {
                                SecureField("sk-ant-...", text: $apiKeyInput)
                                    .onChange(of: apiKeyInput) { _, _ in
                                        testResult = nil
                                    }
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

                    // Get key link
                    if let consoleURL = URL(string: "https://console.anthropic.com") {
                        Link(destination: consoleURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12))
                                Text("Get your API key (free tier available)")
                                    .font(.serifCaption(13, weight: .medium))
                            }
                            .foregroundColor(.forestDark)
                        }
                    }

                    // Test result
                    if let result = testResult {
                        HStack(spacing: 8) {
                            switch result {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("API key verified!")
                                    .font(.serifCaption(14, weight: .medium))
                                    .foregroundColor(.green)
                            case .failure(let error):
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.serifCaption(14, weight: .medium))
                                    .foregroundColor(.red)
                            }
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                .padding(.horizontal, 24)

                Spacer(minLength: 20)

                // Buttons
                VStack(spacing: 14) {
                    // Continue/Save Button
                    Button(action: saveAndContinue) {
                        HStack(spacing: 10) {
                            if testingAPI {
                                ProgressView()
                                    .scaleEffect(0.9)
                                    .tint(.white)
                            }
                            Text(testingAPI ? "Verifying..." : (apiKeyInput.isEmpty ? "Continue" : "Verify & Continue"))
                                .font(.serifBody(18, weight: .semibold))
                        }
                        .foregroundColor(.forestLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: (testingAPI || testResult?.isSuccess == true)
                                    ? [Color.gray.opacity(0.5)]
                                    : [Color.forestDark, Color.forestMedium.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: .forestDark.opacity(0.2), radius: 6, x: 0, y: 3)
                    }
                    .disabled(testingAPI || testResult?.isSuccess == true)

                    // Skip button
                    Button(action: onSkip) {
                        Text("Skip - I'll use OCR only for now")
                            .font(.serifBody(15, weight: .medium))
                            .foregroundColor(.textMedium)
                    }
                    .disabled(testingAPI || testResult?.isSuccess == true)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .background(Color.creamLight.ignoresSafeArea())
        .onAppear {
            apiKeyInput = settings.claudeAPIKey ?? ""
        }
    }

    private func explanationBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .foregroundColor(.forestDark)
                .font(.serifCaption(13, weight: .medium))
            Text(text)
                .font(.serifCaption(13, weight: .regular))
                .foregroundColor(.textMedium)
        }
    }

    private func saveAndContinue() {
        // Trim whitespace from input
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // If no API key, just continue (skip)
        if trimmedKey.isEmpty {
            onContinue()
            return
        }

        // Basic format validation
        guard trimmedKey.hasPrefix("sk-ant-") else {
            testResult = .failure("API key should start with 'sk-ant-'")
            return
        }

        // Validate API key before storing
        testingAPI = true
        testResult = nil

        Task {
            let isValid = await LLMService.shared.validateAPIKey(trimmedKey)
            await MainActor.run {
                testingAPI = false
                if isValid {
                    // Only store after successful validation
                    settings.claudeAPIKey = trimmedKey
                    testResult = .success

                    // Brief delay to show success, then continue
                    Task {
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        onContinue()
                    }
                } else {
                    testResult = .failure("Invalid API key. Check and try again.")
                }
            }
        }
    }
}

#Preview {
    SimpleAPIKeySetupView(onContinue: {}, onSkip: {})
}
