//
//  OnboardingClaudePage.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI

struct OnboardingClaudePage: View {
    @Bindable private var settings = SettingsManager.shared

    var onContinue: () -> Void
    var onSkip: () -> Void

    @State private var apiKeyInput: String = ""
    @State private var showingAPIKey = false
    @State private var testingAPI = false
    @State private var testResult: TestResult?
    @State private var hasAcknowledged = false
    @State private var showingDisclosure = false

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
                            .fill(Color.forestDark.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: "sparkles")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.forestDark)
                    }

                    Text("AI Enhancement")
                        .font(.serifHeadline(26, weight: .bold))
                        .foregroundColor(.forestDark)

                    Text("Add your Claude API key to enable\nOCR cleanup and note summaries")
                        .font(.serifBody(15, weight: .regular))
                        .foregroundColor(.textMedium)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.top, 32)

                // API Key Input Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Claude API Key")
                        .font(.serifBody(14, weight: .semibold))
                        .foregroundColor(.textDark)

                    HStack(spacing: 12) {
                        Group {
                            if showingAPIKey {
                                TextField("sk-ant-...", text: $apiKeyInput)
                            } else {
                                SecureField("sk-ant-...", text: $apiKeyInput)
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

                    Link(destination: URL(string: "https://console.anthropic.com")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12))
                            Text("Get your API key from console.anthropic.com")
                                .font(.serifCaption(12, weight: .medium))
                        }
                        .foregroundColor(.forestDark)
                    }

                    // Test result
                    if let result = testResult {
                        HStack(spacing: 8) {
                            switch result {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("API key verified!")
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
                        .padding(.top, 4)
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                .padding(.horizontal, 24)

                // Data Disclosure Section
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: { withAnimation { showingDisclosure.toggle() }}) {
                        HStack {
                            Image(systemName: "hand.raised")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.forestDark)

                            Text("What data is sent?")
                                .font(.serifBody(15, weight: .semibold))
                                .foregroundColor(.textDark)

                            Spacer()

                            Image(systemName: showingDisclosure ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textMedium)
                        }
                    }
                    .buttonStyle(.plain)

                    if showingDisclosure {
                        VStack(alignment: .leading, spacing: 12) {
                            disclosureBullet("Note text is sent to Anthropic's Claude API")
                            disclosureBullet("Data transmitted securely over HTTPS")
                            disclosureBullet("Your notes are not used to train AI models")
                            disclosureBullet("OCR works entirely on-device without AI")

                            Link(destination: URL(string: "https://www.anthropic.com/privacy")!) {
                                HStack(spacing: 6) {
                                    Text("Read full privacy policy")
                                        .font(.serifCaption(12, weight: .medium))
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.forestDark)
                            }
                            .padding(.top, 4)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Acknowledgment checkbox
                    Button(action: { hasAcknowledged.toggle() }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(hasAcknowledged ? Color.forestDark : Color.textLight, lineWidth: 2)
                                    .frame(width: 20, height: 20)

                                if hasAcknowledged {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.forestDark)
                                        .frame(width: 20, height: 20)

                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }

                            Text("I understand how my data is processed")
                                .font(.serifBody(14, weight: .medium))
                                .foregroundColor(.textDark)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                .padding(.horizontal, 24)

                Spacer(minLength: 20)

                // Save Button
                Button(action: saveAndContinue) {
                    HStack(spacing: 10) {
                        if testingAPI {
                            ProgressView()
                                .scaleEffect(0.9)
                                .tint(.white)
                        }
                        Text(testingAPI ? "Verifying..." : "Save & Continue")
                            .font(.serifBody(18, weight: .semibold))
                    }
                    .foregroundColor(.forestLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: (apiKeyInput.isEmpty || !hasAcknowledged)
                                ? [Color.gray.opacity(0.5)]
                                : [Color.forestDark, Color.forestMedium.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: .forestDark.opacity(0.2), radius: 6, x: 0, y: 3)
                }
                .disabled(apiKeyInput.isEmpty || !hasAcknowledged || testingAPI)
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
            apiKeyInput = settings.claudeAPIKey ?? ""
            hasAcknowledged = settings.hasAcceptedAIDisclosure
        }
    }

    private func disclosureBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .foregroundColor(.forestDark)
            Text(text)
                .font(.serifCaption(13, weight: .regular))
                .foregroundColor(.textMedium)
        }
    }

    private func saveAndContinue() {
        testingAPI = true
        testResult = nil

        settings.claudeAPIKey = apiKeyInput

        Task {
            let isValid = await settings.validateClaudeAPIKey()
            await MainActor.run {
                testingAPI = false
                if isValid {
                    testResult = .success
                    settings.hasAcceptedAIDisclosure = true

                    // Brief delay to show success, then continue
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        onContinue()
                    }
                } else {
                    testResult = .failure("Invalid API key")
                }
            }
        }
    }
}

#Preview {
    OnboardingClaudePage(onContinue: {}, onSkip: {})
}
