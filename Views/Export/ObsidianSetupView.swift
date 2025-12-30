//
//  ObsidianSetupView.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import SwiftUI

struct ObsidianSetupView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var vaultPathInput: String = ""
    @State private var defaultFolderInput: String = ""
    @State private var isValidPath = false
    @State private var testResult: TestResult?

    enum TestResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Vault Path Section
                    vaultPathSection

                    // Default Folder Section
                    defaultFolderSection

                    // Instructions
                    instructionsSection
                }
                .padding(20)
            }
        }
        .navigationTitle("Obsidian Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vaultPathInput = settings.obsidianVaultPath ?? ""
            defaultFolderInput = settings.obsidianDefaultFolder
            validatePath()
        }
    }

    // MARK: - Vault Path Section

    private var vaultPathSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Vault Location", icon: "folder")

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vault Path")
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.textDark)

                    TextField("Enter path to your Obsidian vault", text: $vaultPathInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Color.black)
                        .tint(.black)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.forestDark.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: vaultPathInput) { _, _ in
                            validatePath()
                        }

                    Text("Example: /Users/you/Documents/ObsidianVault")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textMedium)
                }
                .padding(16)

                Divider()

                // Save & Test Button
                HStack(spacing: 12) {
                    Button(action: saveAndTest) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                            Text("Save & Test")
                                .font(.serifBody(14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(vaultPathInput.isEmpty ? Color.gray : Color.forestDark)
                        .cornerRadius(8)
                    }
                    .disabled(vaultPathInput.isEmpty)

                    if settings.hasObsidianVault {
                        Button(action: clearPath) {
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

    // MARK: - Default Folder Section

    private var defaultFolderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Default Folder", icon: "folder.badge.plus")

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Folder Name")
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.textDark)

                    TextField("QuillStack", text: $defaultFolderInput)
                        .textFieldStyle(.plain)
                        .font(.serifBody(14, weight: .regular))
                        .foregroundStyle(Color.black)
                        .tint(.black)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.forestDark.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: defaultFolderInput) { _, newValue in
                            settings.obsidianDefaultFolder = newValue.isEmpty ? "QuillStack" : newValue
                        }

                    Text("Notes without tags will be saved here")
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

    // MARK: - Instructions

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "How to Find Your Vault Path", icon: "questionmark.circle")

            VStack(alignment: .leading, spacing: 12) {
                instructionStep(number: 1, text: "Open Obsidian on your Mac")
                instructionStep(number: 2, text: "Click the vault name in the sidebar")
                instructionStep(number: 3, text: "Select \"Open folder in Finder\"")
                instructionStep(number: 4, text: "Right-click the vault folder and choose \"Get Info\"")
                instructionStep(number: 5, text: "Copy the path from \"Where:\"")

                Text("For iCloud vaults, the path is typically:")
                    .font(.serifCaption(12, weight: .medium))
                    .foregroundColor(.textMedium)
                    .padding(.top, 8)

                Text("~/Library/Mobile Documents/iCloud~md~obsidian/Documents/YourVault")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.forestDark)
                    .padding(8)
                    .background(Color.forestLight.opacity(0.1))
                    .cornerRadius(4)
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

    private func validatePath() {
        guard !vaultPathInput.isEmpty else {
            isValidPath = false
            return
        }

        var isDirectory: ObjCBool = false
        let expandedPath = NSString(string: vaultPathInput).expandingTildeInPath
        isValidPath = FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func saveAndTest() {
        let expandedPath = NSString(string: vaultPathInput).expandingTildeInPath
        settings.obsidianVaultPath = expandedPath

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory) && isDirectory.boolValue {
            testResult = .success("Vault found at path")
        } else {
            testResult = .failure("Path not found or not a directory")
        }
    }

    private func clearPath() {
        vaultPathInput = ""
        settings.obsidianVaultPath = nil
        testResult = nil
    }
}

#Preview {
    NavigationStack {
        ObsidianSetupView()
    }
}
