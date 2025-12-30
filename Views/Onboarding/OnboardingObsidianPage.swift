//
//  OnboardingObsidianPage.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI

struct OnboardingObsidianPage: View {
    @ObservedObject private var settings = SettingsManager.shared

    var onContinue: () -> Void
    var onSkip: () -> Void

    @State private var vaultPathInput: String = ""
    @State private var folderInput: String = "QuillStack"
    @State private var isValidPath = false
    @State private var testResult: TestResult?

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
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: "cube")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.purple)
                    }

                    Text("Obsidian Export")
                        .font(.serifHeadline(26, weight: .bold))
                        .foregroundColor(.forestDark)

                    Text("Export notes directly to your\nObsidian vault as markdown files")
                        .font(.serifBody(15, weight: .regular))
                        .foregroundColor(.textMedium)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.top, 32)

                // Vault Path Input
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vault Path")
                            .font(.serifBody(14, weight: .semibold))
                            .foregroundColor(.textDark)

                        TextField("~/Documents/ObsidianVault", text: $vaultPathInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(Color.black)
                            .tint(.black)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.forestDark.opacity(0.2), lineWidth: 1)
                            )

                        Text("Full path to your Obsidian vault folder")
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textMedium)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Folder")
                            .font(.serifBody(14, weight: .semibold))
                            .foregroundColor(.textDark)

                        TextField("QuillStack", text: $folderInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.black)
                            .tint(.black)
                            .padding(14)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.forestDark.opacity(0.2), lineWidth: 1)
                            )

                        Text("Folder inside vault for exported notes")
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textMedium)
                    }

                    // Test result
                    if let result = testResult {
                        HStack(spacing: 8) {
                            switch result {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Vault path verified!")
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

                // Help text
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.forestDark)
                        Text("Finding your vault path")
                            .font(.serifBody(14, weight: .semibold))
                            .foregroundColor(.forestDark)
                    }

                    Text("Open Obsidian → Settings → Files & Links → Vault Path")
                        .font(.serifCaption(13, weight: .regular))
                        .foregroundColor(.textMedium)
                }
                .padding(16)
                .background(Color.forestDark.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal, 24)

                Spacer(minLength: 20)

                // Save Button
                Button(action: saveAndContinue) {
                    Text("Save & Continue")
                        .font(.serifBody(18, weight: .semibold))
                        .foregroundColor(.forestLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: vaultPathInput.isEmpty
                                    ? [Color.gray.opacity(0.5)]
                                    : [Color.forestDark, Color.forestMedium.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                }
                .disabled(vaultPathInput.isEmpty)
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
            vaultPathInput = settings.obsidianVaultPath ?? ""
            folderInput = settings.obsidianDefaultFolder
        }
    }

    private func saveAndContinue() {
        // Expand ~ to home directory
        let expandedPath = NSString(string: vaultPathInput).expandingTildeInPath

        // Validate path exists
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory)

        if exists && isDirectory.boolValue {
            settings.obsidianVaultPath = expandedPath
            settings.obsidianDefaultFolder = folderInput
            testResult = .success

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onContinue()
            }
        } else {
            testResult = .failure("Path not found or not a directory")
        }
    }
}

#Preview {
    OnboardingObsidianPage(onContinue: {}, onSkip: {})
}
