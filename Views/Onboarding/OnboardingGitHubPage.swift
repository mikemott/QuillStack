//
//  OnboardingGitHubPage.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI
import UIKit

struct OnboardingGitHubPage: View {
    var onContinue: () -> Void
    var onSkip: () -> Void

    @State private var github = GitHubService.shared
    @State private var isConnecting = false
    @State private var showDeviceCode = false
    @State private var isPollng = false
    @State private var errorMessage: String?
    @State private var codeCopied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.1, green: 0.1, blue: 0.1).opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    }

                    Text("GitHub Integration")
                        .font(.serifHeadline(26, weight: .bold))
                        .foregroundColor(.forestDark)

                    Text("Turn handwritten feature requests\ninto GitHub issues instantly")
                        .font(.serifBody(15, weight: .regular))
                        .foregroundColor(.textMedium)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.top, 32)

                // Content based on state
                if github.isAuthenticated {
                    connectedView
                } else if showDeviceCode, let deviceCode = github.deviceCode {
                    deviceCodeView(deviceCode)
                } else {
                    connectView
                }

                // How it works
                howItWorksCard
                    .padding(.horizontal, 24)

                Spacer(minLength: 20)

                // Continue/Skip buttons
                if github.isAuthenticated {
                    Button(action: onContinue) {
                        Text("Continue")
                            .font(.serifBody(18, weight: .semibold))
                            .foregroundColor(.forestLight)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [Color.forestDark, Color.forestMedium.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 32)
                }

                Button(action: onSkip) {
                    Text(github.isAuthenticated ? "" : "Skip for now")
                        .font(.serifBody(15, weight: .medium))
                        .foregroundColor(.textMedium)
                }
                .opacity(github.isAuthenticated ? 0 : 1)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Connect View

    private var connectView: some View {
        VStack(spacing: 20) {
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.serifCaption(13, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            }

            Button(action: startConnection) {
                HStack(spacing: 12) {
                    if isConnecting {
                        ProgressView()
                            .scaleEffect(0.9)
                            .tint(.white)
                    } else {
                        Image(systemName: "link")
                    }
                    Text(isConnecting ? "Starting..." : "Connect GitHub Account")
                        .font(.serifBody(16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                .cornerRadius(12)
            }
            .disabled(isConnecting)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Device Code View

    private func deviceCodeView(_ deviceCode: DeviceCodeResponse) -> some View {
        VStack(spacing: 20) {
            // Instructions
            Text("Enter this code on GitHub:")
                .font(.serifBody(15, weight: .medium))
                .foregroundColor(.textMedium)

            // Code display with copy button
            VStack(spacing: 12) {
                Text(deviceCode.userCode)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.forestDark)
                    .tracking(4)

                Button(action: {
                    UIPasteboard.general.string = deviceCode.userCode
                    withAnimation(.easeInOut(duration: 0.2)) {
                        codeCopied = true
                    }
                    // Reset after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            codeCopied = false
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14, weight: .medium))
                        Text(codeCopied ? "Copied!" : "Copy Code")
                            .font(.serifCaption(13, weight: .semibold))
                    }
                    .foregroundColor(codeCopied ? .green : .forestDark)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(codeCopied ? Color.green.opacity(0.1) : Color.forestDark.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.forestDark.opacity(0.08))
            .cornerRadius(12)

            // Open browser button
            Link(destination: URL(string: deviceCode.verificationUri)!) {
                HStack(spacing: 8) {
                    Image(systemName: "safari")
                    Text("Open github.com/login/device")
                        .font(.serifBody(15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                .cornerRadius(10)
            }

            // Polling status
            if isPollng {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Waiting for authorization...")
                        .font(.serifCaption(13, weight: .medium))
                        .foregroundColor(.textMedium)
                }
                .padding(.top, 8)
            }

            // Cancel button
            Button(action: cancelConnection) {
                Text("Cancel")
                    .font(.serifBody(14, weight: .medium))
                    .foregroundColor(.textMedium)
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 24)
    }

    // MARK: - Connected View

    private var connectedView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Connected to GitHub")
                        .font(.serifBody(16, weight: .semibold))
                        .foregroundColor(.textDark)

                    Text("\(github.repositories.count) repositories available")
                        .font(.serifCaption(13, weight: .regular))
                        .foregroundColor(.textMedium)
                }

                Spacer()
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - How It Works

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.forestDark)
                Text("How it works")
                    .font(.serifBody(14, weight: .semibold))
                    .foregroundColor(.forestDark)
            }

            VStack(alignment: .leading, spacing: 10) {
                tipRow("1", "Write #feature# or #issue# on paper")
                tipRow("2", "Capture with QuillStack camera")
                tipRow("3", "Review and create GitHub issue")
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }

    private func tipRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.forestDark.opacity(0.7))
                .clipShape(Circle())

            Text(text)
                .font(.serifCaption(13, weight: .regular))
                .foregroundColor(.textMedium)
        }
    }

    // MARK: - Actions

    private func startConnection() {
        isConnecting = true
        errorMessage = nil

        Task {
            do {
                let deviceCode = try await github.startAuthentication()
                await MainActor.run {
                    isConnecting = false
                    showDeviceCode = true
                    startPolling()
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func startPolling() {
        isPollng = true

        Task {
            do {
                try await github.pollForAuthentication()
                await MainActor.run {
                    isPollng = false
                    showDeviceCode = false
                    // Auto-continue after successful auth
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onContinue()
                    }
                }
            } catch {
                await MainActor.run {
                    isPollng = false
                    showDeviceCode = false
                    if let ghError = error as? GitHubError {
                        errorMessage = ghError.localizedDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func cancelConnection() {
        isPollng = false
        showDeviceCode = false
        github.deviceCode = nil
    }
}

#Preview {
    OnboardingGitHubPage(onContinue: {}, onSkip: {})
}
