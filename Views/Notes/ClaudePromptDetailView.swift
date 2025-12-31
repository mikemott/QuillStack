//
//  ClaudePromptDetailView.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI
import CoreData

struct ClaudePromptDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var note: Note

    // Services
    private let gitHubService = GitHubService.shared
    private let refinerService = PromptRefinerService.shared

    // State
    @State private var refinedPrompt: RefinedPrompt?
    @State private var isRefining = false
    @State private var refineError: String?

    @State private var selectedRepo: GitHubRepository?
    @State private var selectedLabels: Set<String> = []
    @State private var availableLabels: [String] = [
        "enhancement", "bug", "documentation", "ui", "performance", "refactor"
    ]

    @State private var isCreatingIssue = false
    @State private var createdIssue: GitHubIssue?
    @State private var createError: String?

    @State private var showOriginal = false
    @State private var showingDeviceCodeSheet = false
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var editedBody = ""

    // Common labels for fallback
    private let commonLabels = ["enhancement", "bug", "documentation", "ui", "performance", "refactor", "security", "testing"]

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Original text (collapsible)
                    originalTextSection

                    // Refined prompt
                    refinedPromptSection

                    // Repository selector
                    repositorySection

                    // Labels
                    labelsSection

                    // Create button
                    createButtonSection

                    // Success state
                    if let issue = createdIssue {
                        successSection(issue: issue)
                    }

                    // Error states
                    if let error = refineError ?? createError {
                        errorSection(message: error)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("GitHub Issue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if refinedPrompt != nil && createdIssue == nil {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            // Save edits
                            if let prompt = refinedPrompt {
                                refinedPrompt = RefinedPrompt(
                                    title: editedTitle,
                                    body: editedBody,
                                    suggestedLabels: prompt.suggestedLabels,
                                    originalText: prompt.originalText
                                )
                            }
                        } else {
                            // Start editing
                            editedTitle = refinedPrompt?.title ?? ""
                            editedBody = refinedPrompt?.body ?? ""
                        }
                        isEditing.toggle()
                    }
                }
            }
        }
        .task {
            await refinePrompt()

            // Fetch repositories if already authenticated (won't trigger onChange)
            if gitHubService.isAuthenticated && gitHubService.repositories.isEmpty {
                try? await gitHubService.fetchRepositories()
            }
        }
        .sheet(isPresented: $showingDeviceCodeSheet) {
            DeviceCodeSheet()
        }
        .onChange(of: gitHubService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                Task {
                    try? await gitHubService.fetchRepositories()
                }
            }
        }
    }

    // MARK: - Original Text Section

    private var originalTextSection: some View {
        DisclosureGroup("Original Handwriting", isExpanded: $showOriginal) {
            Text(note.content)
                .font(.serifBody())
                .foregroundColor(.textMedium)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.paperTan.opacity(0.5))
                .cornerRadius(8)
        }
        .font(.serifBody(15, weight: .medium))
        .foregroundColor(.textDark)
        .tint(.forestDark)
    }

    // MARK: - Refined Prompt Section

    private var refinedPromptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.forestDark)
                Text("Refined Issue")
                    .font(.serifHeadline(18, weight: .semibold))
                    .foregroundColor(.textDark)
                Spacer()
                if isRefining {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let refined = refinedPrompt {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    if isEditing {
                        TextField("Issue Title", text: $editedTitle)
                            .font(.serifHeadline(17, weight: .semibold))
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.forestDark.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        Text(refined.title)
                            .font(.serifHeadline(17, weight: .semibold))
                            .foregroundColor(.textDark)
                    }

                    Divider()

                    // Body
                    if isEditing {
                        TextEditor(text: $editedBody)
                            .font(.serifBody())
                            .foregroundStyle(Color.textDark)
                            .frame(minHeight: 200)
                            .padding(8)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.forestDark.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        Text(refined.body)
                            .font(.serifBody())
                            .foregroundColor(.textMedium)
                            .lineSpacing(4)
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            } else if !isRefining {
                // Placeholder when not refining and no result
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.textLight)
                    Text("Tap to refine your handwritten notes into a structured issue")
                        .font(.serifCaption(13, weight: .regular))
                        .foregroundColor(.textMedium)
                        .multilineTextAlignment(.center)

                    Button("Refine Notes") {
                        Task { await refinePrompt() }
                    }
                    .font(.serifBody(14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.forestDark)
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
        }
    }

    // MARK: - Repository Section

    private var repositorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.forestDark)
                Text("Repository")
                    .font(.serifHeadline(18, weight: .semibold))
                    .foregroundColor(.textDark)
            }

            if gitHubService.isAuthenticated {
                VStack(spacing: 0) {
                    Picker("Repository", selection: $selectedRepo) {
                        Text("Select repository...").tag(nil as GitHubRepository?)
                        ForEach(gitHubService.repositories) { repo in
                            HStack {
                                Image(systemName: repo.isPrivate ? "lock" : "globe")
                                Text(repo.fullName)
                            }
                            .tag(repo as GitHubRepository?)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.forestDark)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                .onChange(of: selectedRepo) { _, newRepo in
                    if let repo = newRepo {
                        Task {
                            if let labels = try? await gitHubService.fetchLabels(for: repo) {
                                availableLabels = labels.isEmpty ? commonLabels : labels
                            }
                        }
                    }
                }
            } else {
                // Not authenticated - show connect button
                VStack(spacing: 12) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.textLight)

                    Text("Connect your GitHub account to create issues")
                        .font(.serifCaption(13, weight: .regular))
                        .foregroundColor(.textMedium)
                        .multilineTextAlignment(.center)

                    Button(action: startGitHubAuth) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.circle")
                            Text("Connect GitHub")
                        }
                        .font(.serifBody(14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
        }
    }

    // MARK: - Labels Section

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.forestDark)
                Text("Labels")
                    .font(.serifHeadline(18, weight: .semibold))
                    .foregroundColor(.textDark)

                Spacer()

                Text("\(selectedLabels.count) selected")
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textMedium)
            }

            LabelSelector(
                availableLabels: availableLabels,
                selectedLabels: $selectedLabels
            )
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .opacity(gitHubService.isAuthenticated ? 1 : 0.5)
    }

    // MARK: - Create Button Section

    private var createButtonSection: some View {
        Button(action: createIssue) {
            HStack(spacing: 8) {
                if isCreatingIssue {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                }
                Text(isCreatingIssue ? "Creating Issue..." : "Create GitHub Issue")
                    .font(.serifBody(16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: canCreateIssue
                        ? [Color.forestDark, Color.forestMedium]
                        : [Color.gray.opacity(0.5), Color.gray.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: canCreateIssue ? .forestDark.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .disabled(!canCreateIssue || isCreatingIssue)
        .opacity(createdIssue != nil ? 0.5 : 1)
    }

    private var canCreateIssue: Bool {
        gitHubService.isAuthenticated &&
        selectedRepo != nil &&
        refinedPrompt != nil &&
        createdIssue == nil
    }

    // MARK: - Success Section

    private func successSection(issue: GitHubIssue) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("Issue #\(issue.number) Created!")
                .font(.serifHeadline(20, weight: .bold))
                .foregroundColor(.textDark)

            if let repo = selectedRepo {
                Text(repo.fullName)
                    .font(.serifCaption(14, weight: .medium))
                    .foregroundColor(.textMedium)
            }

            Link(destination: URL(string: issue.htmlUrl)!) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.square")
                    Text("Open in GitHub")
                }
                .font(.serifBody(15, weight: .semibold))
                .foregroundColor(.forestDark)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.forestDark.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.green.opacity(0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Error Section

    private func errorSection(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(message)
                .font(.serifCaption(13, weight: .medium))
                .foregroundColor(.textDark)

            Spacer()

            Button("Retry") {
                refineError = nil
                createError = nil
                Task { await refinePrompt() }
            }
            .font(.serifCaption(13, weight: .semibold))
            .foregroundColor(.forestDark)
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func refinePrompt() async {
        guard refinedPrompt == nil else { return }

        isRefining = true
        refineError = nil

        do {
            let refined = try await refinerService.refineToGitHubIssue(
                rawText: note.content,
                projectContext: nil
            )
            refinedPrompt = refined
            selectedLabels = Set(refined.suggestedLabels)
            editedTitle = refined.title
            editedBody = refined.body
        } catch {
            refineError = error.localizedDescription
        }

        isRefining = false
    }

    private func createIssue() {
        guard let repo = selectedRepo,
              let refined = refinedPrompt else { return }

        isCreatingIssue = true
        createError = nil

        Task {
            do {
                let title = isEditing ? editedTitle : refined.title
                let body = isEditing ? editedBody : refined.fullIssueBody

                let issue = try await gitHubService.createIssue(
                    in: repo,
                    title: title,
                    body: body,
                    labels: Array(selectedLabels)
                )

                createdIssue = issue

                // Update note with issue link
                note.summary = "GitHub Issue #\(issue.number)"
                try? viewContext.save()
            } catch {
                createError = error.localizedDescription
            }

            isCreatingIssue = false
        }
    }

    private func startGitHubAuth() {
        Task {
            do {
                _ = try await gitHubService.startAuthentication()
                showingDeviceCodeSheet = true
            } catch {
                createError = error.localizedDescription
            }
        }
    }
}

// MARK: - Device Code Sheet

struct DeviceCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let gitHubService = GitHubService.shared

    @State private var isPollling = false
    @State private var pollError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "link.badge.plus")
                    .font(.system(size: 56))
                    .foregroundColor(.forestDark)

                Text("Connect GitHub")
                    .font(.serifHeadline(24, weight: .bold))
                    .foregroundColor(.textDark)

                if let deviceCode = gitHubService.deviceCode {
                    VStack(spacing: 16) {
                        Text("Enter this code at GitHub:")
                            .font(.serifBody(15, weight: .regular))
                            .foregroundColor(.textMedium)

                        // Code display
                        Text(deviceCode.userCode)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(.forestDark)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color.forestDark.opacity(0.1))
                            .cornerRadius(12)

                        // Copy button
                        Button(action: {
                            UIPasteboard.general.string = deviceCode.userCode
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Code")
                            }
                            .font(.serifCaption(13, weight: .medium))
                            .foregroundColor(.forestDark)
                        }

                        Divider()
                            .padding(.vertical, 8)

                        // Open GitHub link
                        Link(destination: URL(string: deviceCode.verificationUri)!) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.right.square")
                                Text("Open \(deviceCode.verificationUri)")
                            }
                            .font(.serifBody(15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .cornerRadius(10)
                        }

                        // Polling indicator
                        if isPollling {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Waiting for authorization...")
                                    .font(.serifCaption(13, weight: .regular))
                                    .foregroundColor(.textMedium)
                            }
                            .padding(.top, 8)
                        }

                        if let error = pollError {
                            Text(error)
                                .font(.serifCaption(13, weight: .medium))
                                .foregroundColor(.red)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                // Continue button (starts polling)
                if !isPollling {
                    Button(action: startPolling) {
                        Text("I've entered the code")
                            .font(.serifBody(16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.forestDark)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 20)
            .background(Color.creamLight)
            .navigationTitle("GitHub Authorization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func startPolling() {
        isPollling = true
        pollError = nil

        Task {
            do {
                try await gitHubService.pollForAuthentication()
                dismiss()
            } catch {
                pollError = error.localizedDescription
                isPollling = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ClaudePromptDetailView(note: {
            let context = CoreDataStack.shared.persistentContainer.viewContext
            let note = Note(context: context)
            note.id = UUID()
            note.content = "#feature# Add dark mode toggle to settings page with system default option"
            note.noteType = "claudePrompt"
            note.createdAt = Date()
            note.updatedAt = Date()
            return note
        }())
    }
}
