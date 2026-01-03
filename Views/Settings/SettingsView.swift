//
//  SettingsView.swift
//  QuillStack
//
//  Created on 2025-12-15.
//

import SwiftUI
import Sentry

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var apiKeyInput: String = ""
    @State private var showingAPIKey = false
    @State private var testingAPI = false
    @State private var apiTestResult: APITestResult?
    @State private var showingDisclosureSheet = false
    @State private var learnedCorrectionCount: Int = 0
    @State private var showingClearConfirmation = false
    @State private var showingGitHubDeviceCode = false
    @State private var isPollingGitHub = false

    // Beta code state
    @State private var betaCodeInput: String = ""
    @State private var showingBetaCode = false

    // Storage management state
    @State private var storageUsed: Int64 = 0
    @State private var notesWithImages: Int = 0
    @State private var showingClearImagesConfirmation = false
    @State private var isCalculatingStorage = false

    enum APITestResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamLight.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom header
                    PageHeader(title: "Settings")

                    // Content
                    ScrollView {
                        VStack(spacing: 24) {
                            // AI Enhancement Section
                            aiEnhancementSection

                            // AI Data Disclosure (only show when API key is set)
                            if settings.hasAPIKey {
                                aiDisclosureSection
                            }

                            // Storage & Privacy Section
                            storagePrivacySection

                            // Handwriting Learning Section
                            handwritingLearningSection

                            // GitHub Integration Section
                            gitHubIntegrationSection

                            // Export Settings Section
                            exportSettingsSection

                            // About Section
                            aboutSection

                            #if DEBUG
                            // Debug Section (only in debug builds)
                            debugSection
                            #endif
                        }
                        .padding(20)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                apiKeyInput = settings.claudeAPIKey ?? ""
                betaCodeInput = settings.betaCode ?? ""
                learnedCorrectionCount = HandwritingLearningService.shared.correctionCount()
                loadStorageInfo()
            }
            .confirmationDialog(
                "Clear Learned Corrections",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    HandwritingLearningService.shared.clearAllCorrections()
                    learnedCorrectionCount = 0
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove all corrections you've taught the app. This action cannot be undone.")
            }
            .confirmationDialog(
                "Clear Original Images",
                isPresented: $showingClearImagesConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Images", role: .destructive) {
                    Task {
                        await ImageRetentionService.shared.clearAllOriginalImages()
                        loadStorageInfo()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all original images while keeping thumbnails. This frees up storage but you won't be able to view full-resolution images. This action cannot be undone.")
            }
            .sheet(isPresented: $showingDisclosureSheet) {
                AIDisclosureSheet(
                    onAccept: {
                        settings.hasAcceptedAIDisclosure = true
                        showingDisclosureSheet = false
                    },
                    onDecline: {
                        showingDisclosureSheet = false
                    }
                )
            }
            .sheet(isPresented: $showingGitHubDeviceCode) {
                GitHubDeviceCodeSheet(
                    isPolling: $isPollingGitHub,
                    onDismiss: {
                        showingGitHubDeviceCode = false
                        GitHubService.shared.deviceCode = nil
                    }
                )
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

                    Text("Get your API key from console.anthropic.com")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textMedium)
                }
                .padding(16)

                Divider()

                // Beta Code Entry (Optional alternative to API key)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Beta Access Code")
                            .font(.serifBody(14, weight: .medium))
                            .foregroundColor(.textDark)

                        Spacer()

                        Text("OPTIONAL")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.textMedium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.textMedium.opacity(0.1))
                            .cornerRadius(4)
                    }

                    HStack(spacing: 12) {
                        Group {
                            if showingBetaCode {
                                TextField("BETA-XXX-XXX", text: $betaCodeInput)
                            } else {
                                SecureField("BETA-XXX-XXX", text: $betaCodeInput)
                            }
                        }
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Color.black)
                        .tint(.black)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                        Button(action: { showingBetaCode.toggle() }) {
                            Image(systemName: showingBetaCode ? "eye.slash" : "eye")
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

                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.forestMedium)
                        Text("Use your beta code instead of an API key")
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textMedium)
                    }

                    // Credits display (if using beta code)
                    if settings.hasBetaCode {
                        HStack {
                            Image(systemName: "creditcard")
                                .font(.system(size: 12))
                                .foregroundColor(.forestDark)
                            Text("\(Int(settings.betaCreditsRemaining)) of \(Int(settings.betaCreditsTotal)) credits remaining")
                                .font(.serifCaption(12, weight: .medium))
                                .foregroundColor(.forestDark)
                            Spacer()
                        }
                        .padding(.top, 4)

                        // Low credits warning
                        if let usage = settings.creditUsagePercentage(), usage > 0.8 {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Credits Running Low")
                                        .font(.serifCaption(12, weight: .semibold))
                                        .foregroundColor(.orange)
                                    Text("\(Int(usage * 100))% used - Consider getting more beta credits")
                                        .font(.serifCaption(11, weight: .regular))
                                        .foregroundColor(.orange.opacity(0.8))
                                }

                                Spacer()
                            }
                            .padding(10)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(16)

                Divider()

                // Save Beta Code / Clear Button
                if !betaCodeInput.isEmpty || settings.hasBetaCode {
                    HStack(spacing: 12) {
                        Button(action: saveBetaCode) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                Text("Save Beta Code")
                                    .font(.serifBody(14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(betaCodeInput.isEmpty ? Color.gray : Color.forestMedium)
                            .cornerRadius(8)
                        }
                        .disabled(betaCodeInput.isEmpty)

                        if settings.hasBetaCode {
                            Button(action: clearBetaCode) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .padding(12)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                    Divider()
                }

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
                .opacity(settings.canUseAIFeatures ? 1 : 0.5)
                .disabled(!settings.canUseAIFeatures)
            }
            .background(
                LinearGradient(
                    colors: [Color.paperBeige.opacity(0.95), Color.paperTan.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Storage & Privacy Section

    private var storagePrivacySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Storage & Privacy", icon: "externaldrive")

            VStack(spacing: 0) {
                // Image Retention Policy
                VStack(alignment: .leading, spacing: 12) {
                    Text("Image Retention")
                        .font(.serifBody(15, weight: .medium))
                        .foregroundColor(.textDark)

                    Text("Control how long original images are kept after OCR processing")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textMedium)

                    Picker("Retention Policy", selection: $settings.imageRetentionPolicy) {
                        ForEach(ImageRetentionPolicy.allCases, id: \.self) { policy in
                            HStack {
                                Image(systemName: policy.icon)
                                Text(policy.displayName)
                            }
                            .tag(policy)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.forestDark)
                }
                .padding(16)

                // Days picker (only shown for deleteAfterDays policy)
                if settings.imageRetentionPolicy == .deleteAfterDays {
                    Divider()

                    HStack {
                        Text("Keep images for")
                            .font(.serifBody(15, weight: .medium))
                            .foregroundColor(.textDark)

                        Spacer()

                        Picker("Days", selection: $settings.imageRetentionDays) {
                            Text("7 days").tag(7)
                            Text("14 days").tag(14)
                            Text("30 days").tag(30)
                            Text("60 days").tag(60)
                            Text("90 days").tag(90)
                        }
                        .pickerStyle(.menu)
                        .tint(.forestDark)
                    }
                    .padding(16)
                }

                Divider()

                // Storage usage display
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Original Images")
                            .font(.serifBody(15, weight: .medium))
                            .foregroundColor(.textDark)
                        Text("\(notesWithImages) notes with images stored")
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textMedium)
                    }

                    Spacer()

                    if isCalculatingStorage {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text(ImageRetentionService.formatStorageSize(storageUsed))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.forestDark)
                    }
                }
                .padding(16)

                if notesWithImages > 0 {
                    Divider()

                    // Clear all images button
                    Button(action: { showingClearImagesConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear All Original Images")
                                .font(.serifBody(15, weight: .medium))
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(16)
                    }
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.paperBeige.opacity(0.95), Color.paperTan.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)

            // Privacy note
            Text("Thumbnails are always kept for display. Only full-resolution originals are affected.")
                .font(.serifCaption(11, weight: .regular))
                .foregroundColor(.textMedium)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Handwriting Learning Section

    private var handwritingLearningSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Handwriting Learning", icon: "brain")

            VStack(spacing: 0) {
                // Learning status
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Learned Corrections")
                            .font(.serifBody(15, weight: .medium))
                            .foregroundColor(.textDark)
                        Text("Corrections learned from your edits")
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textMedium)
                    }

                    Spacer()

                    Text("\(learnedCorrectionCount)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.forestDark)
                }
                .padding(16)

                if learnedCorrectionCount > 0 {
                    Divider()

                    // View learned corrections
                    NavigationLink(destination: LearnedCorrectionsView()) {
                        HStack {
                            Text("View Corrections")
                                .font(.serifBody(15, weight: .medium))
                                .foregroundColor(.textDark)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.textLight)
                        }
                        .padding(16)
                    }

                    Divider()

                    // Clear button
                    Button(action: { showingClearConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Learned Corrections")
                        }
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }

                Divider()

                // How it works explanation
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 12))
                            .foregroundColor(.forestDark)
                        Text("How it works")
                            .font(.serifCaption(12, weight: .semibold))
                            .foregroundColor(.forestDark)
                    }
                    Text("When you edit OCR text, the app learns your corrections. For example, if OCR reads \"rnail\" and you correct it to \"mail\", future scans will automatically fix this mistake.")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textMedium)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
            .background(
                LinearGradient(
                    colors: [Color.paperBeige.opacity(0.95), Color.paperTan.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - GitHub Integration Section

    private var gitHubIntegrationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "GitHub Integration", icon: "arrow.triangle.branch")

            VStack(spacing: 0) {
                if GitHubService.shared.isAuthenticated {
                    // Connected state
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Connected to GitHub")
                                .font(.serifBody(15, weight: .semibold))
                                .foregroundColor(.textDark)
                            Text("Create issues from handwritten notes")
                                .font(.serifCaption(12, weight: .regular))
                                .foregroundColor(.textMedium)
                        }

                        Spacer()
                    }
                    .padding(16)

                    Divider()

                    // Repository count
                    HStack {
                        Text("Repositories")
                            .font(.serifBody(15, weight: .medium))
                            .foregroundColor(.textDark)
                        Spacer()
                        Text("\(GitHubService.shared.repositories.count)")
                            .font(.serifBody(14, weight: .medium))
                            .foregroundColor(.textMedium)
                    }
                    .padding(16)

                    Divider()

                    // Disconnect button
                    Button(action: { GitHubService.shared.disconnect() }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Disconnect GitHub")
                        }
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                } else {
                    // Not connected state
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 32))
                            .foregroundColor(.textLight)

                        VStack(spacing: 8) {
                            Text("Create GitHub Issues")
                                .font(.serifBody(16, weight: .semibold))
                                .foregroundColor(.textDark)

                            Text("Connect your account to turn handwritten feature requests into GitHub issues")
                                .font(.serifCaption(13, weight: .regular))
                                .foregroundColor(.textMedium)
                                .multilineTextAlignment(.center)
                        }

                        Button(action: connectGitHub) {
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                Text("Connect GitHub Account")
                            }
                            .font(.serifBody(14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(20)
                }

                Divider()

                // How it works explanation
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 12))
                            .foregroundColor(.forestDark)
                        Text("How it works")
                            .font(.serifCaption(12, weight: .semibold))
                            .foregroundColor(.forestDark)
                    }
                    Text("Write #feature# or #issue# on paper, capture it with the camera, and QuillStack will transform your handwritten notes into a structured GitHub issue.")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textMedium)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
            .background(
                LinearGradient(
                    colors: [Color.paperBeige.opacity(0.95), Color.paperTan.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
    }

    private func connectGitHub() {
        Task {
            do {
                _ = try await GitHubService.shared.startAuthentication()
                showingGitHubDeviceCode = true

                // Start polling for authentication
                isPollingGitHub = true
                try await GitHubService.shared.pollForAuthentication()
                isPollingGitHub = false
                showingGitHubDeviceCode = false
            } catch {
                isPollingGitHub = false
                // Error is already stored in GitHubService.shared.authError
            }
        }
    }

    // MARK: - Export Settings Section

    private var exportSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Export", icon: "square.and.arrow.up.on.square")

            VStack(spacing: 0) {
                // Default destination
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Destination")
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.textDark)

                    Picker("", selection: $settings.defaultExportDestination) {
                        Text("Apple Notes").tag("apple_notes")
                        Text("Obsidian").tag("obsidian")
                        Text("Notion").tag("notion")
                    }
                    .pickerStyle(.segmented)
                }
                .padding(16)

                Divider()

                // Obsidian setup
                NavigationLink(destination: ObsidianSetupView()) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Obsidian")
                                .font(.serifBody(15, weight: .medium))
                                .foregroundColor(.textDark)
                            Text(settings.hasObsidianVault ? "Configured" : "Not configured")
                                .font(.serifCaption(12, weight: .regular))
                                .foregroundColor(settings.hasObsidianVault ? .green : .textMedium)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.textLight)
                    }
                    .padding(16)
                }

                Divider()

                // Notion setup
                NavigationLink(destination: NotionSetupView()) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notion")
                                .font(.serifBody(15, weight: .medium))
                                .foregroundColor(.textDark)
                            Text(settings.hasNotionAPIKey ? "Configured" : "Not configured")
                                .font(.serifCaption(12, weight: .regular))
                                .foregroundColor(settings.hasNotionAPIKey ? .green : .textMedium)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.textLight)
                    }
                    .padding(16)
                }

                Divider()

                // Include original image toggle
                Toggle(isOn: $settings.includeOriginalImageDefault) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Include original image")
                            .font(.serifBody(15, weight: .medium))
                            .foregroundColor(.textDark)
                        Text("Attach handwritten image by default")
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textMedium)
                    }
                }
                .tint(.forestDark)
                .padding(16)
            }
            .background(
                LinearGradient(
                    colors: [Color.paperBeige.opacity(0.95), Color.paperTan.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - AI Disclosure Section

    private var aiDisclosureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Data & Privacy", icon: "hand.raised")

            VStack(spacing: 0) {
                // Consent status
                HStack(spacing: 12) {
                    Image(systemName: settings.hasAcceptedAIDisclosure ? "checkmark.shield.fill" : "exclamationmark.shield")
                        .font(.system(size: 24))
                        .foregroundColor(settings.hasAcceptedAIDisclosure ? .green : .orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.hasAcceptedAIDisclosure ? "AI Data Disclosure Accepted" : "Review Required")
                            .font(.serifBody(15, weight: .semibold))
                            .foregroundColor(.textDark)
                        Text(settings.hasAcceptedAIDisclosure
                             ? "You've acknowledged how your notes are processed"
                             : "Please review how AI enhancement uses your data")
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textMedium)
                    }

                    Spacer()
                }
                .padding(16)

                if !settings.hasAcceptedAIDisclosure {
                    Divider()

                    Button(action: { showingDisclosureSheet = true }) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Review Data Disclosure")
                                .font(.serifBody(14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.forestDark)
                        .cornerRadius(8)
                    }
                    .padding(16)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.paperBeige.opacity(0.95), Color.paperTan.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
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
                Divider()

                // Re-run setup wizard button
                Button(action: {
                    settings.hasCompletedOnboarding = false
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .medium))
                        Text("Run Setup Wizard Again")
                            .font(.serifBody(15, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textLight)
                    }
                    .foregroundColor(.forestDark)
                    .padding(16)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.paperBeige.opacity(0.95), Color.paperTan.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Debug Section

    #if DEBUG
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Debug Tools", icon: "ladybug")

            VStack(spacing: 0) {
                // Test crash button
                Button(action: {
                    // Add a breadcrumb first so we can see the flow before crash
                    let breadcrumb = Breadcrumb(level: .info, category: "debug")
                    breadcrumb.message = "User triggered test crash"
                    SentrySDK.addBreadcrumb(breadcrumb)

                    // Trigger crash
                    fatalError("Test crash triggered from Settings")
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                        Text("Trigger Test Crash")
                            .font(.serifBody(15, weight: .medium))
                        Spacer()
                    }
                    .foregroundColor(.forestDark)
                    .padding(16)
                }

                Divider()

                // Send test event
                Button(action: {
                    SentrySDK.capture(message: "Test event from Settings") { scope in
                        scope.setLevel(.info)
                        scope.setContext(value: [
                            "source": "debug_settings",
                            "timestamp": Date().ISO8601Format()
                        ], key: "test_event")
                    }
                }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text("Send Test Event to Sentry")
                            .font(.serifBody(15, weight: .medium))
                        Spacer()
                    }
                    .foregroundColor(.forestDark)
                    .padding(16)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.paperBeige.opacity(0.95), Color.paperTan.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)

            Text("Test crash reporting and Sentry integration. Only visible in DEBUG builds.")
                .font(.serifCaption(12))
                .foregroundColor(.textLight)
        }
    }
    #endif

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
            let isValid = await settings.validateClaudeAPIKey()
            await MainActor.run {
                if isValid {
                    apiTestResult = .success
                    // Show disclosure sheet on first valid key
                    if !settings.hasAcceptedAIDisclosure {
                        showingDisclosureSheet = true
                    }
                } else {
                    apiTestResult = .failure("Invalid API key or connection error")
                }
                testingAPI = false
            }
        }
    }

    private func clearAPIKey() {
        apiKeyInput = ""
        settings.claudeAPIKey = nil
        settings.hasAcceptedAIDisclosure = false
        apiTestResult = nil
    }

    private func saveBetaCode() {
        settings.betaCode = betaCodeInput
        settings.useBetaAPIProxy = true

        // Set default proxy URL if not already set
        if settings.betaAPIProxyURL == nil {
            settings.betaAPIProxyURL = "https://quillstack-api-proxy.mikebmott.workers.dev"
        }

        // Show disclosure sheet if not already accepted
        if !settings.hasAcceptedAIDisclosure {
            showingDisclosureSheet = true
        }
    }

    private func clearBetaCode() {
        betaCodeInput = ""
        settings.betaCode = nil
        settings.useBetaAPIProxy = false
        settings.betaCreditsRemaining = 0
        settings.betaCreditsTotal = 0
    }

    private func loadStorageInfo() {
        isCalculatingStorage = true
        Task {
            let storage = await ImageRetentionService.shared.calculateStorageUsed()
            let count = await ImageRetentionService.shared.notesWithImagesCount()
            storageUsed = storage
            notesWithImages = count
            isCalculatingStorage = false
        }
    }
}

// MARK: - AI Disclosure Sheet

struct AIDisclosureSheet: View {
    var onAccept: () -> Void
    var onDecline: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48))
                            .foregroundColor(.forestDark)

                        Text("AI Data Processing Disclosure")
                            .font(.serifHeadline(22, weight: .bold))
                            .foregroundColor(.textDark)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)

                    // What we send
                    disclosureSection(
                        icon: "arrow.up.doc",
                        title: "What Gets Sent",
                        items: [
                            "The full text content of your notes when you tap 'Enhance' or 'Summarize'",
                            "The note type (todo, meeting, email, or general)",
                            "No images, metadata, or personal identifiers are sent"
                        ]
                    )

                    // Where it goes
                    disclosureSection(
                        icon: "globe",
                        title: "Where It Goes",
                        items: [
                            "Your notes are sent to Anthropic's Claude API (api.anthropic.com)",
                            "Data is transmitted securely over HTTPS with certificate validation",
                            "Processing occurs on Anthropic's servers in the United States"
                        ]
                    )

                    // Data retention
                    disclosureSection(
                        icon: "clock.badge.checkmark",
                        title: "Data Retention",
                        items: [
                            "Anthropic may retain data for up to 30 days for abuse prevention",
                            "Your notes are not used to train AI models",
                            "Review Anthropic's privacy policy for complete details"
                        ]
                    )

                    // Your control
                    disclosureSection(
                        icon: "hand.raised",
                        title: "Your Control",
                        items: [
                            "AI features are optional - OCR works entirely on-device",
                            "You choose when to enhance or summarize each note",
                            "You can remove your API key at any time to disable AI features"
                        ]
                    )

                    // Privacy link
                    Link(destination: URL(string: "https://www.anthropic.com/privacy")!) {
                        HStack {
                            Image(systemName: "link")
                            Text("Read Anthropic's Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.forestDark)
                        .padding(16)
                        .background(Color.forestDark.opacity(0.08))
                        .cornerRadius(10)
                    }
                }
                .padding(20)
            }
            .background(Color.creamLight)
            .navigationTitle("Data Disclosure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Decline") {
                        onDecline()
                    }
                    .foregroundColor(.textMedium)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button(action: onAccept) {
                        Text("I Understand and Accept")
                            .font(.serifBody(16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.forestDark)
                            .cornerRadius(12)
                    }

                    Text("You can review this anytime in Settings")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textMedium)
                }
                .padding(20)
                .background(Color.creamLight)
            }
        }
        .presentationDetents([.large])
    }

    private func disclosureSection(icon: String, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.forestDark)
                Text(title)
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.textDark)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.forestDark)
                        Text(item)
                            .font(.serifBody(14, weight: .regular))
                            .foregroundColor(.textMedium)
                    }
                }
            }
            .padding(.leading, 4)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - GitHub Device Code Sheet

struct GitHubDeviceCodeSheet: View {
    @Binding var isPolling: Bool
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // GitHub logo placeholder
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 56))
                    .foregroundColor(.textDark)

                if let deviceCode = GitHubService.shared.deviceCode {
                    VStack(spacing: 16) {
                        Text("Enter this code on GitHub")
                            .font(.serifHeadline(20, weight: .semibold))
                            .foregroundColor(.textDark)

                        // User code display
                        Text(deviceCode.userCode)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(.forestDark)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color.forestDark.opacity(0.1))
                            .cornerRadius(12)

                        Text("Go to:")
                            .font(.serifBody(14, weight: .regular))
                            .foregroundColor(.textMedium)

                        Link(deviceCode.verificationUri, destination: URL(string: deviceCode.verificationUri)!)
                            .font(.serifBody(16, weight: .semibold))
                            .foregroundColor(.forestDark)

                        if isPolling {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Waiting for authorization...")
                                    .font(.serifCaption(14, weight: .medium))
                                    .foregroundColor(.textMedium)
                            }
                            .padding(.top, 8)
                        }
                    }

                    // Open in browser button
                    Button(action: {
                        if let url = URL(string: deviceCode.verificationUri) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "safari")
                            Text("Open in Browser")
                        }
                        .font(.serifBody(16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.forestDark)
                        .cornerRadius(10)
                    }
                    .padding(.top, 16)
                } else {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Connecting to GitHub...")
                        .font(.serifBody(16, weight: .medium))
                        .foregroundColor(.textMedium)
                }

                Spacer()

                if let error = GitHubService.shared.authError {
                    Text(error)
                        .font(.serifCaption(13, weight: .medium))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .padding(24)
            .background(Color.creamLight)
            .navigationTitle("Connect GitHub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundColor(.textMedium)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    SettingsView()
}
