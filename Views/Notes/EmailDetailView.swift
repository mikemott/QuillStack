//
//  EmailDetailView.swift
//  QuillStack
//
//  Created on 2025-12-15.
//

import SwiftUI
import CoreData
import MessageUI

struct EmailDetailView: View, NoteDetailViewProtocol {
    @ObservedObject var note: Note
    @State private var toField: String = ""
    @State private var ccField: String = ""
    @State private var bccField: String = ""
    @State private var subjectField: String = ""
    @State private var bodyContent: String = ""
    @State private var showCcBcc: Bool = false
    @State private var showingMailComposer = false
    @State private var showingMailError = false
    @State private var showingExportSheet = false
    @State private var showingSummarySheet = false
    @State private var showingTypePicker = false
    @State private var showingTagEditor = false // QUI-162
    @Environment(\.dismiss) private var dismiss

    // MARK: - NoteDetailViewProtocol

    var shareableContent: String {
        var text = ""
        if !toField.isEmpty { text += "To: \(toField)\n" }
        if !ccField.isEmpty { text += "Cc: \(ccField)\n" }
        if !bccField.isEmpty { text += "Bcc: \(bccField)\n" }
        if !subjectField.isEmpty { text += "Subject: \(subjectField)\n\n" }
        text += bodyContent
        return text
    }

    var body: some View {
        mainContent
            .navigationBarHidden(true)
            .onAppear {
                parseEmailContent()
            }
            .onChange(of: toField) { _, _ in saveChanges() }
            .onChange(of: ccField) { _, _ in saveChanges() }
            .onChange(of: bccField) { _, _ in saveChanges() }
            .onChange(of: subjectField) { _, _ in saveChanges() }
            .onChange(of: bodyContent) { _, _ in saveChanges() }
            .sheet(isPresented: $showingMailComposer) {
                MailComposerView(
                    toRecipients: parseRecipients(toField),
                    ccRecipients: parseRecipients(ccField),
                    bccRecipients: parseRecipients(bccField),
                    subject: subjectField,
                    body: bodyContent
                )
            }
            .alert("Cannot Send Email", isPresented: $showingMailError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Mail is not configured on this device. Please set up a mail account in Settings.")
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportSheet(note: note)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingSummarySheet) {
                SummarySheet(note: note)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingTypePicker) {
                NoteTypePickerSheet(note: note)
            }
            .sheet(isPresented: $showingTagEditor) {
                TagEditorSheet(note: note)
                    .presentationDetents([.medium, .large])
            }
    }

    private var mainContent: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header using shared component
                DetailHeader(
                    title: "Email Draft",
                    date: note.createdAt,
                    noteType: "email",
                    onBack: { dismiss() },
                    customLabel: "Draft",
                    classification: note.classification
                )

                emailFieldsScrollView

                // Bottom bar
                bottomBar
            }
        }
    }

    private var emailFieldsScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Tags section (QUI-184)
                TagDisplaySection(note: note, showingTagEditor: $showingTagEditor)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // To field
                emailField(label: "To:", text: $toField, placeholder: "recipient@example.com")

                // CC/BCC toggle
                ccBccToggleSection

                if showCcBcc {
                    ccBccFieldsSection
                }

                Divider()
                    .background(Color.forestDark.opacity(0.1))

                // Subject field
                emailField(label: "Subject:", text: $subjectField, placeholder: "Email subject")

                Divider()
                    .background(Color.forestDark.opacity(0.1))

                // Body - always editable
                bodyEditorSection

                // Related notes section (QUI-161)
                relatedNotesSection
            }
        }
        .background(
            LinearGradient(
                colors: [Color.paperBeige.opacity(0.98), Color.paperTan.opacity(0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    @ViewBuilder
    private var ccBccToggleSection: some View {
        if !showCcBcc {
            Button(action: { withAnimation { showCcBcc = true } }) {
                HStack {
                    Spacer()
                    Text("Add Cc/Bcc")
                        .font(.serifCaption(13, weight: .medium))
                        .foregroundColor(.badgeEmail)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private var ccBccFieldsSection: some View {
        Group {
            Divider()
                .background(Color.forestDark.opacity(0.1))

            emailField(label: "Cc:", text: $ccField, placeholder: "cc@example.com")

            Divider()
                .background(Color.forestDark.opacity(0.1))

            emailField(label: "Bcc:", text: $bccField, placeholder: "bcc@example.com")
        }
    }

    private var bodyEditorSection: some View {
        TextEditor(text: $bodyContent)
            .font(.serifBody(16, weight: .regular))
            .foregroundColor(.textDark)
            .lineSpacing(6)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 300)
            .padding(16)
    }

    @ViewBuilder
    private var relatedNotesSection: some View {
        if note.linkCount > 0 {
            RelatedNotesSection(note: note) { selectedNote in
                // TODO: Navigate to selected note
                print("Selected related note: \(selectedNote.id)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Email Field

    private func emailField(label: String, text: Binding<String>, placeholder: String) -> some View {
        let isEmailField = label == "To:" || label == "Cc:" || label == "Bcc:"

        return HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.serifBody(14, weight: .medium))
                .foregroundColor(.textMedium)
                .frame(width: 60, alignment: .leading)

            TextField(placeholder, text: text)
                .font(.serifBody(16, weight: .regular))
                .foregroundColor(.textDark)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(isEmailField)
                .keyboardType(isEmailField ? .emailAddress : .default)

            // Validation indicator for email fields
            if isEmailField && !text.wrappedValue.isEmpty {
                let emails = parseRecipients(text.wrappedValue)
                let allValid = emails.allSatisfy { isValidEmail($0) }
                Image(systemName: allValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(allValid ? .green : .red)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Email Validation

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return true }  // Empty is valid (optional field)
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    private func parseRecipients(_ text: String) -> [String] {
        text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        DetailBottomBar(
            onExport: { showingExportSheet = true },
            onCopy: { copyToClipboard() },
            aiActions: DetailBottomBar.summarizeOnlyAIActions(
                onSummarize: { showingSummarySheet = true }
            ),
            customActions: [
                DetailAction(icon: "arrow.left.arrow.right.circle") {
                    showingTypePicker = true
                }
            ],
            primaryAction: DetailAction(
                icon: "paperplane.fill",
                color: .badgeEmail
            ) { openInMail() }
        )
    }

    // MARK: - Helpers

    private func parseEmailContent() {
        let classifier = TextClassifier()
        let content: String
        if let extracted = classifier.extractTriggerTag(from: note.content) {
            content = extracted.cleanedContent
        } else {
            content = note.content
        }

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lowercased = trimmed.lowercased()

            // Try to extract To: field
            if lowercased.hasPrefix("to:") {
                toField = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
            // Try to extract Cc: field
            else if lowercased.hasPrefix("cc:") {
                ccField = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                showCcBcc = true
            }
            // Try to extract Bcc: field
            else if lowercased.hasPrefix("bcc:") {
                bccField = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                showCcBcc = true
            }
            // Try to extract Subject: field
            else if lowercased.hasPrefix("subject:") || lowercased.hasPrefix("subj:") || lowercased.hasPrefix("re:") {
                if lowercased.hasPrefix("re:") {
                    subjectField = trimmed
                } else {
                    let colonIndex = trimmed.firstIndex(of: ":")!
                    subjectField = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        // Everything else is body (excluding parsed fields)
        var bodyLines: [String] = []
        var foundBody = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lowercased = trimmed.lowercased()

            // Skip email header lines
            if lowercased.hasPrefix("to:") || lowercased.hasPrefix("cc:") ||
               lowercased.hasPrefix("bcc:") || lowercased.hasPrefix("subject:") ||
               lowercased.hasPrefix("subj:") {
                foundBody = true
                continue
            }

            if foundBody || (!lowercased.hasPrefix("to:") && !lowercased.hasPrefix("subject:")) {
                bodyLines.append(line)
                foundBody = true
            }
        }

        bodyContent = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func saveChanges() {
        var lines: [String] = []

        // Add trigger tag
        lines.append("#email#")

        if !toField.isEmpty {
            lines.append("To: \(toField)")
        }
        if !ccField.isEmpty {
            lines.append("Cc: \(ccField)")
        }
        if !bccField.isEmpty {
            lines.append("Bcc: \(bccField)")
        }
        if !subjectField.isEmpty {
            lines.append("Subject: \(subjectField)")
        }
        if !bodyContent.isEmpty {
            lines.append("")
            lines.append(bodyContent)
        }

        note.content = lines.joined(separator: "\n")
        note.updatedAt = Date()
        try? CoreDataStack.shared.saveViewContext()
    }

    private func openInMail() {
        if MFMailComposeViewController.canSendMail() {
            showingMailComposer = true
        } else {
            // Fallback to mailto: URL
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = toField

            var queryItems: [URLQueryItem] = []
            if !ccField.isEmpty {
                queryItems.append(URLQueryItem(name: "cc", value: ccField))
            }
            if !bccField.isEmpty {
                queryItems.append(URLQueryItem(name: "bcc", value: bccField))
            }
            if !subjectField.isEmpty {
                queryItems.append(URLQueryItem(name: "subject", value: subjectField))
            }
            if !bodyContent.isEmpty {
                queryItems.append(URLQueryItem(name: "body", value: bodyContent))
            }
            if !queryItems.isEmpty {
                components.queryItems = queryItems
            }

            if let url = components.url {
                UIApplication.shared.open(url)
            } else {
                showingMailError = true
            }
        }
    }

}

// MARK: - Mail Composer View

struct MailComposerView: UIViewControllerRepresentable {
    let toRecipients: [String]
    let ccRecipients: [String]
    let bccRecipients: [String]
    let subject: String
    let body: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(toRecipients.filter { !$0.isEmpty })
        composer.setCcRecipients(ccRecipients.filter { !$0.isEmpty })
        composer.setBccRecipients(bccRecipients.filter { !$0.isEmpty })
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

#Preview {
    EmailDetailView(note: Note())
}
