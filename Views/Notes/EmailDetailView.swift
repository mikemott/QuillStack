//
//  EmailDetailView.swift
//  QuillStack
//
//  Created on 2025-12-15.
//

import SwiftUI
import CoreData
import MessageUI

struct EmailDetailView: View {
    @ObservedObject var note: Note
    @State private var toField: String = ""
    @State private var subjectField: String = ""
    @State private var bodyContent: String = ""
    @State private var showingMailComposer = false
    @State private var showingMailError = false
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                slimHeader

                // Email fields
                ScrollView {
                    VStack(spacing: 0) {
                        // To field
                        emailField(label: "To:", text: $toField, placeholder: "recipient@example.com")

                        Divider()
                            .background(Color.forestDark.opacity(0.1))

                        // Subject field
                        emailField(label: "Subject:", text: $subjectField, placeholder: "Email subject")

                        Divider()
                            .background(Color.forestDark.opacity(0.1))

                        // Body - always editable
                        TextEditor(text: $bodyContent)
                            .font(.serifBody(16, weight: .regular))
                            .foregroundColor(.textDark)
                            .lineSpacing(6)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 300)
                            .padding(16)
                    }
                }
                .background(
                    LinearGradient(
                        colors: [Color.paperBeige.opacity(0.98), Color.paperTan.opacity(0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                // Bottom bar
                bottomBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            parseEmailContent()
        }
        .onChange(of: toField) { _, _ in saveChanges() }
        .onChange(of: subjectField) { _, _ in saveChanges() }
        .onChange(of: bodyContent) { _, _ in saveChanges() }
        .sheet(isPresented: $showingMailComposer) {
            MailComposerView(
                toRecipients: [toField],
                subject: subjectField,
                body: bodyContent
            )
        }
        .alert("Cannot Send Email", isPresented: $showingMailError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Mail is not configured on this device. Please set up a mail account in Settings.")
        }
    }

    // MARK: - Header

    private var slimHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.forestLight)
                }

                Text("Email Draft")
                    .font(.serifBody(17, weight: .semibold))
                    .foregroundColor(.forestLight)
                    .lineLimit(1)

                Spacer()

                // Badge
                HStack(spacing: 4) {
                    Image(systemName: "envelope")
                        .font(.system(size: 10, weight: .bold))
                    Text("EMAIL")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [Color.badgeEmail, Color.badgeEmail.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(4)
                .shadow(color: Color.badgeEmail.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // Date row
            HStack(spacing: 12) {
                Text(formattedDate)
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textLight.opacity(0.8))

                Text("•")
                    .foregroundColor(.textLight.opacity(0.5))

                Text("Draft")
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textLight.opacity(0.8))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(
            LinearGradient(
                colors: [Color.forestMedium, Color.forestDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Email Field

    private func emailField(label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.serifBody(14, weight: .medium))
                .foregroundColor(.textMedium)
                .frame(width: 60, alignment: .leading)

            TextField(placeholder, text: text)
                .font(.serifBody(16, weight: .regular))
                .foregroundColor(.textDark)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(label == "To:")
                .keyboardType(label == "To:" ? .emailAddress : .default)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Button(action: copyContent) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            Spacer()

            // Open in Mail button
            Button(action: openInMail) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Open in Mail")
                        .font(.serifBody(15, weight: .semibold))
                }
                .foregroundColor(.forestLight)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.badgeEmail, Color.badgeEmail.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.creamLight)
        .overlay(
            Rectangle()
                .fill(Color.forestDark.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(note.createdAt) {
            return "Today"
        } else if calendar.isDateInYesterday(note.createdAt) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: note.createdAt)
        }
    }

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

            // Skip To: and Subject: lines
            if lowercased.hasPrefix("to:") || lowercased.hasPrefix("subject:") || lowercased.hasPrefix("subj:") {
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

    private func saveChanges() {
        var lines: [String] = []

        // Add trigger tag
        lines.append("#email#")

        if !toField.isEmpty {
            lines.append("To: \(toField)")
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

    private func copyContent() {
        var text = ""
        if !toField.isEmpty { text += "To: \(toField)\n" }
        if !subjectField.isEmpty { text += "Subject: \(subjectField)\n\n" }
        text += bodyContent
        UIPasteboard.general.string = text
    }
}

// MARK: - Mail Composer View

struct MailComposerView: UIViewControllerRepresentable {
    let toRecipients: [String]
    let subject: String
    let body: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(toRecipients.filter { !$0.isEmpty })
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
